-- BantayDengue v2.3 follow-up migration
--
-- Deploy this after 202608110001_existing_system_integration.sql on projects
-- that already installed v2.2. Fresh installations receive the same policies
-- from the corrected 0001 migration. The role::text expressions keep this
-- compatible with both the original text role column and the supplied repaired
-- enum baseline (resident, health_worker, waste_personnel, admin).

begin;

-- The supplied enum baseline already includes `waste_personnel`. Older Bantay
-- Dengue installations used a text column, so these aliases can be converted
-- without an enum replacement or destructive table rewrite.
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

-- Residents can still see only their own requests. Waste Personnel gain the
-- operational queue but do not gain report-review or appointment privileges.
drop policy if exists "waste_select_own_or_staff" on public.waste_requests;
create policy "waste_select_own_or_staff" on public.waste_requests
  for select using (
    public.current_account_active()
    and (
      requester_id = auth.uid()
      or public.current_role() in ('health_worker', 'waste_personnel', 'admin')
    )
  );

drop policy if exists "waste_update_staff_only" on public.waste_requests;
create policy "waste_update_staff_only" on public.waste_requests
  for update using (
    public.current_role() in ('health_worker', 'waste_personnel', 'admin')
  )
  with check (
    public.current_role() in ('health_worker', 'waste_personnel', 'admin')
  );

drop policy if exists "profiles_select_own_or_staff" on public.profiles;
create policy "profiles_select_own_or_staff" on public.profiles
  for select using (
    id = auth.uid()
    or public.current_role() in ('health_worker', 'waste_personnel', 'admin')
  );

drop policy if exists "profiles_update_own_limited" on public.profiles;
create policy "profiles_update_own_limited" on public.profiles
  for update using (id = auth.uid() and public.current_account_active())
  with check (
    id = auth.uid()
    and role::text = public.current_role()
    and is_active = true
  );

drop policy if exists "notifications_insert_staff" on public.notifications;
create policy "notifications_insert_staff" on public.notifications
  for insert with check (public.current_role() in ('health_worker', 'admin'));
-- Waste workflow notifications are emitted by the security-definer status
-- trigger instead of granting personnel arbitrary notification inserts.

drop policy if exists "status_history_read_authorized" on public.status_history;
create policy "status_history_read_authorized" on public.status_history
  for select using (
    public.current_role() = 'admin'
    or (
      entity_type = 'report'
      and (
        public.current_role() = 'health_worker'
        or exists (
          select 1 from public.reports r
          where r.id = entity_id and r.reporter_id = auth.uid()
        )
      )
    )
    or (
      entity_type = 'appointment'
      and (
        public.current_role() = 'health_worker'
        or exists (
          select 1 from public.appointments a
          where a.id = entity_id and a.patient_id = auth.uid()
        )
      )
    )
    or (
      entity_type = 'waste_request'
      and (
        public.current_role() in ('health_worker', 'waste_personnel')
        or exists (
          select 1 from public.waste_requests w
          where w.id = entity_id and w.requester_id = auth.uid()
        )
      )
    )
  );

-- Personnel may claim an unassigned request, but cannot rewrite the resident's
-- submission or take over work already assigned to another personnel account.
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

drop trigger if exists waste_protect_personnel_update
  on public.waste_requests;
create trigger waste_protect_personnel_update
  before update on public.waste_requests
  for each row execute function public.protect_waste_personnel_update();

-- Private evidence remains owner-readable. Waste Personnel can read only the
-- waste bucket, while health workers/admins retain their broader evidence role.
drop policy if exists "evidence_authorized_read" on storage.objects;
create policy "evidence_authorized_read" on storage.objects
  for select to authenticated
  using (
    public.current_account_active()
    and bucket_id in ('report-evidence', 'waste-evidence')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.current_role() in ('health_worker', 'admin')
      or (
        bucket_id = 'waste-evidence'
        and public.current_role() = 'waste_personnel'
      )
    )
  );

commit;
