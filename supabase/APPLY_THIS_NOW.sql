-- ============================================================================
-- BantayDengue — ONE-TIME CONSOLIDATED FIX (v2)
-- Run this ENTIRE file ONCE, in Supabase Studio → SQL Editor → New query.
-- Then refresh the app.
--
-- ⚠️ NOT SAFE TO RE-RUN once it has succeeded. STEP 1 below drops and
-- recreates public.reports and public.waste_requests — that permanently
-- deletes every row in both tables, every single time this file runs, even
-- on a second/third run. This file's earlier claim that "every statement
-- here is safe to re-run" was WRONG and caused real data loss on
-- 2026-08-19 — see the note at the bottom of the file. If you already ran
-- this once successfully, do not run it again. Future fixes belong in
-- their own new file (e.g. APPLY_APPOINTMENTS_FIX.sql), never appended
-- here.
-- ============================================================================

-- ── ROOT CAUSE, confirmed from your Supabase API logs ──────────────────────
-- "column reports.report_type does not exist" and
-- "column waste_requests.description does not exist" are not schema-cache
-- lag — they're real. Your project has TWO unrelated schema designs sitting
-- in the supabase/ folder (schema.sql, which every screen in lib/ is
-- actually written against — and supabase/migrations/..., an earlier,
-- abandoned "enterprise" redesign with different table shapes: `type`
-- instead of `report_type`, geography points instead of lat/lng columns, a
-- separate report_evidence table instead of a photo_url column, etc).
--
-- At some point public.reports and public.waste_requests got created from
-- the migrations/ version instead of schema.sql. Everything else in your
-- database (profiles, appointments, health_advisories, ...) is already
-- correct — confirmed from your logs, those return 200. So this is NOT a
-- full database rebuild. Only these two tables are wrong, and only these


-- two get touched below.
--R
-- Fixing this means making the database match the app that's actually
-- built (50 Dart files deep in that assumption) rather than rewriting the
-- Flutter app to match an abandoned schema nothing currently uses.

-- ── STEP 1: drop the two mismatched tables ──────────────────────────────────
-- CASCADE also removes any leftover artifacts from the wrong migration that
-- depended on these tables (e.g. a report_evidence table, if it exists).
drop table if exists public.reports cascade;
drop table if exists public.waste_requests cascade;

-- ── STEP 2: recreate them exactly as schema.sql defines them ───────────────
-- (copied verbatim from schema.sql so this file is self-contained — you
-- don't have to also re-run schema.sql separately)
create table public.reports (
  id              uuid primary key default uuid_generate_v4(),
  reporter_id     uuid not null references public.profiles(id) on delete cascade,
  report_type     text not null check (report_type in ('dengue_case','breeding_site')),
  description     text,
  photo_url       text,
  latitude        double precision,
  longitude       double precision,
  location_text   text,
  status          text not null default 'pending' check (status in ('pending','under_review','verified','rejected','resolved')),
  reviewed_by     uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create table public.waste_requests (
  id              uuid primary key default uuid_generate_v4(),
  requester_id    uuid not null references public.profiles(id) on delete cascade,
  description     text,
  latitude        double precision,
  longitude       double precision,
  location_text   text,
  status          text not null default 'pending' check (status in ('pending','scheduled','collected','cancelled')),
  scheduled_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.reports        enable row level security;
alter table public.waste_requests enable row level security;

-- ── STEP 3: RLS policies (same as schema.sql, plus the resident-owns-it
-- update policy that makes Edit/Delete work — see database_service.dart) ──
create policy "reports_insert_own" on public.reports
  for insert with check (reporter_id = auth.uid());

create policy "reports_select_own_or_staff" on public.reports
  for select using (reporter_id = auth.uid() or public.current_role() in ('health_worker','admin'));

create policy "reports_update_staff_only" on public.reports
  for update using (public.current_role() in ('health_worker','admin'));

create policy "reports_update_own_pending" on public.reports
  for update
  using (reporter_id = auth.uid() and status = 'pending')
  with check (reporter_id = auth.uid() and status = 'pending');

create policy "waste_insert_own" on public.waste_requests
  for insert with check (requester_id = auth.uid());

create policy "waste_select_own_or_staff" on public.waste_requests
  for select using (requester_id = auth.uid() or public.current_role() in ('health_worker','admin'));

create policy "waste_update_staff_only" on public.waste_requests
  for update using (public.current_role() in ('health_worker','admin'));

-- ── STEP 4: real server-side rate limit on report submissions ──────────────
-- Max 8 reports per resident per rolling 24 hours — enforced in the
-- database, not just the Flutter app's 10-second UI cooldown (which a
-- direct API call could ignore entirely).
create or replace function public.enforce_report_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from public.reports
  where reporter_id = new.reporter_id
    and created_at > now() - interval '24 hours';

  if recent_count >= 8 then
    raise exception
      'Too many reports submitted in the last 24 hours. Please wait before submitting another.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger reports_rate_limit
  before insert on public.reports
  for each row
  execute function public.enforce_report_rate_limit();

-- ── STEP 5: the earlier profile-creation bug fix, kept for anyone who
-- hasn't applied it yet (idempotent — no-ops if already applied) ───────────
drop policy if exists "profiles_insert_own_default_role" on public.profiles;
create policy "profiles_insert_own_default_role" on public.profiles
  for insert with check (
    id = auth.uid()
    and role = 'resident'
    and email = coalesce(auth.jwt() ->> 'email', '')
  );

insert into public.profiles (id, full_name, email, role)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1)),
  u.email,
  'resident'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
  and not exists (select 1 from public.profiles p2 where p2.email = u.email);

-- ============================================================================
-- Done. This DELETES all existing rows in reports and waste_requests (their
-- structure was wrong, so any test data in them was already unusable by the
-- app anyway). Nothing else in your database is touched.
-- Refresh the app (or Hot Restart) after this finishes running.
--
-- ⚠️ 2026-08-19 INCIDENT NOTE: this file was re-run a second time (to pick
-- up an unrelated appointments fix that used to live below this line) and
-- it silently wiped out all reports/waste_requests rows that had been
-- created since the first run — because STEP 1's DROP TABLE CASCADE is NOT
-- safe to re-run once you have real data in these tables, despite the
-- claim at the top of this file. That claim was wrong and has been
-- corrected. The appointments fix now lives in its own file,
-- `APPLY_APPOINTMENTS_FIX.sql`, specifically so this file never needs to be
-- run a second time. Do NOT re-run this file again once it has succeeded
-- once — if you need a future fix, put it in a NEW file instead.
-- ============================================================================
