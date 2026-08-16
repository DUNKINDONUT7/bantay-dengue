-- ============================================================================
-- BantayDengue — Supabase schema
-- Run this once in Supabase Studio → SQL Editor (or via `supabase db push`).
-- Safe to re-run: every statement uses IF NOT EXISTS / OR REPLACE.
-- ============================================================================

create extension if not exists "uuid-ossp";

-- ── profiles ────────────────────────────────────────────────────────────────
-- One row per auth.users row. Role lives here, never on the client.
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  email       text not null default '',
  phone       text,
  role        text not null default 'resident' check (role in ('resident','health_worker','admin')),
  barangay    text,
  photo_url   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── reports (dengue cases + breeding sites) ────────────────────────────────
create table if not exists public.reports (
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
  updated_at      timestamptz not null default now()
);

-- ── appointments ────────────────────────────────────────────────────────────
create table if not exists public.appointments (
  id              uuid primary key default uuid_generate_v4(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  assigned_doctor uuid references public.profiles(id),
  scheduled_at    timestamptz not null,
  reason          text,
  status          text not null default 'pending' check (status in ('pending','approved','rejected','completed','cancelled')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ── waste_requests ──────────────────────────────────────────────────────────
create table if not exists public.waste_requests (
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

-- ── notifications ───────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  body        text,
  type        text not null default 'general' check (type in ('general','outbreak_alert','advisory','appointment','report_status','waste')),
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ── health_advisories ───────────────────────────────────────────────────────
create table if not exists public.health_advisories (
  id           uuid primary key default uuid_generate_v4(),
  author_id    uuid references public.profiles(id),
  title        text not null,
  body         text not null,
  created_at   timestamptz not null default now()
);

-- ── hotspots ─────────────────────────────────────────────────────────────────
create table if not exists public.hotspots (
  id           uuid primary key default uuid_generate_v4(),
  latitude     double precision not null,
  longitude    double precision not null,
  risk_level   text not null default 'low' check (risk_level in ('low','moderate','high')),
  barangay     text,
  case_count   integer not null default 0,
  updated_at   timestamptz not null default now()
);

-- ── announcements (admin) ───────────────────────────────────────────────────
create table if not exists public.announcements (
  id           uuid primary key default uuid_generate_v4(),
  author_id    uuid references public.profiles(id),
  title        text not null,
  body         text not null,
  created_at   timestamptz not null default now()
);

-- ── system_activity (admin audit log) ──────────────────────────────────────
create table if not exists public.system_activity (
  id           uuid primary key default uuid_generate_v4(),
  actor_id     uuid references public.profiles(id),
  action       text not null,
  details      jsonb,
  created_at   timestamptz not null default now()
);

-- ============================================================================
-- Auto-create a profile row whenever someone signs up. Role is ALWAYS
-- forced to 'resident' here; signup can never set health_worker/admin.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    'resident'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table public.profiles          enable row level security;
alter table public.reports           enable row level security;
alter table public.appointments      enable row level security;
alter table public.waste_requests    enable row level security;
alter table public.notifications     enable row level security;
alter table public.health_advisories enable row level security;
alter table public.hotspots          enable row level security;
alter table public.announcements     enable row level security;
alter table public.system_activity   enable row level security;

-- Helper: current user's role, read straight from the table (not the JWT),
-- so a promoted/demoted user is respected immediately.
create or replace function public.current_role()
returns text
language sql stable
security definer set search_path = public
as $$
  select role::text from public.profiles where id = auth.uid();
$$;

-- ── profiles policies ───────────────────────────────────────────────────────
drop policy if exists "profiles_select_own_or_staff" on public.profiles;
create policy "profiles_select_own_or_staff" on public.profiles
  for select using (
    id = auth.uid() or public.current_role() in ('health_worker','admin')
  );

drop policy if exists "profiles_insert_own_default_role" on public.profiles;
create policy "profiles_insert_own_default_role" on public.profiles
  for insert with check (
    id = auth.uid()
    and role = 'resident'
    and email = coalesce(auth.jwt() ->> 'email', '')
  );
  -- Reads the email straight off the current session's JWT claims instead
  -- of querying auth.users. auth.users is a protected table — the
  -- `authenticated` role has no SELECT grant on it by default in Supabase,
  -- so the old `(select email from auth.users where id = auth.uid())`
  -- version of this check threw `permission denied for table users`
  -- (Postgres code 42501) every time this policy's WITH CHECK actually had
  -- to run — i.e. whenever a user's profile row didn't already exist from
  -- the on_auth_user_created trigger and the client tried to create it
  -- itself. auth.jwt() needs no table grant at all, so this can't fail the
  -- same way. Run supabase/APPLY_THIS_NOW.sql to apply this fix
  -- and repair any accounts already stuck by it.

drop policy if exists "profiles_update_own_limited" on public.profiles;
create policy "profiles_update_own_limited" on public.profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
  -- ^ users can edit their own name/phone/barangay/photo, but the `role`
  --   column can never change through this policy — only a service-role
  --   admin action (server-side) can promote someone to health_worker/admin.

drop policy if exists "profiles_admin_update_role" on public.profiles;
create policy "profiles_admin_update_role" on public.profiles
  for update using (public.current_role() = 'admin')
  with check (true);

-- ── reports policies ────────────────────────────────────────────────────────
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports
  for insert with check (reporter_id = auth.uid());

drop policy if exists "reports_select_own_or_staff" on public.reports;
create policy "reports_select_own_or_staff" on public.reports
  for select using (reporter_id = auth.uid() or public.current_role() in ('health_worker','admin'));

drop policy if exists "reports_update_staff_only" on public.reports;
create policy "reports_update_staff_only" on public.reports
  for update using (public.current_role() in ('health_worker','admin'));

-- ── appointments policies ───────────────────────────────────────────────────
drop policy if exists "appointments_insert_own" on public.appointments;
create policy "appointments_insert_own" on public.appointments
  for insert with check (patient_id = auth.uid());

drop policy if exists "appointments_select_own_or_staff" on public.appointments;
create policy "appointments_select_own_or_staff" on public.appointments
  for select using (patient_id = auth.uid() or public.current_role() in ('health_worker','admin'));

drop policy if exists "appointments_update_own_or_staff" on public.appointments;
create policy "appointments_update_own_or_staff" on public.appointments
  for update using (patient_id = auth.uid() or public.current_role() in ('health_worker','admin'));

-- ── waste_requests policies ─────────────────────────────────────────────────
drop policy if exists "waste_insert_own" on public.waste_requests;
create policy "waste_insert_own" on public.waste_requests
  for insert with check (requester_id = auth.uid());

drop policy if exists "waste_select_own_or_staff" on public.waste_requests;
create policy "waste_select_own_or_staff" on public.waste_requests
  for select using (requester_id = auth.uid() or public.current_role() in ('health_worker','admin'));

drop policy if exists "waste_update_staff_only" on public.waste_requests;
create policy "waste_update_staff_only" on public.waste_requests
  for update using (public.current_role() in ('health_worker','admin'));

-- ── notifications policies ──────────────────────────────────────────────────
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (user_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (user_id = auth.uid());

drop policy if exists "notifications_insert_staff" on public.notifications;
create policy "notifications_insert_staff" on public.notifications
  for insert with check (public.current_role() in ('health_worker','admin'));

-- ── health_advisories / hotspots: public read, staff write ────────────────
drop policy if exists "advisories_read_all" on public.health_advisories;
create policy "advisories_read_all" on public.health_advisories for select using (true);
drop policy if exists "advisories_write_staff" on public.health_advisories;
create policy "advisories_write_staff" on public.health_advisories
  for all using (public.current_role() in ('health_worker','admin')) with check (public.current_role() in ('health_worker','admin'));

drop policy if exists "hotspots_read_all" on public.hotspots;
create policy "hotspots_read_all" on public.hotspots for select using (true);
drop policy if exists "hotspots_write_staff" on public.hotspots;
create policy "hotspots_write_staff" on public.hotspots
  for all using (public.current_role() in ('health_worker','admin')) with check (public.current_role() in ('health_worker','admin'));

-- ── announcements: public read, admin write ────────────────────────────────
drop policy if exists "announcements_read_all" on public.announcements;
create policy "announcements_read_all" on public.announcements for select using (true);
drop policy if exists "announcements_write_admin" on public.announcements;
create policy "announcements_write_admin" on public.announcements
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- ── system_activity: admin only ─────────────────────────────────────────────
drop policy if exists "activity_admin_only" on public.system_activity;
create policy "activity_admin_only" on public.system_activity
  for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- ============================================================================
-- To assign an authorized role, run manually as a project owner:
--   update public.profiles set role = 'waste_personnel' where email = 'collector@example.com';
-- Never expose this capability to a public-facing screen without checking
-- current_role() = 'admin' server-side first.
-- ============================================================================
