-- Run in Supabase Studio > SQL Editor, AFTER the account has already signed
-- up normally through the app's Sign Up screen (so it has a real, working
-- password Supabase itself hashed and validated — never hand-insert a row
-- into auth.users with a guessed password_hash format, that's a common way
-- to end up with an account that silently can't ever log in).
--
-- This is the ONLY supported way to create the first admin: by design, no
-- client-side code path can ever promote an account to admin (see
-- profiles_admin_update_role in schema.sql, which only lets an EXISTING
-- admin promote someone — direct SQL here is how you bootstrap the first
-- one).

update public.profiles
set role = 'admin'
where email = 'REPLACE_WITH_THE_EMAIL_YOU_SIGNED_UP_WITH';
