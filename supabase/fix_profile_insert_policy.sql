-- Run in Supabase Studio > SQL Editor. Safe to re-run.
--
-- Fixes a real bug in the original profiles_insert_own_default_role policy:
-- it checked the new row's email against `(select email from auth.users
-- where id = auth.uid())`. The `authenticated` role has no SELECT grant on
-- auth.users by default in Supabase (that table is intentionally locked
-- down), so that subquery threw:
--   permission denied for table users (Postgres code 42501)
-- every time this policy actually had to evaluate — i.e. whenever a
-- signed-in user's profile row was missing and the app tried to create it
-- client-side. You'd have seen this in the Flutter logs as repeating
-- "Profile repair failed ... permission denied for table users" /
-- "Unable to load or repair profile" for the same user id, forever, on
-- every hot restart. That account was functionally stuck: authenticated,
-- but with no profile the rest of the app could use.
--
-- This file (1) fixes the policy so it can never fail that way again, and
-- (2) backfills a profile row for any existing auth user this already
-- happened to.

drop policy if exists "profiles_insert_own_default_role" on public.profiles;
create policy "profiles_insert_own_default_role" on public.profiles
  for insert with check (
    id = auth.uid()
    and role = 'resident'

    and email = coalesce(auth.jwt() ->> 'email', '')
  );

-- Backfill: create a 'resident' profile for every auth.users row that
-- doesn't already have one. Run as the Studio SQL Editor's postgres role,
-- which — unlike the app's `authenticated` role — can read auth.users, so
-- this works even though the RLS policy above intentionally can't.
insert into public.profiles (id, full_name, email, role)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1)),
  u.email,
  'resident'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
