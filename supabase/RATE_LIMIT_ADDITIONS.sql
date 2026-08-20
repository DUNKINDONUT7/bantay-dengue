-- ============================================================================
-- BantayDengue — closes the remaining server-side anti-spam gaps
-- Run this ONCE in Supabase Studio → SQL Editor → New query, after
-- BantayDengue_FINAL.sql. Safe to re-run (idempotent).
--
-- WHAT THIS FILE ADDS:
--   PART 1 — the same real, database-enforced rate limit that
--     APPLY_THIS_NOW.sql already gives `reports` (enforce_report_rate_limit
--     / reports_rate_limit), extended to `appointments` and `waste_requests`.
--     Both currently only have the Flutter app's client-side cooldown
--     (request_appointment_screen.dart / request_waste_screen.dart), which
--     the code's own comments already say plainly: "not a real rate limit —
--     a determined attacker can bypass any client-side check trivially."
--     This makes it actually true at the database level.
--   PART 2 — a request log + SECURITY DEFINER check function for the
--     assistant-guidance Edge Function (AI assistant), which is about to be
--     backed by a real, quota/cost-metered provider and currently has no
--     spam protection at all beyond "must be signed in."
-- ============================================================================

begin;

-- ============================================================================
-- PART 1 — real rate limits for appointments and waste_requests
-- ============================================================================

-- Max 5 appointment requests per resident per rolling 24 hours.
create or replace function public.enforce_appointment_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from public.appointments
  where patient_id = new.patient_id
    and created_at > now() - interval '24 hours';

  if recent_count >= 5 then
    raise exception
      'Too many appointment requests in the last 24 hours. Please wait before requesting another.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists appointments_rate_limit on public.appointments;
create trigger appointments_rate_limit
  before insert on public.appointments
  for each row
  execute function public.enforce_appointment_rate_limit();

-- Max 8 waste-collection requests per resident per rolling 24 hours (same
-- cap as reports — same category of operational request).
create or replace function public.enforce_waste_request_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from public.waste_requests
  where requester_id = new.requester_id
    and created_at > now() - interval '24 hours';

  if recent_count >= 8 then
    raise exception
      'Too many waste collection requests in the last 24 hours. Please wait before submitting another.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists waste_requests_rate_limit on public.waste_requests;
create trigger waste_requests_rate_limit
  before insert on public.waste_requests
  for each row
  execute function public.enforce_waste_request_rate_limit();

-- ============================================================================
-- PART 2 — real rate limit for the AI assistant
-- 6 requests per rolling 60 seconds (stops rapid-fire spam/scripts) and 40
-- per rolling 24 hours (stops sustained cost abuse). Both generous for a
-- real back-and-forth conversation.
-- ============================================================================

create table if not exists public.ai_assistant_requests (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_assistant_requests_user_time
  on public.ai_assistant_requests (user_id, created_at desc);

alter table public.ai_assistant_requests enable row level security;
-- No policies defined, on purpose: this table is unreachable through the
-- client's anon/authenticated role entirely. Only the service-role key
-- (used exclusively inside the Edge Function, never shipped to the app) can
-- read or write it, via the SECURITY DEFINER function below.

create or replace function public.check_and_log_ai_request(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  burst_count integer;
  daily_count integer;
begin
  select count(*) into burst_count
  from public.ai_assistant_requests
  where user_id = p_user_id
    and created_at > now() - interval '60 seconds';

  if burst_count >= 6 then
    return false;
  end if;

  select count(*) into daily_count
  from public.ai_assistant_requests
  where user_id = p_user_id
    and created_at > now() - interval '24 hours';

  if daily_count >= 40 then
    return false;
  end if;

  insert into public.ai_assistant_requests (user_id) values (p_user_id);

  -- Best-effort housekeeping so this table doesn't grow forever — no
  -- pg_cron dependency needed, it just prunes a couple of days back on
  -- every call.
  delete from public.ai_assistant_requests
  where created_at < now() - interval '2 days';

  return true;
end;
$$;

revoke execute on function public.check_and_log_ai_request(uuid) from public, anon, authenticated;
grant execute on function public.check_and_log_ai_request(uuid) to service_role;

commit;
