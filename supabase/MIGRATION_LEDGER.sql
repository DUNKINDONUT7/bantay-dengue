-- ============================================================================
-- Migration safety net — run this ONCE in Supabase Studio -> SQL Editor.
-- Safe to re-run (idempotent): CREATE TABLE IF NOT EXISTS, ON CONFLICT DO
-- NOTHING throughout.
--
-- WHY THIS EXISTS
-- On 2026-08-23 the live `waste_requests` table was found to have silently
-- reverted to an older shape: `APPLY_THIS_NOW.sql` (explicitly marked "do
-- not re-run" in this same folder) had been re-run at some point AFTER
-- `BantayDengue_FINAL.sql`, which quietly dropped the waste_personnel RLS
-- grant and the handled_by/photo_url/completion_photo_url columns that file
-- adds. Nothing errored. The Waste Personnel role's dashboard just showed
-- zero rows, with no indication why. It was only caught by manually
-- querying pg_policies and information_schema against the live project and
-- comparing against what the file claims it does.
--
-- supabase/README.md's own status table is comments-and-trust — exactly the
-- kind of file-level claim that already turned out to be stale once (see
-- the incident note in APPLY_THIS_NOW.sql, and note this same session found
-- Step 7 below marked "not confirmed live" in the README when it was, in
-- fact, already live — verified directly against pg_policies).
--
-- This does NOT revive `supabase migrations`/`db push` CLI tooling —
-- supabase/migrations/ holds an abandoned, incompatible PostGIS-based
-- redesign (see that folder and _archive/README.md) that a `db push` would
-- try to reconcile against this project's actual schema. The fix here is
-- narrower and additive: a ledger table the DATABASE ITSELF can be queried
-- against, replacing "check a markdown table by eye."
--
-- CONVENTION FOR EVERY FUTURE .sql FILE IN THIS FOLDER, FROM NOW ON:
--   1. Guard at the top:
--        do $$
--        begin
--          if exists (select 1 from public.schema_migrations where filename = 'YOUR_FILE.sql') then
--            raise exception 'YOUR_FILE.sql has already been applied — see supabase/README.md before re-running.';
--          end if;
--        end $$;
--   2. Record at the bottom, inside the same transaction as the rest of the
--      file's changes (so a failed file never gets falsely marked applied):
--        insert into public.schema_migrations (filename) values ('YOUR_FILE.sql');
--   3. Update the run-order table in supabase/README.md in the same PR.
--
-- Files already applied before this ledger existed are backfilled below
-- with today's date as `applied_at` — that is the backfill date, not each
-- file's true historical apply date, which was never recorded.
-- ============================================================================

begin;

create table if not exists public.schema_migrations (
  filename text primary key,
  applied_at timestamptz not null default now()
);

-- Internal bookkeeping only — no client (resident, staff, or admin) ever
-- needs to read or write this. RLS enabled with zero policies means only
-- the service-role/Studio connection can touch it, the same deliberate
-- deny-all-to-clients posture already used for `ai_assistant_requests`
-- (see RATE_LIMIT_ADDITIONS.sql).
alter table public.schema_migrations enable row level security;

insert into public.schema_migrations (filename) values
  ('schema.sql'),
  ('APPLY_THIS_NOW.sql'),
  ('BantayDengue_FINAL.sql'),
  ('RATE_LIMIT_ADDITIONS.sql'),
  ('AVATAR_STORAGE.sql'),
  ('APPLY_APPOINTMENTS_FIX.sql'),
  ('fix_profile_insert_policy.sql'),
  ('MIGRATION_LEDGER.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select filename, applied_at from public.schema_migrations order by filename;
-- Should return exactly the 8 rows above.
-- ============================================================================
