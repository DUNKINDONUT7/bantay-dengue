-- ============================================================================
-- BantayDengue — appointments table fix
-- Run this ENTIRE file ONCE, in Supabase Studio → SQL Editor → New query.
-- Then refresh the app.
--
-- ⚠️ Same caution as APPLY_THIS_NOW.sql: this file is safe to run once, but
-- NOT safe to re-run after it succeeds, because it drops and recreates
-- public.appointments (deleting any rows in it at the time). As of
-- 2026-08-19, that table has 0 rows (every booking attempt has been
-- failing — see below), so running this now loses nothing. If you book any
-- real appointments after running this, do NOT run this file again.
-- ============================================================================

-- ── Root cause ───────────────────────────────────────────────────────────
-- Confirmed live (2026-08-19): public.appointments carries NOT NULL columns
-- from the same abandoned "enterprise" redesign documented in
-- APPLY_THIS_NOW.sql (patient_name, health_center, appointment_at) stacked
-- on top of the real schema.sql columns, plus a custom `appointment_status`
-- enum missing 'approved'/'rejected' — two values every staff screen
-- depends on. No app code writes patient_name/health_center/appointment_at,
-- so every booking attempt has been failing with a NOT NULL violation at
-- the database level. Recreating from schema.sql (same approach
-- APPLY_THIS_NOW.sql already used for reports/waste_requests) fixes it,
-- and needs zero Dart code changes — database_service.dart already targets
-- exactly this shape.

drop table if exists public.appointments cascade;

create table public.appointments (
  id              uuid primary key default uuid_generate_v4(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  assigned_doctor uuid references public.profiles(id),
  scheduled_at    timestamptz not null,
  reason          text,
  status          text not null default 'pending' check (status in ('pending','approved','rejected','completed','cancelled')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.appointments enable row level security;

create policy "appointments_insert_own" on public.appointments
  for insert with check (patient_id = auth.uid());

create policy "appointments_select_own_or_staff" on public.appointments
  for select using (patient_id = auth.uid() or public.current_role() in ('health_worker','admin'));

create policy "appointments_update_own_or_staff" on public.appointments
  for update using (patient_id = auth.uid() or public.current_role() in ('health_worker','admin'));

-- ============================================================================
-- Done. Refresh the app (or Hot Restart) after this finishes running, then
-- try booking an appointment as the resident test account to confirm.
-- ============================================================================
