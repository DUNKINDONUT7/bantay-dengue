# BantayDengue Deployment Guide

This guide separates client compilation from privileged backend changes. The Flutter app must never carry a service-role key, database password, or AI provider secret.

## 1. Prerequisites

- Flutter compatible with Dart `>=3.9.0 <4.0.0` (validated with Flutter 3.44.9 / Dart 3.12.2)
- A Supabase project owner/developer account
- Supabase CLI authenticated to the intended project, or access to Supabase Dashboard SQL Editor and Edge Functions
- For Android: Android Studio/SDK and Java 17–25
- For iOS: macOS, Xcode, CocoaPods, and Apple signing configuration

Before any hosted change, back up the database and test in a staging Supabase project.

## 2. Client configuration

Copy `env.json.example` to the ignored `env.json` file:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-PUBLISHABLE-OR-ANON-KEY"
}
```

Use only the browser-safe publishable/anon key. Build-time Flutter Web defines are visible in the downloaded JavaScript.

The application retains the original repository's public project URL and anon key as a fallback to preserve its existing login. Supplying Dart defines overrides that fallback.

## 3. Review and apply the database migration

Database SQL is privileged and is never executed by the app, and this project does **not** use `supabase db push` / CLI-tracked migrations — every change so far has been applied by hand in Supabase Studio's SQL Editor. **`supabase/README.md` is the authoritative index**: it lists every SQL file, whether it's already applied to the live project, and the exact order to run what's still pending. Read that file before touching anything in `supabase/` — do not assume a file is safe to run (or re-run) from its name alone; some files are one-time-only and destructive on a second run (they say so at the top).

For a **fresh, blank** project only, `supabase/BantayDengue_Full_Database_v2.3.sql` is a single-file alternative to the incremental path — see `supabase/README.md` for details.

### Applying a pending file

1. Open the intended project in Supabase Dashboard.
2. Create a database backup.
3. Open SQL Editor, paste the exact file `supabase/README.md` says is next, and confirm the project name before running.
4. Execute once as an authorized owner.
5. If any statement fails, the surrounding transaction rolls back; investigate rather than removing safeguards.
6. Update the status table in `supabase/README.md` once it succeeds.

Do not run `supabase db push` against this project — `supabase/_archive/` holds SQL that was never applied and is not compatible with the live schema; pushing would try to apply it.

## 4. Verify backend behavior

Use separate test accounts for each role. Never perform these checks with production personal/health data.

### Role and account checks

- A new sign-up receives `resident` regardless of client metadata.
- A resident cannot update `role`, `is_active`, `email`, or another profile through direct REST calls.
- An active administrator can assign `resident`, `health_worker`, `waste_personnel`, or `admin`.
- A suspended account reaches the blocked-account screen and cannot read/write operational or evidence data.
- Do not suspend or demote the only administrator.

### Workflow checks

Expected transitions are:

| Entity | Allowed transitions |
|---|---|
| Report | `pending → under_review/verified/rejected`; `under_review → verified/rejected`; `verified → resolved` |
| Appointment | `pending → approved/rejected/cancelled`; `approved → completed/cancelled` |
| Waste request | `pending → scheduled/cancelled`; `scheduled → collected/cancelled` |

Confirm that skipped/reversed transitions fail. Confirm residents can cancel only their own pending/approved appointments. Each successful transition should add exactly one `status_history` row and one resident notification; the database trigger is authoritative.

### Evidence checks

- Files are stored beneath the authenticated owner UUID, for example `USER_ID/reports/...`.
- Buckets remain private.
- A resident can upload and sign/read only owned evidence.
- Health workers/admins can sign/read report evidence.
- Waste Personnel/admins (and health workers under the current operational policy) can sign/read waste evidence.
- A signed preview expires after five minutes.
- A suspended account cannot read evidence.
- File limit is 5 MiB and allowed types are JPEG, PNG, and WebP.

## 5. Deploy Edge Functions

The normal Supabase function gateway must keep JWT verification enabled. Do **not** deploy with `--no-verify-jwt`.

```bash
supabase functions deploy assistant-guidance
supabase functions deploy weather-risk
```

The weather function calls Open-Meteo and needs no private weather key.

Configure AI provider secrets server-side:

```bash
supabase secrets set AI_API_KEY=YOUR_PROVIDER_KEY
supabase secrets set AI_BASE_URL=https://api.openai.com/v1
supabase secrets set AI_MODEL=gpt-4.1-mini
```

`AI_BASE_URL` and `AI_MODEL` are optional; shown values are defaults. The provider must expose an OpenAI-compatible `/chat/completions` endpoint. Do not place `AI_API_KEY` in Flutter code, `env.json`, or version control.

Function checks:

- unauthenticated invocation receives HTTP 401 from the gateway/function;
- authenticated weather requests return `level`, `score`, forecast measurements, methodology, source, disclaimer, and timestamp;
- AI warning-sign language produces urgent escalation without calling the provider;
- no prompt/health message is written to function logs;
- provider failure produces a safe unavailable response, and the client uses bounded offline guidance.

## 6. Build and test Flutter

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run -O2 --dart-define-from-file=env.json
```

In a higher-memory CI runner, the normal release command can use default optimization. If Flutter concurrently runs Dart2JS and a Wasm compatibility dry run in a low-memory environment, retain `--no-wasm-dry-run -O2`.

### Web hosting

Deploy the contents of `build/web/` to an HTTPS static host. Configure the host to return `index.html` for application routes when deep links are used. Review CSP and caching for the chosen host. Supabase requests and map tiles require network access.

### Android

```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

Use your release keystore and follow Play Console requirements. The project declares Internet access, optional camera hardware, and camera permission. Gallery selection uses Android's system picker. Test permission denial and evidence selection on supported Android versions.

### iOS

```bash
flutter build ipa --release --dart-define-from-file=env.json
```

Open `ios/Runner.xcworkspace` in Xcode to configure team, bundle ID, and signing. Camera and photo-library usage descriptions are present in `ios/Runner/Info.plist`. Test on a real device before distribution.

## 7. Production operations checklist

- Keep RLS enabled on every exposed table and Storage bucket.
- Rotate exposed private provider secrets immediately; public Supabase anon/publishable keys are not privileged, but still rely on correct RLS.
- Use a policy-compliant production tile provider or self-hosting for substantial map traffic; preserve OpenStreetMap attribution and caching.
- Apply retention rules for evidence and health-related submissions.
- Restrict Supabase Dashboard access and enable MFA for maintainers.
- Monitor Edge Function errors, authentication anomalies, status transitions, and audit events without logging health-message content.
- Label WHO figures as official national surveillance, never as barangay counts.
- Treat weather output as breeding-condition context only.
- Establish a human escalation and incident-response process before real public-health use.
