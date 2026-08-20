# Supabase — what's live, what's pending, run order

The database is never auto-migrated by the app. Every file below is applied by hand, once, in **Supabase Studio → SQL Editor → New query**, by an authorized project owner. This file is the index — check it before running or writing any SQL here, instead of guessing from file names or comments inside the files (some of those comments have been wrong before; see the incident note in `APPLY_THIS_NOW.sql`).

Status below was confirmed live on **2026-08-20** by querying the actual project (`information_schema`, `pg_proc`, `storage.buckets`) — not assumed from the files.

## Run order (incremental path — what actually built this project)

| # | File | Status | What it does |
|---|---|---|---|
| 1 | `schema.sql` | ✅ Applied | Base tables, RLS, core policies |
| 2 | `APPLY_THIS_NOW.sql` | ✅ Applied | Rebuilds `reports`/`waste_requests` (fixes contamination from an abandoned schema — see `_archive/README.md`), report rate limit, profile-insert fix. **Do not re-run** — see the warning at the top of that file |
| 3 | `BantayDengue_FINAL.sql` | ✅ Applied | Waste Personnel role/workflow, account suspension, `status_history`, notifications, audit triggers |
| 4 | `RATE_LIMIT_ADDITIONS.sql` | ✅ Applied | Extends the database-enforced rate limit to `appointments` and `waste_requests` |
| 5 | `AVATAR_STORAGE.sql` | ✅ Applied | Public avatar storage bucket + RLS — confirmed live: `avatars` bucket exists, public, 3 MiB limit |
| 6 | `APPLY_APPOINTMENTS_FIX.sql` | ✅ Applied | Rebuilds `appointments` — confirmed live: correct columns (`patient_id`, `assigned_doctor`, `scheduled_at`, `reason`, `status`), no leftover NOT NULL contamination. **Do not re-run** — table now holds real bookings |

Everything in the incremental path is applied. Appointment booking and avatar upload are unblocked as of 2026-08-20.

## Standalone / as-needed

| File | When to run it |
|---|---|
| `promote_to_admin.sql` | Once, to bootstrap the very first admin account after it has signed up normally through the app |
| `BantayDengue_Full_Database_v2.3.sql` | Only for a **fresh, blank** Supabase project as a single-file alternative to steps 1–4 above. Do not run against this already-configured project — it is not written to be idempotent against existing tables |

## Folder layout

```
supabase/
├── README.md                    ← you are here
├── config.toml                  Supabase CLI project config
├── schema.sql                   Step 1
├── APPLY_THIS_NOW.sql           Step 2 (applied — do not re-run)
├── BantayDengue_FINAL.sql       Step 3 (applied)
├── RATE_LIMIT_ADDITIONS.sql     Step 4 (applied)
├── AVATAR_STORAGE.sql           Step 5 (pending)
├── APPLY_APPOINTMENTS_FIX.sql   Step 6 (pending)
├── BantayDengue_Full_Database_v2.3.sql   Fresh-install alternative only
├── promote_to_admin.sql         Standalone utility
├── functions/                   Edge Functions (assistant-guidance, weather-risk)
├── _archive/                    Superseded/never-applied files — do not run, do not migrate. See _archive/README.md
└── .temp/                       Supabase CLI local cache — not committed, ignore
```

## Before writing new SQL against this project

The live schema has drifted from the SQL files here before (see `_archive/README.md`) — comments and file names are not reliable ground truth. Confirm what's actually live first:

```bash
supabase db query --linked "select column_name, data_type, is_nullable from information_schema.columns where table_schema='public' and table_name='<table>' order by ordinal_position;"
```

This uses the Supabase Management API (no DB password needed) and is read-only/safe. Never assume a table's shape from `schema.sql` alone without checking — that assumption caused three separate bugs in one afternoon (`reports`/`waste_requests`, `appointments`, `hotspots`).

## Never re-run a file that "succeeded once"

Several files in this folder use `DROP TABLE IF EXISTS ... CASCADE` to fix a table's shape. That is safe to run **once**, and permanently deletes every row in that table **every time it runs after that**. Before running any file here a second time, open it and check whether it contains `DROP TABLE` — if it does, don't, unless the table is confirmed empty first.
