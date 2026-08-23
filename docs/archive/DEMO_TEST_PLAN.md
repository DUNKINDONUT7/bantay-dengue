# Manual demo test plan

The Flutter client no longer has a local `APP_MODE=demo` fixture mode — every login goes through
the real Supabase project (`lib/config/supabase_config.dart`). Run each scenario below signed in
with a real test account for that role. Keep one account per role (resident, health worker, waste
personnel, admin) in the project's `profiles` table for repeatable demos/grading.

## Resident

1. Sign in with a `resident` account.
2. Confirm Home shows metrics, quick actions, advisories, weather context, and WHO context/fallback.
3. Open **Report a case**. Validate required fields, location capture, and submit.
4. Open **Report a breeding site** / waste report. Attach a photo and submit.
5. Open **My Reports** and confirm only this account's own reports are listed (RLS-enforced —
   see `docs/API_TEST_LOG.md` for a live proof of the underlying policy).
6. While a report is still `pending`, use Edit and Delete on it; confirm both are gone once staff
   moves it to `under_review`.
7. Open Map. Confirm the privacy notice and generalized/displaced pin behavior for suspected cases.
8. Book an appointment. Confirm it appears Pending.
9. Ask Bantay AI about prevention, symptoms, and severe bleeding; confirm the last case escalates
   to in-person care without diagnosing.

## Health Worker

1. Sign in with a `health_worker` account.
2. Open the Verification Queue and a pending report.
3. Test Verify, Reject, and Resolve actions across available reports.
4. Confirm the reviewer note and status change persist after refresh.
5. Open Staff Appointments and change Pending to Approved/Completed.
6. Open Map and inspect exact (non-generalized) operational details.
7. Publish an advisory with audience and severity.
8. Confirm direct navigation to Users or Analytics redirects to Dashboard (role fence).

## Waste Personnel

1. Sign in with a `waste_personnel` account.
2. Confirm Reports/Map screens are not reachable (role-fenced) — this role only sees the
   operations dashboard and account workspace.
3. Open the waste dashboard, filter by status, and move a request through
   Scheduled → Assigned → In progress → Collected.
4. Confirm direct Appointments, Users, Analytics, and Assistant routes redirect away.

## Administrator

1. Sign in with an `admin` account.
2. Open User Management, search/filter users, and deactivate/reactivate a non-admin account.
3. Confirm the signed-in admin's own account cannot be deactivated.
4. Open Analytics/system activity and review the audit log.
5. Review reports and publish an announcement.

## Automated checks

```bash
flutter analyze
flutter test
```

For live API/RLS verification without opening the app, see `docs/API_TEST_LOG.md` — a real
`curl` run against the WHO, Open-Meteo, and Supabase endpoints, including a request that
confirms an unauthenticated write is rejected by Row-Level Security (`401`,
`42501 — row-level security policy violation`).
