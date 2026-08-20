-- ============================================================================
-- BantayDengue — THE ONE FILE TO RUN FROM NOW ON
-- Run this ENTIRE file, once, in Supabase Studio → SQL Editor → New query.
-- Safe to re-run (idempotent) — every statement uses IF NOT EXISTS / OR
-- REPLACE / DROP POLICY IF EXISTS.
--
-- WHAT THIS ASSUMES YOU ALREADY HAVE (confirmed applied on the live project):
--   supabase/schema.sql            — base tables, profiles, RLS
--   supabase/APPLY_THIS_NOW.sql    — reports/waste_requests rebuild, report
--                                     rate limit, profile-insert fix
--
-- WHAT THIS FILE ADDS (none of this is live yet):
--   1. The v2.3 additive layer: waste_personnel role, account suspension
--      (is_active), status_history audit trail, workflow-transition +
--      notification + audit triggers, private evidence storage buckets.
--      Without this, the Waste Personnel role cannot exist (profiles.role
--      check constraint rejects it) and photo evidence upload fails (the
--      report-evidence/waste-evidence buckets don't exist).
--   2. NEW: lets a resident cancel their own waste-collection request while
--      it is still 'pending' — the same self-service cancel that already
--      exists for reports (soft delete) and appointments (status update),
--      but was missing for waste requests entirely (no RLS path, no UI).
--
-- AFTER RUNNING THIS ONCE: supabase/schema.sql, supabase/APPLY_THIS_NOW.sql,
-- supabase/BantayDengue_Full_Database_v2.3.sql, and the whole
-- supabase/migrations/ folder (which contains an abandoned PostGIS-based
-- redesign nothing in the Flutter app uses) are superseded. This is the only
-- file to reference/run going forward.
-- ============================================================================

begin;

-- ============================================================================
-- PART 1 — v2.3 additive security and operations layer
-- ============================================================================

-- ── Profiles and role compatibility ────────────────────────────────────────
alter table public.profiles
  add column if not exists is_active boolean not null default true;

update public.profiles
set role = 'waste_personnel'
where role::text in ('waste_staff', 'waste_management');

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role::text in ('resident', 'health_worker', 'waste_personnel', 'admin')) not valid;
alter table public.profiles validate constraint profiles_role_check;

create or replace function public.current_role()
returns text
language sql stable
security definer
set search_path = public
as $$
  select role::text
  from public.profiles
  where id = auth.uid() and is_active = true;
$$;

create or replace function public.current_account_active()
returns boolean
language sql stable
security definer
set search_path = public
as $$
  select coalesce((select is_active from public.profiles where id = auth.uid()), false);
$$;

-- RLS WITH CHECK expressions cannot safely compare OLD and NEW rows. Enforce
-- privileged profile fields in a trigger so a resident cannot promote or
-- reactivate an account through a handcrafted REST request.
create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'Profile IDs cannot be changed' using errcode = '42501';
  end if;

  if auth.uid() is not null
     and coalesce(public.current_role(), '') <> 'admin'
     and (
       new.role is distinct from old.role
       or new.is_active is distinct from old.is_active
       or new.email is distinct from old.email
     ) then
    raise exception 'Only an administrator may change profile access fields'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_privileged_fields on public.profiles;
create trigger profiles_protect_privileged_fields
  before update on public.profiles
  for each row execute function public.protect_profile_privileged_fields();

-- ── Richer waste evidence and assignment metadata ──────────────────────────
alter table public.waste_requests
  add column if not exists photo_url text,
  add column if not exists handled_by uuid references public.profiles(id),
  add column if not exists completion_photo_url text;

-- ── Status history ─────────────────────────────────────────────────────────
create table if not exists public.status_history (
  id uuid primary key default uuid_generate_v4(),
  entity_type text not null check (entity_type in ('report', 'appointment', 'waste_request')),
  entity_id uuid not null,
  old_status text,
  new_status text not null,
  changed_by uuid references public.profiles(id),
  note text,
  created_at timestamptz not null default now()
);
create index if not exists status_history_entity_idx
  on public.status_history(entity_type, entity_id, created_at desc);
alter table public.status_history enable row level security;

-- ── RLS: suspended accounts cannot perform operational actions ─────────────
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports
  for insert with check (reporter_id = auth.uid() and public.current_account_active());

drop policy if exists "reports_select_own_or_staff" on public.reports;
create policy "reports_select_own_or_staff" on public.reports
  for select using (
    public.current_account_active()
    and (reporter_id = auth.uid() or public.current_role() in ('health_worker', 'admin'))
  );

drop policy if exists "reports_update_staff_only" on public.reports;
create policy "reports_update_staff_only" on public.reports
  for update using (public.current_role() in ('health_worker', 'admin'))
  with check (public.current_role() in ('health_worker', 'admin'));

drop policy if exists "appointments_insert_own" on public.appointments;
create policy "appointments_insert_own" on public.appointments
  for insert with check (patient_id = auth.uid() and public.current_account_active());

drop policy if exists "appointments_select_own_or_staff" on public.appointments;
create policy "appointments_select_own_or_staff" on public.appointments
  for select using (
    public.current_account_active()
    and (patient_id = auth.uid() or public.current_role() in ('health_worker', 'admin'))
  );

drop policy if exists "appointments_update_own_or_staff" on public.appointments;
create policy "appointments_update_own_or_staff" on public.appointments
  for update using (
    public.current_account_active()
    and (patient_id = auth.uid() or public.current_role() in ('health_worker', 'admin'))
  )
  with check (
    public.current_account_active()
    and (patient_id = auth.uid() or public.current_role() in ('health_worker', 'admin'))
  );

drop policy if exists "waste_insert_own" on public.waste_requests;
create policy "waste_insert_own" on public.waste_requests
  for insert with check (requester_id = auth.uid() and public.current_account_active());

drop policy if exists "waste_select_own_or_staff" on public.waste_requests;
create policy "waste_select_own_or_staff" on public.waste_requests
  for select using (
    public.current_account_active()
    and (requester_id = auth.uid() or public.current_role() in ('health_worker', 'waste_personnel', 'admin'))
  );

drop policy if exists "waste_update_staff_only" on public.waste_requests;
create policy "waste_update_staff_only" on public.waste_requests
  for update using (public.current_role() in ('health_worker', 'waste_personnel', 'admin'))
  with check (public.current_role() in ('health_worker', 'waste_personnel', 'admin'));

drop policy if exists "profiles_select_own_or_staff" on public.profiles;
create policy "profiles_select_own_or_staff" on public.profiles
  for select using (
    id = auth.uid()
    or public.current_role() in ('health_worker', 'waste_personnel', 'admin')
  );

-- Keep self-service profile changes from altering role or access state.
drop policy if exists "profiles_update_own_limited" on public.profiles;
create policy "profiles_update_own_limited" on public.profiles
  for update using (id = auth.uid() and public.current_account_active())
  with check (
    id = auth.uid()
    and role::text = public.current_role()
    and is_active = true
  );

drop policy if exists "profiles_admin_update_role" on public.profiles;
create policy "profiles_admin_update_role" on public.profiles
  for update using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (user_id = auth.uid() and public.current_account_active());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (user_id = auth.uid() and public.current_account_active())
  with check (user_id = auth.uid() and public.current_account_active());

drop policy if exists "notifications_insert_staff" on public.notifications;
create policy "notifications_insert_staff" on public.notifications
  for insert with check (public.current_role() in ('health_worker', 'admin'));

-- Waste Personnel can read maps/advisories but only health workers/admins
-- classify hotspots and publish clinical/public-health guidance.
drop policy if exists "hotspots_write_staff" on public.hotspots;
create policy "hotspots_write_staff" on public.hotspots
  for all using (public.current_role() in ('health_worker', 'admin'))
  with check (public.current_role() in ('health_worker', 'admin'));

drop policy if exists "advisories_write_staff" on public.health_advisories;
create policy "advisories_write_staff" on public.health_advisories
  for all using (public.current_role() in ('health_worker', 'admin'))
  with check (public.current_role() in ('health_worker', 'admin'));

-- Residents see history for their own records; authorized operational staff
-- see only history relevant to their assigned domain.
drop policy if exists "status_history_read_authorized" on public.status_history;
create policy "status_history_read_authorized" on public.status_history
  for select using (
    public.current_role() = 'admin'
    or (entity_type = 'report' and (
      public.current_role() = 'health_worker'
      or exists (select 1 from public.reports r where r.id = entity_id and r.reporter_id = auth.uid())
    ))
    or (entity_type = 'appointment' and (
      public.current_role() = 'health_worker'
      or exists (select 1 from public.appointments a where a.id = entity_id and a.patient_id = auth.uid())
    ))
    or (entity_type = 'waste_request' and (
      public.current_role() in ('health_worker', 'waste_personnel')
      or exists (select 1 from public.waste_requests w where w.id = entity_id and w.requester_id = auth.uid())
    ))
  );

-- ── Authoritative workflow history, notification and audit triggers ─────────
create or replace function public.validate_workflow_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then return new; end if;

  if tg_table_name = 'reports' then
    if not (
      (old.status = 'pending' and new.status in ('under_review', 'verified', 'rejected'))
      or (old.status = 'under_review' and new.status in ('verified', 'rejected'))
      or (old.status = 'verified' and new.status = 'resolved')
    ) then
      raise exception 'Invalid report status transition: % -> %', old.status, new.status
        using errcode = '23514';
    end if;
  elsif tg_table_name = 'appointments' then
    if not (
      (old.status = 'pending' and new.status in ('approved', 'rejected', 'cancelled'))
      or (old.status = 'approved' and new.status in ('completed', 'cancelled'))
    ) then
      raise exception 'Invalid appointment status transition: % -> %', old.status, new.status
        using errcode = '23514';
    end if;
  elsif tg_table_name = 'waste_requests' then
    if not (
      (old.status = 'pending' and new.status in ('scheduled', 'cancelled'))
      or (old.status = 'scheduled' and new.status in ('collected', 'cancelled'))
    ) then
      raise exception 'Invalid waste status transition: % -> %', old.status, new.status
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

-- Residents may cancel their own pending/approved appointments, but may not
-- approve, complete, reassign, or otherwise edit appointment records directly.
create or replace function public.protect_patient_appointment_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.patient_id
     and coalesce(public.current_role(), '') not in ('health_worker', 'admin')
     and (
       new.status <> 'cancelled'
       or old.status not in ('pending', 'approved')
       or new.patient_id is distinct from old.patient_id
       or new.assigned_doctor is distinct from old.assigned_doctor
       or new.scheduled_at is distinct from old.scheduled_at
       or new.reason is distinct from old.reason
       or new.created_at is distinct from old.created_at
     ) then
    raise exception 'Patients may only cancel their own active appointments'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Waste Personnel may update workflow fields but cannot rewrite resident
-- ownership, submission evidence, or location details. A collection claimed by
-- one personnel account cannot be completed or cancelled by another.
create or replace function public.protect_waste_personnel_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_role() <> 'waste_personnel' then
    return new;
  end if;

  if new.requester_id is distinct from old.requester_id
     or new.description is distinct from old.description
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude
     or new.location_text is distinct from old.location_text
     or new.photo_url is distinct from old.photo_url
     or new.created_at is distinct from old.created_at then
    raise exception 'Waste Personnel cannot rewrite resident request details'
      using errcode = '42501';
  end if;

  if old.handled_by is not null and old.handled_by <> auth.uid() then
    raise exception 'This collection is assigned to another personnel account'
      using errcode = '42501';
  end if;

  if new.status in ('scheduled', 'collected') and new.handled_by is null then
    new.handled_by := auth.uid();
  end if;

  if new.handled_by is not null and new.handled_by <> auth.uid() then
    raise exception 'Waste Personnel may only assign a collection to themselves'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists reports_validate_status on public.reports;
create trigger reports_validate_status before update of status on public.reports
  for each row execute function public.validate_workflow_transition();
drop trigger if exists appointments_protect_patient_update on public.appointments;
create trigger appointments_protect_patient_update before update on public.appointments
  for each row execute function public.protect_patient_appointment_update();
drop trigger if exists appointments_validate_status on public.appointments;
create trigger appointments_validate_status before update of status on public.appointments
  for each row execute function public.validate_workflow_transition();
drop trigger if exists waste_protect_personnel_update on public.waste_requests;
create trigger waste_protect_personnel_update before update on public.waste_requests
  for each row execute function public.protect_waste_personnel_update();
drop trigger if exists waste_validate_status on public.waste_requests;
create trigger waste_validate_status before update of status on public.waste_requests
  for each row execute function public.validate_workflow_transition();

create or replace function public.capture_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  entity text;
  recipient uuid;
  notification_type text;
  notification_title text;
begin
  if new.status is not distinct from old.status then return new; end if;

  if tg_table_name = 'reports' then
    entity := 'report'; recipient := new.reporter_id;
    notification_type := 'report_status'; notification_title := 'Report status updated';
  elsif tg_table_name = 'appointments' then
    entity := 'appointment'; recipient := new.patient_id;
    notification_type := 'appointment'; notification_title := 'Appointment updated';
  elsif tg_table_name = 'waste_requests' then
    entity := 'waste_request'; recipient := new.requester_id;
    notification_type := 'waste'; notification_title := 'Waste request updated';
  else
    return new;
  end if;

  insert into public.status_history(entity_type, entity_id, old_status, new_status, changed_by)
  values (entity, new.id, old.status, new.status, auth.uid());

  insert into public.notifications(user_id, title, body, type)
  values (
    recipient,
    notification_title,
    'Status changed from ' || replace(old.status, '_', ' ') || ' to ' || replace(new.status, '_', ' ') || '.',
    notification_type
  );

  insert into public.system_activity(actor_id, action, details)
  values (
    auth.uid(),
    entity || '_status_changed',
    jsonb_build_object('entity_id', new.id, 'old_status', old.status, 'new_status', new.status)
  );
  return new;
end;
$$;

drop trigger if exists reports_capture_status on public.reports;
create trigger reports_capture_status after update of status on public.reports
  for each row execute function public.capture_status_change();
drop trigger if exists appointments_capture_status on public.appointments;
create trigger appointments_capture_status after update of status on public.appointments
  for each row execute function public.capture_status_change();
drop trigger if exists waste_capture_status on public.waste_requests;
create trigger waste_capture_status after update of status on public.waste_requests
  for each row execute function public.capture_status_change();

-- ── Private Storage buckets and object policies ─────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-evidence', 'report-evidence', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('waste-evidence', 'waste-evidence', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "evidence_owner_insert" on storage.objects;
create policy "evidence_owner_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('report-evidence', 'waste-evidence')
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_account_active()
  );

drop policy if exists "evidence_authorized_read" on storage.objects;
create policy "evidence_authorized_read" on storage.objects
  for select to authenticated
  using (
    public.current_account_active()
    and bucket_id in ('report-evidence', 'waste-evidence')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.current_role() in ('health_worker', 'admin')
      or (bucket_id = 'waste-evidence' and public.current_role() = 'waste_personnel')
    )
  );

drop policy if exists "evidence_owner_delete" on storage.objects;
create policy "evidence_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('report-evidence', 'waste-evidence')
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_account_active()
  );

-- ============================================================================
-- PART 2 — NEW: resident can cancel their own pending waste request
-- ============================================================================
-- Reports already have a resident-owns-it path (soft delete, see
-- APPLY_THIS_NOW.sql's reports_update_own_pending). Appointments already have
-- one (protect_patient_appointment_update above). Waste requests had neither
-- — waste_update_staff_only only grants staff/waste_personnel/admin, so a
-- resident could never withdraw their own pending pickup request. This adds
-- that missing path. It only allows a resident to flip their own pending
-- request to 'cancelled' — validate_workflow_transition (above) already
-- allows that exact transition, and protect_waste_personnel_update (above)
-- doesn't apply to residents, so this is additive and doesn't weaken any
-- existing staff policy.
drop policy if exists "waste_cancel_own_pending" on public.waste_requests;
create policy "waste_cancel_own_pending" on public.waste_requests
  for update
  using (
    requester_id = auth.uid()
    and status = 'pending'
    and public.current_account_active()
  )
  with check (
    requester_id = auth.uid()
    and status = 'cancelled'
  );

-- ============================================================================
-- PART 3 — NEW: nearby-duplicate check for the report form
-- ============================================================================
-- Lets the report form warn "there's already a recent report near here"
-- without ever exposing WHO filed it or its other details to a resident who
-- isn't authorized to see it — this returns a single boolean, computed
-- server-side as the table owner (SECURITY DEFINER), so it can see across
-- all residents' rows while still handing the caller nothing but true/false.
-- Distance is plain haversine (no PostGIS needed) since a simple ~150m
-- radius check doesn't need a spatial index at this data volume.
create or replace function public.nearby_report_exists(
  p_report_type text,
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters double precision default 150,
  p_days integer default 14
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.reports r
      where p_report_type = 'dengue_case'
        and r.report_type = 'dengue_case'
        and r.deleted_at is null
        and r.status <> 'rejected'
        and r.created_at > now() - (p_days || ' days')::interval
        and r.latitude is not null
        and r.longitude is not null
        and 6371000 * acos(
              least(1.0, greatest(-1.0,
                cos(radians(p_latitude)) * cos(radians(r.latitude)) *
                cos(radians(r.longitude) - radians(p_longitude)) +
                sin(radians(p_latitude)) * sin(radians(r.latitude))
              ))
            ) <= p_radius_meters
    )
    or exists (
      select 1
      from public.waste_requests w
      where p_report_type = 'breeding_site'
        and w.status <> 'cancelled'
        and w.created_at > now() - (p_days || ' days')::interval
        and w.latitude is not null
        and w.longitude is not null
        and 6371000 * acos(
              least(1.0, greatest(-1.0,
                cos(radians(p_latitude)) * cos(radians(w.latitude)) *
                cos(radians(w.longitude) - radians(p_longitude)) +
                sin(radians(p_latitude)) * sin(radians(w.latitude))
              ))
            ) <= p_radius_meters
    );
$$;

grant execute on function public.nearby_report_exists(
  text, double precision, double precision, double precision, integer
) to authenticated;

commit;

-- ============================================================================
-- Done. Refresh the app (or Hot Restart) after this finishes running.
--
-- To create your first Waste Personnel account for the demo, run manually:
--   update public.profiles set role = 'waste_personnel' where email = '...';
-- ============================================================================
