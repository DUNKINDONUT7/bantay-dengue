-- BantayDengue Supabase schema
-- Apply with: supabase db reset (local) or supabase db push (linked project)

create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;

create type public.app_role as enum ('resident', 'health_worker', 'waste_staff', 'admin');
create type public.report_type as enum ('suspected_case', 'breeding_site', 'waste');
create type public.report_status as enum ('pending', 'needs_information', 'verified', 'rejected', 'resolved');
create type public.risk_level as enum ('low', 'moderate', 'high', 'critical');
create type public.appointment_status as enum ('pending', 'approved', 'rescheduled', 'completed', 'cancelled');
create type public.waste_status as enum ('for_scheduling', 'scheduled', 'assigned', 'in_progress', 'collected', 'cancelled');

create table public.barangays (
  psgc_code text primary key,
  name text not null,
  municipality_psgc_code text not null,
  municipality_name text not null default 'Marilao',
  province_name text not null default 'Bulacan',
  boundary extensions.geometry(MultiPolygon, 4326),
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 120),
  role public.app_role not null default 'resident',
  barangay_code text references public.barangays(psgc_code),
  municipality_psgc_code text not null default '031410000',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reference_no text not null unique default ('RPT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  reporter_id uuid not null references public.profiles(id),
  type public.report_type not null,
  title text not null check (char_length(title) between 4 and 140),
  description text not null check (char_length(description) between 8 and 3000),
  barangay_code text not null references public.barangays(psgc_code),
  address text not null check (char_length(address) <= 300),
  exact_location extensions.geography(Point, 4326) not null,
  public_location extensions.geography(Point, 4326) not null,
  status public.report_status not null default 'pending',
  risk public.risk_level not null default 'moderate',
  symptoms text[] not null default '{}',
  has_evidence boolean not null default false,
  assigned_to uuid references public.profiles(id),
  review_note text check (char_length(review_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint suspected_case_symptoms check (type <> 'suspected_case' or cardinality(symptoms) > 0)
);

create table public.report_evidence (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  uploader_id uuid not null references public.profiles(id),
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  byte_size integer not null check (byte_size between 1 and 5242880),
  created_at timestamptz not null default now()
);

create table public.report_status_events (
  id bigint generated always as identity primary key,
  report_id uuid not null references public.reports(id) on delete cascade,
  from_status public.report_status,
  to_status public.report_status not null,
  actor_id uuid references public.profiles(id),
  note text check (char_length(note) <= 2000),
  created_at timestamptz not null default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  reference_no text not null unique default ('APT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  resident_id uuid not null references public.profiles(id),
  barangay_code text not null references public.barangays(psgc_code),
  health_center text not null check (char_length(health_center) <= 180),
  scheduled_at timestamptz not null,
  reason text not null check (char_length(reason) between 4 and 1000),
  status public.appointment_status not null default 'pending',
  managed_by uuid references public.profiles(id),
  check_in_token_hash text,
  token_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.waste_requests (
  id uuid primary key default gen_random_uuid(),
  reference_no text not null unique default ('WR-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  source_report_id uuid references public.reports(id),
  requester_id uuid not null references public.profiles(id),
  barangay_code text not null references public.barangays(psgc_code),
  title text not null check (char_length(title) between 4 and 140),
  location_description text not null check (char_length(location_description) <= 300),
  exact_location extensions.geography(Point, 4326) not null,
  scheduled_at timestamptz,
  status public.waste_status not null default 'for_scheduling',
  priority public.risk_level not null default 'moderate',
  assigned_to uuid references public.profiles(id),
  completion_note text check (char_length(completion_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.advisories (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 4 and 160),
  message text not null check (char_length(message) between 10 and 4000),
  audience_barangay_code text references public.barangays(psgc_code),
  audience_label text not null default 'All barangays',
  severity public.risk_level not null default 'moderate',
  published_by uuid not null references public.profiles(id),
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_table text not null,
  entity_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index reports_created_at_idx on public.reports(created_at desc);
create index reports_status_idx on public.reports(status, type);
create index reports_barangay_idx on public.reports(barangay_code, status);
create index reports_exact_location_gix on public.reports using gist(exact_location);
create index reports_public_location_gix on public.reports using gist(public_location);
create index waste_requests_location_gix on public.waste_requests using gist(exact_location);
create index appointments_resident_schedule_idx on public.appointments(resident_id, scheduled_at desc);
create index advisories_published_idx on public.advisories(published_at desc) where is_active;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger reports_set_updated_at before update on public.reports for each row execute function public.set_updated_at();
create trigger appointments_set_updated_at before update on public.appointments for each row execute function public.set_updated_at();
create trigger waste_set_updated_at before update on public.waste_requests for each row execute function public.set_updated_at();
revoke all on function public.set_updated_at() from public;

-- The server, not the client, chooses the public map coordinate. Suspected-case
-- points are displaced 250–600 meters in a random direction.
create or replace function public.set_report_public_location()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.type = 'suspected_case'::public.report_type then
    new.public_location = extensions.st_project(new.exact_location, 250 + random() * 350, random() * 2 * pi());
  else
    new.public_location = new.exact_location;
  end if;
  return new;
end;
$$;

create trigger reports_set_public_location before insert or update of exact_location, type on public.reports for each row execute function public.set_report_public_location();

-- Signup metadata never controls privileged roles. Every public signup starts as resident.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  safe_display_name text := left(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 120);
  safe_barangay_code text;
begin
  if char_length(safe_display_name) < 2 then
    safe_display_name := 'New Resident';
  end if;

  -- Ignore unknown or out-of-municipality metadata instead of failing signup.
  select b.psgc_code into safe_barangay_code
  from public.barangays b
  where b.psgc_code = nullif(new.raw_user_meta_data ->> 'barangay_code', '')
    and b.municipality_psgc_code = '031410000'
  limit 1;

  insert into public.profiles (id, display_name, role, barangay_code)
  values (new.id, safe_display_name, 'resident'::public.app_role, safe_barangay_code);
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
revoke all on function public.handle_new_user() from public;

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid() and is_active = true;
$$;

create or replace function public.current_barangay_code()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select barangay_code from public.profiles where id = auth.uid() and is_active = true;
$$;

revoke all on function public.current_app_role() from public;
revoke all on function public.current_barangay_code() from public;
grant execute on function public.current_app_role() to authenticated;
grant execute on function public.current_barangay_code() to authenticated;

-- Public map RPC exposes no reporter, address, symptoms, exact coordinates, or evidence.
create or replace function public.get_public_report_markers(
  min_lat double precision default 14.70,
  min_lng double precision default 120.90,
  max_lat double precision default 14.82,
  max_lng double precision default 121.02
)
returns table (
  id uuid,
  reference_no text,
  type public.report_type,
  barangay_code text,
  status public.report_status,
  risk public.risk_level,
  latitude double precision,
  longitude double precision,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.reference_no, r.type, r.barangay_code, r.status, r.risk,
         extensions.st_y(r.public_location::extensions.geometry) as latitude,
         extensions.st_x(r.public_location::extensions.geometry) as longitude,
         r.created_at
  from public.reports r
  where auth.uid() is not null
    and public.current_app_role() is not null
    and r.status in ('verified'::public.report_status, 'resolved'::public.report_status)
    and extensions.st_intersects(
      r.public_location,
      extensions.st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::extensions.geography
    )
  order by r.created_at desc
  limit 500;
$$;

revoke all on function public.get_public_report_markers(double precision, double precision, double precision, double precision) from public;
grant execute on function public.get_public_report_markers(double precision, double precision, double precision, double precision) to authenticated;

-- Immutable report timeline.
create or replace function public.record_report_status_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.report_status_events(report_id, from_status, to_status, actor_id)
    values (new.id, null, new.status, new.reporter_id);
  elsif new.status is distinct from old.status then
    insert into public.report_status_events(report_id, from_status, to_status, actor_id, note)
    values (new.id, old.status, new.status, auth.uid(), new.review_note);
  end if;
  return new;
end;
$$;

create trigger reports_status_timeline after insert or update of status on public.reports for each row execute function public.record_report_status_event();

alter table public.barangays enable row level security;
alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.report_evidence enable row level security;
alter table public.report_status_events enable row level security;
alter table public.appointments enable row level security;
alter table public.waste_requests enable row level security;
alter table public.advisories enable row level security;
alter table public.audit_logs enable row level security;

create policy barangays_authenticated_read on public.barangays for select to authenticated using (true);

create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.current_app_role() = 'admin'::public.app_role);
create policy profiles_admin_update on public.profiles for update to authenticated
using (public.current_app_role() = 'admin'::public.app_role)
with check (public.current_app_role() = 'admin'::public.app_role);

create policy reports_insert_resident on public.reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and public.current_app_role() = 'resident'::public.app_role
  and status = 'pending'::public.report_status
  and risk = 'moderate'::public.risk_level
  and has_evidence = false
  and assigned_to is null
  and review_note is null
  and resolved_at is null
);
create policy reports_read_owner_or_authorized_staff on public.reports for select to authenticated
using (
  public.current_app_role() is not null
  and (
  reporter_id = auth.uid()
  or public.current_app_role() = 'admin'::public.app_role
  or (
    public.current_app_role() = 'health_worker'::public.app_role
    and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())
  )
  or (
    public.current_app_role() = 'waste_staff'::public.app_role
    and type in ('breeding_site'::public.report_type, 'waste'::public.report_type)
    and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())
  )
  )
);
create policy reports_update_authorized_staff on public.reports for update to authenticated
using (
  public.current_app_role() = 'admin'::public.app_role
  or (public.current_app_role() = 'health_worker'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
  or (public.current_app_role() = 'waste_staff'::public.app_role and type in ('breeding_site'::public.report_type, 'waste'::public.report_type) and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
)
with check (
  public.current_app_role() = 'admin'::public.app_role
  or (public.current_app_role() = 'health_worker'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
  or (public.current_app_role() = 'waste_staff'::public.app_role and type in ('breeding_site'::public.report_type, 'waste'::public.report_type) and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
);

create policy evidence_read_owner_or_staff on public.report_evidence for select to authenticated
using (exists (select 1 from public.reports r where r.id = report_id));
create policy evidence_insert_owner on public.report_evidence for insert to authenticated
with check (
  uploader_id = auth.uid()
  and public.current_app_role() = 'resident'::public.app_role
  and (storage.foldername(storage_path))[1] = auth.uid()::text
  and exists (
    select 1 from public.reports r
    where r.id = report_id and r.reporter_id = auth.uid()
  )
);

create policy timeline_read_via_report on public.report_status_events for select to authenticated
using (exists (select 1 from public.reports r where r.id = report_id));

create policy appointments_read_owner_or_staff on public.appointments for select to authenticated
using (
  public.current_app_role() is not null
  and (
    resident_id = auth.uid()
    or public.current_app_role() = 'admin'::public.app_role
    or (public.current_app_role() = 'health_worker'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
  )
);
create policy appointments_insert_resident on public.appointments for insert to authenticated
with check (
  resident_id = auth.uid()
  and public.current_app_role() = 'resident'::public.app_role
  and status = 'pending'::public.appointment_status
  and managed_by is null
  and check_in_token_hash is null
  and token_expires_at is null
);
create policy appointments_update_health_admin on public.appointments for update to authenticated
using (public.current_app_role() = 'admin'::public.app_role or (public.current_app_role() = 'health_worker'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())))
with check (public.current_app_role() = 'admin'::public.app_role or (public.current_app_role() = 'health_worker'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())));

create policy waste_read_owner_or_staff on public.waste_requests for select to authenticated
using (
  public.current_app_role() is not null
  and (
    requester_id = auth.uid()
    or public.current_app_role() = 'admin'::public.app_role
    or (public.current_app_role() = 'waste_staff'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code()))
  )
);
create policy waste_insert_resident on public.waste_requests for insert to authenticated
with check (
  requester_id = auth.uid()
  and public.current_app_role() = 'resident'::public.app_role
  and status = 'for_scheduling'::public.waste_status
  and priority = 'moderate'::public.risk_level
  and scheduled_at is null
  and assigned_to is null
  and completion_note is null
  and (
    source_report_id is null
    or exists (
      select 1 from public.reports r
      where r.id = source_report_id
        and r.reporter_id = auth.uid()
        and r.type in ('breeding_site'::public.report_type, 'waste'::public.report_type)
    )
  )
);
create policy waste_update_staff on public.waste_requests for update to authenticated
using (public.current_app_role() = 'admin'::public.app_role or (public.current_app_role() = 'waste_staff'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())))
with check (public.current_app_role() = 'admin'::public.app_role or (public.current_app_role() = 'waste_staff'::public.app_role and (public.current_barangay_code() is null or barangay_code = public.current_barangay_code())));

create policy advisories_authenticated_read on public.advisories for select to authenticated
using (
  public.current_app_role() is not null
  and is_active
  and (expires_at is null or expires_at > now())
  and (audience_barangay_code is null or audience_barangay_code = public.current_barangay_code() or public.current_app_role() in ('health_worker'::public.app_role, 'waste_staff'::public.app_role, 'admin'::public.app_role))
);
create policy advisories_publish_authorized on public.advisories for insert to authenticated
with check (published_by = auth.uid() and public.current_app_role() in ('health_worker'::public.app_role, 'admin'::public.app_role));
create policy advisories_admin_update on public.advisories for update to authenticated
using (public.current_app_role() = 'admin'::public.app_role)
with check (public.current_app_role() = 'admin'::public.app_role);

create policy audit_admin_read on public.audit_logs for select to authenticated
using (public.current_app_role() = 'admin'::public.app_role);

-- Limit direct mutation to explicit profile/workflow columns. Server-maintained
-- identity, publisher, and timestamp columns are not client-writable.
revoke update on public.profiles from authenticated;
grant update (display_name, role, barangay_code, is_active) on public.profiles to authenticated;
revoke update on public.reports from authenticated;
grant update (status, risk, assigned_to, review_note, resolved_at) on public.reports to authenticated;
revoke update on public.appointments from authenticated;
grant update (scheduled_at, status, managed_by, check_in_token_hash, token_expires_at) on public.appointments to authenticated;
revoke update on public.waste_requests from authenticated;
grant update (scheduled_at, status, priority, assigned_to, completion_note) on public.waste_requests to authenticated;
revoke update on public.advisories from authenticated;
grant update (title, message, audience_barangay_code, audience_label, severity, expires_at, is_active) on public.advisories to authenticated;

-- Evidence bucket is private; access uses authenticated queries or short-lived signed URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-evidence', 'report-evidence', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy evidence_storage_insert_own_folder on storage.objects for insert to authenticated
with check (
  bucket_id = 'report-evidence'
  and public.current_app_role() = 'resident'::public.app_role
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy evidence_storage_read_own_or_authorized on storage.objects for select to authenticated
using (
  bucket_id = 'report-evidence'
  and public.current_app_role() is not null
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or (
      public.current_app_role() in ('health_worker'::public.app_role, 'admin'::public.app_role)
      and exists (
        select 1 from public.report_evidence e
        where e.storage_path = name
      )
    )
  )
);
create policy evidence_storage_delete_own_folder on storage.objects for delete to authenticated
using (
  bucket_id = 'report-evidence'
  and public.current_app_role() = 'resident'::public.app_role
  and (storage.foldername(name))[1] = auth.uid()::text
);

insert into public.barangays(psgc_code, name, municipality_psgc_code) values
  ('031410001', 'Abangan Norte', '031410000'),
  ('031410002', 'Abangan Sur', '031410000'),
  ('031410005', 'Ibayo', '031410000'),
  ('031410006', 'Lambakin', '031410000'),
  ('031410007', 'Lias', '031410000'),
  ('031410008', 'Loma de Gato', '031410000'),
  ('031410009', 'Nagbalon', '031410000'),
  ('031410010', 'Patubig', '031410000'),
  ('031410011', 'Poblacion I', '031410000'),
  ('031410012', 'Poblacion II', '031410000'),
  ('031410013', 'Prenza I', '031410000'),
  ('031410014', 'Prenza II', '031410000'),
  ('031410015', 'Santa Rosa I', '031410000'),
  ('031410016', 'Santa Rosa II', '031410000'),
  ('031410017', 'Saog', '031410000'),
  ('031410018', 'Tabing Ilog', '031410000')
on conflict (psgc_code) do nothing;

-- Realtime is optional but useful for operational queues.
do $$
begin
  alter publication supabase_realtime add table public.reports;
  alter publication supabase_realtime add table public.appointments;
  alter publication supabase_realtime add table public.waste_requests;
  alter publication supabase_realtime add table public.advisories;
exception when duplicate_object then null;
end $$;
