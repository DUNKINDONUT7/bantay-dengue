# Supabase — what's live, what's pending, run order

The database is never auto-migrated by the app. Every file below is applied by hand, once, in **Supabase Studio → SQL Editor → New query**, by an authorized project owner. This file is the index — check it before running or writing any SQL here, instead of guessing from file names or comments inside the files (some of those comments have been wrong before; see the incident note in `APPLY_THIS_NOW.sql`).

Status below was confirmed live on **2026-08-20** by querying the actual project (`information_schema`, `pg_proc`, `storage.buckets`) — not assumed from the files. Steps 7 and 8 were confirmed live on **2026-08-23**.

## Incident: this status table itself was wrong once

On 2026-08-23, `waste_requests` was found live-missing the `handled_by`/`photo_url`/`completion_photo_url` columns and the `waste_personnel` RLS grant that `BantayDengue_FINAL.sql` (marked "✅ Applied" below, correctly) adds — because `APPLY_THIS_NOW.sql` (marked "**Do not re-run**" below) had evidently been re-run *after* it, silently reverting those changes with no error. Separately, the same audit found Step 7 below was actually already live despite being marked "not confirmed" — the opposite kind of drift. Both were only caught by querying `pg_policies`/`information_schema` directly against the live project, not by reading this table.

`MIGRATION_LEDGER.sql` (Step 8) exists because of this: a ledger the database itself enforces, so "was this actually applied, and did anything undo it since" stops depending on a human keeping this markdown table perfectly in sync. **This table is still the index to read first** — the ledger doesn't replace it, it backstops it.

## Run order (incremental path — what actually built this project)

| # | File | Status | What it does |
|---|---|---|---|
| 1 | `schema.sql` | ✅ Applied | Base tables, RLS, core policies |
| 2 | `APPLY_THIS_NOW.sql` | ✅ Applied | Rebuilds `reports`/`waste_requests` (fixes contamination from an abandoned schema — see `_archive/README.md`), report rate limit, profile-insert fix. **Do not re-run** — see the warning at the top of that file |
| 3 | `BantayDengue_FINAL.sql` | ✅ Applied | Waste Personnel role/workflow, account suspension, `status_history`, notifications, audit triggers |
| 4 | `RATE_LIMIT_ADDITIONS.sql` | ✅ Applied | Extends the database-enforced rate limit to `appointments` and `waste_requests` |
| 5 | `AVATAR_STORAGE.sql` | ✅ Applied | Public avatar storage bucket + RLS — confirmed live: `avatars` bucket exists, public, 3 MiB limit |
| 6 | `APPLY_APPOINTMENTS_FIX.sql` | ✅ Applied | Rebuilds `appointments` — confirmed live: correct columns (`patient_id`, `assigned_doctor`, `scheduled_at`, `reason`, `status`), no leftover NOT NULL contamination. **Do not re-run** — table now holds real bookings |
| 7 | `fix_profile_insert_policy.sql` | ✅ Applied — confirmed live 2026-08-23 (`pg_policies.with_check` matches this file's `auth.jwt() ->> 'email'` fix exactly, no `auth.users` subquery) | Fixes `profiles_insert_own_default_role`: the old policy queried `auth.users` in a subquery, which the `authenticated` role can't read, so it threw `permission denied for table users` and left signed-in users stuck with no profile row. Also backfills a `resident` profile for any existing `auth.users` row missing one. Safe to re-run. |
| 8 | `MIGRATION_LEDGER.sql` | ✅ Applied — confirmed live 2026-08-23 (`schema_migrations` holds exactly the 8 expected rows; RLS enabled, zero policies) | Adds `public.schema_migrations`, backfilled with steps 1–7 plus itself, and the guard/record convention every future file must follow — see the incident note above and the comments at the top of that file |
| 9 | `COMMUNITY_STORIES.sql` | ✅ Applied — confirmed live 2026-08-23 (ledger row present; `community_posts`/`community_comments`/`community_reactions` columns and RLS policies match the file; all 4 triggers present; `community-photos` bucket public, 5 MiB limit) | Resident-only peer-support feed: posts, comments, one "love" reaction, admin moderation, rate limits, engagement notifications, public photo bucket. First file to use the Step 8 ledger convention for real — see the comments at the top of that file for the scope decisions made |
| 10 | `COMMUNITY_AUTHOR_LOOKUP.sql` | ✅ Applied — confirmed live 2026-08-23 (`community_author_info` exists, `prosecdef=true`, callable) | Narrow SECURITY DEFINER function so a resident can see another resident's name/photo on a community post — `profiles`' own RLS only lets a resident read their own row, which Step 9's Postgrest embed silently relied on and would have returned null authors for. Caught in review before this ever reached a real user — see the comments at the top of that file |
| 11 | `COMMUNITY_REALTIME.sql` | ✅ Applied — confirmed live 2026-08-23 (`pg_publication_tables` for `supabase_realtime` lists all 3 community tables) | Adds `community_posts`/`community_comments`/`community_reactions` to the `supabase_realtime` publication + `REPLICA IDENTITY FULL` on all three, so the feed updates live on other residents' screens instead of requiring pull-to-refresh |
| 12 | `COMMUNITY_NOTIFICATION_TYPES_FIX.sql` | ✅ Applied — confirmed live 2026-08-23 (`notifications_type_check` now includes `community_comment`/`community_reaction`) | **Bug fix, not a feature.** `notifications_type_check` was never updated when Step 9 added `notify_community_comment()`/`notify_community_reaction()` — every comment and every reaction on a community post was failing outright (the trigger's own notification insert violated the check constraint, aborting the whole transaction, so the comment/reaction row itself never committed either). Found while seeding demo data, not by inspection — see the comments at the top of that file |
| 13 | `NOTIFICATIONS_REALTIME.sql` | ✅ Applied — confirmed live 2026-08-23 (`pg_publication_tables` for `supabase_realtime` now also lists `notifications`) | Adds `notifications` to the `supabase_realtime` publication + `REPLICA IDENTITY FULL`, so the global notification bell's unread badge (`main_shell.dart`'s `NotificationBellButton`) updates live instead of only refreshing on the next shell rebuild |

Steps 1–13 are applied and confirmed live as of 2026-08-23.

## Standalone / as-needed

| File | When to run it |
|---|---|
| `promote_to_admin.sql` | Once, to bootstrap the very first admin account after it has signed up normally through the app |
| `COMMUNITY_SEED_DEMO_DATA.sql` | Dev/demo only — backdated fake posts/comments/reactions on the Community Stories feed so there's enough volume to judge the UI with. Attributed to real existing resident accounts (no fake auth users created). Every row's content ends in an invisible zero-width-space marker (`chr(8203)`) for easy identification/removal without a visible "[seed]" tag showing up in the actual feed UI — see the comment block at the top of that file. Applied live 2026-08-23: 28 posts, 26 comments, 23 reactions |
| `BantayDengue_Full_Database_v2.3.sql` | Only for a **fresh, blank** Supabase project as a single-file alternative to steps 1–4 above. Do not run against this already-configured project — it is not written to be idempotent against existing tables |

## Folder layout

```
supabase/
├── README.md                    ← you are here
├── config.toml                  Supabase CLI project config
├── schema.sql                   Step 1 (applied)
├── APPLY_THIS_NOW.sql           Step 2 (applied — do not re-run)
├── BantayDengue_FINAL.sql       Step 3 (applied)
├── RATE_LIMIT_ADDITIONS.sql     Step 4 (applied)
├── AVATAR_STORAGE.sql           Step 5 (applied)
├── APPLY_APPOINTMENTS_FIX.sql   Step 6 (applied — do not re-run)
├── fix_profile_insert_policy.sql   Step 7 (applied, safe to re-run)
├── MIGRATION_LEDGER.sql         Step 8 (applied)
├── COMMUNITY_STORIES.sql        Step 9 (applied)
├── COMMUNITY_AUTHOR_LOOKUP.sql  Step 10 (applied)
├── check_live_schema.sh         Drift-check helper (columns/policies/ledger) — bash
├── check_live_schema.ps1        Same, for Windows PowerShell
├── BantayDengue_Full_Database_v2.3.sql   Fresh-install alternative only
├── promote_to_admin.sql         Standalone utility
├── functions/                   Edge Functions (assistant-guidance, weather-risk)
├── _archive/                    Superseded/never-applied files — do not run, do not migrate. See _archive/README.md
└── .temp/                       Supabase CLI local cache — not committed, ignore
```

## Before writing new SQL against this project

The live schema has drifted from the SQL files here before (see `_archive/README.md` and the incident note above) — comments, file names, and even this status table are not reliable ground truth on their own. Confirm what's actually live first:

```bash
# bash
supabase/check_live_schema.sh columns <table>
supabase/check_live_schema.sh policies <table>
supabase/check_live_schema.sh ledger
```
```powershell
# Windows PowerShell
supabase/check_live_schema.ps1 columns <table>
supabase/check_live_schema.ps1 policies <table>
supabase/check_live_schema.ps1 ledger
```

These wrap the Supabase Management API (no DB password needed) and are read-only/safe. Never assume a table's shape — or that a file was actually applied — without checking. That assumption caused three separate bugs in one afternoon (`reports`/`waste_requests`, `appointments`, `hotspots`) plus the `waste_personnel` RLS-drift incident above.

## New SQL files must follow the ledger convention (Step 8 onward)

Every `.sql` file added to this folder after `MIGRATION_LEDGER.sql` must:
1. Guard at the top against `public.schema_migrations` already containing its filename (raise an exception if so).
2. Record itself into `public.schema_migrations` at the bottom, inside the same transaction as its other changes.
3. Get a new row in the run-order table above, in the same PR.

See the comment block at the top of `MIGRATION_LEDGER.sql` for the exact pattern.

## Never re-run a file that "succeeded once"

Several files in this folder use `DROP TABLE IF EXISTS ... CASCADE` to fix a table's shape. That is safe to run **once**, and permanently deletes every row in that table **every time it runs after that**. Before running any file here a second time, open it and check whether it contains `DROP TABLE` — if it does, don't, unless the table is confirmed empty first.
