# BantayDengue

BantayDengue **v2.3.0** is a responsive Flutter and Supabase community dengue-surveillance and health-management system for residents and authorized barangay personnel. This project extends the original database-connected application rather than replacing its authentication or data flow.

> **Public-health boundary:** Resident reports are unverified submissions until reviewed by authorized personnel. WHO figures are national surveillance data, not Marilao or barangay case counts. The weather card is an app-defined mosquito-breeding-condition indicator, not a dengue forecast. Bantay AI provides general education only and never diagnoses or replaces professional or emergency care.

## Role-based workflows

- **Resident:** submit dengue-case and breeding-site reports with private evidence; view status history; book/cancel appointments; request waste collection; view OpenStreetMap hotspots, advisories, notifications, weather context, and bounded AI guidance; maintain a profile.
- **Health worker:** review reports and time-limited signed evidence, move reports through verification states, manage appointments, inspect operational metrics, advisories, and hotspot information.
- **Waste Personnel:** use a separate role-authorized operations dashboard and account; prioritize resident waste requests, inspect private evidence, claim/schedule pickup, and mark assigned collection complete.
- **Administrator:** view system analytics and audit activity, manage user roles/access, and publish announcements.

The router fences each area using the role stored in the authenticated Supabase `profiles` row. The Flutter client uses only a browser-safe publishable/anon key; service-role and provider secrets must never be placed in the app.

## Technology

- Flutter 3.44.9 / Dart 3.12.2 validated
- Supabase Auth, PostgreSQL/RLS, Storage, and Edge Functions
- OpenStreetMap through `flutter_map`
- Web, Android, and iOS project targets (Windows runner retained from the base repository)

## Open and run in VS Code

1. Install Flutter and confirm a suitable device:
   ```bash
   flutter doctor
   flutter devices
   ```
2. Open this folder in VS Code.
3. Resolve packages:
   ```bash
   flutter pub get
   ```
4. Optional: copy `env.json.example` to `env.json` and enter the browser-safe URL and publishable/anon key for the Supabase project you want to use. The repository retains the original project's public Supabase connection as a fallback so its existing login remains testable.
5. Run Web:
   ```bash
   flutter run -d chrome --dart-define-from-file=env.json
   ```
   If you are intentionally using the preserved project fallback, omit `--dart-define-from-file=env.json`.
6. Run Android after installing Android Studio/SDK and Java 17–25:
   ```bash
   flutter run -d android --dart-define-from-file=env.json
   ```
7. Run iOS on macOS with Xcode:
   ```bash
   flutter run -d ios --dart-define-from-file=env.json
   ```

Never put a Supabase `service_role`/secret key in `env.json`; Flutter Web build-time values are visible to users.

## Interface and entry behavior

The interface uses a Flutter-native, Shadcn-inspired monochrome system: near-black surfaces, white primary controls, zinc borders, restrained radii, semantic colors only for health/workflow status, and consistent mobile touch targets. Mobile and tablet navigation keep the most important role actions visible and place all other authorized destinations in a **More** sheet.

A full-screen account-sync state is intentionally limited to app startup, session restoration, and sign-in/profile resolution. Ordinary report, appointment, waste, and administration actions retain local button or section progress instead of blocking the whole screen. Heavy app-wide blur/grid layers and overlapping shell animations were removed to reduce rendering and navigation overhead.

## Backend integration is required

The UI is compatible with the original schema, but all added workflows require the additive migration and Edge Functions:

- Base schema: `supabase/schema.sql`
- Complete install/repair SQL: `supabase/BantayDengue_Full_Database_v2.3.sql`
- Additive migrations: `supabase/migrations/202608110001_existing_system_integration.sql` and `202608110002_waste_personnel_canonical_role.sql`
- Edge Functions: `supabase/functions/assistant-guidance` and `supabase/functions/weather-risk`

The SQL uses the canonical `waste_personnel` role (while the client can read legacy role aliases), adds suspension enforcement, workflow guards/history, notifications/auditing, waste evidence and assignment metadata, and private evidence buckets/policies. It is intentionally **not auto-applied** by the client. Review and deploy it from an authorized Supabase owner account by following [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

Until that migration is deployed:

- the existing resident, health-worker, and administrator login/data flows remain available;
- assigning `waste_personnel`, account suspension, private evidence buckets, assignment ownership, and authoritative status-history triggers are unavailable;
- waste-list loading automatically falls back to the original column set.

## Validation performed

Validated in the supplied Linux workspace with Flutter 3.44.9:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run -O2
```

Results for v2.3.0: analyzer clean, all eight tests passed (including phone-width landing/login and the dedicated Waste Personnel account), every SQL file parsed successfully with PostgreSQL syntax tooling, and the release Web bundle compiled successfully. The lower Web optimization level and disabled Wasm compatibility dry run avoid excessive memory use in constrained environments; production CI with more RAM may use the default optimization.

Android compilation was not run in the supplied workspace because Android Studio/SDK and a compatible Java toolchain were unavailable. iOS builds require macOS/Xcode. Generated Android and iOS platform configuration is included, with network/camera and photo-library usage declarations.

## Project guide

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — modules, roles, data boundaries, and workflow states
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — migration, Edge Function, Web, Android, and iOS deployment checklist
- `lib/services/database_service.dart` — authenticated Supabase operational gateway
- `lib/navigation/app_router.dart` — session and role fences
- `supabase/BantayDengue_Full_Database_v2.3.sql` — complete owner-reviewed install/repair script
- `supabase/migrations/` — additive and deployed-v2.2 follow-up migrations

## Map usage

OpenStreetMap attribution is visible in the app. Direct public OSM tiles are suitable for modest testing, not unrestricted production traffic. For production, use a policy-compliant tile provider or self-hosted tiles, preserve attribution, caching, and provider terms, and do not bulk download or prefetch tiles.
