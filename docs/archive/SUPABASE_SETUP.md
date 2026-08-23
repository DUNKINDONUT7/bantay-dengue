# Supabase setup

## Prerequisites

- A Supabase project or local Supabase CLI installation
- Docker Desktop for local Supabase
- A Flutter environment for client testing

## Local backend

From the project root:

```bash
supabase start
supabase db reset
```

The migration creates:

- PostgreSQL enums and operational tables
- PostGIS geography columns and GiST indexes
- auth profile trigger (all signups start as Resident)
- RLS policies by ownership, role, and barangay jurisdiction
- a privacy-safe `get_public_report_markers` RPC
- immutable report status events
- private `report-evidence` storage bucket and policies
- seeded Marilao barangay reference rows
- Realtime publication entries

Copy the local API URL and publishable/anon key from `supabase status`, then run:

```bash
flutter run -d chrome \
  --dart-define=APP_MODE=supabase \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_ANON_KEY
```

On an Android emulator, `127.0.0.1` refers to the emulator. Use `10.0.2.2` for services running on the host machine, or your LAN address for a physical device.

## Hosted backend

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Set server-only AI secrets:

```bash
supabase secrets set \
  AI_API_KEY=YOUR_PROVIDER_KEY \
  AI_BASE_URL=https://api.openai.com/v1 \
  AI_MODEL=gpt-4.1-mini
```

Deploy protected functions:

```bash
supabase functions deploy assistant-guidance
supabase functions deploy weather-risk
```

Both functions require a valid Supabase JWT. Do not use `--no-verify-jwt` in production.

## Create the first administrator

Public signup always creates a Resident profile by design. After creating a trusted account, promote it from the SQL editor or a secure service-role administration process:

```sql
update public.profiles
set role = 'admin', municipality_psgc_code = '031410000'
where id = 'TRUSTED_AUTH_USER_UUID';
```

Do not let users set roles via editable JWT/user metadata. If using custom claims, update them only in trusted backend code and force token refresh after role changes.

## Evidence upload convention

Use private paths with ownership as the first folder:

```text
<auth-user-uuid>/<report-uuid>/<random-file-name>.jpg
```

Store metadata in `report_evidence`. Serve evidence through short-lived signed URLs after authorization. Strip unnecessary image metadata and apply server-side content validation in a production upload pipeline.

## Public versus authorized map reads

- **Resident/community map:** call `get_public_report_markers(min_lat, min_lng, max_lat, max_lng)`.
- **Reporter’s own details:** query base `reports`; RLS allows own rows.
- **Health/admin operational map:** query base `reports` only within the RLS-authorized jurisdiction.
- **Waste staff:** RLS permits only breeding-site and waste categories, not suspected cases.

Never use a service-role key in Flutter to bypass these rules.

## Production adapter work

The schema is ready, but the demo screens still read `AppState`. Implement repositories described in `ARCHITECTURE.md`, map database enums to Dart enums, add Auth screens/session recovery, and use Realtime selectively for queues. Add integration tests against local Supabase before enabling hosted mode for end users.

## Backups and migrations

- Never edit an already-applied migration in production; add a new timestamped migration.
- Enable Supabase backups/PITR appropriate to the project plan.
- Test restores and RLS behavior before launch.
- Keep secrets in `supabase secrets`, a CI secret manager, or the hosting platform—not in source control.
