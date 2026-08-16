# BantayDengue v2.3.0 Release Notes

Release date: 2026-08-11  
Flutter package version: `2.3.0+4`

## Interface

- Rebuilt the public landing experience for compact app screens and wide website/tablet layouts.
- Rebuilt login and resident signup with a shared monochrome Shadcn-inspired shell, autofill, visibility controls, inline validation, clearer role guidance, and friendly authentication errors.
- Kept the full-screen synchronization/pause state limited to application/session entry and sign-in profile resolution. Routine operations use local progress states.

## Waste Personnel separation

- Canonical database role is now `waste_personnel`.
- Legacy `waste_staff` and `waste_management` rows remain readable during rollout, but all application writes use the canonical value.
- Added a dedicated Waste Personnel operations dashboard and account route at `/waste-management/account`.
- Resident waste creation/history remains separate at `/civilian/waste`.
- Added assignment visibility and local action progress. Scheduling claims a request for the acting personnel account; personnel cannot complete another person's assigned collection.
- Kept a safe redirect from the previous `/waste-management/profile` path.

## Database and security

- Added `supabase/BantayDengue_Full_Database_v2.3.sql` as the complete install/repair SQL.
- Corrected the additive integration migration for canonical roles and text/enum compatibility using `role::text`.
- Added `202608110002_waste_personnel_canonical_role.sql` for projects that already recorded the v2.2 migration.
- Added authoritative protection preventing Waste Personnel from rewriting resident request ownership, evidence, and location fields or taking over another personnel assignment.
- Preserved Supabase Auth, RLS, private Storage, status history, notifications, and audit triggers.
- Public signup remains forced to `resident`; elevated roles require administrator authorization.

## Validation

Validated in the supplied Linux workspace with Flutter 3.44.9 / Dart 3.12.2:

- `flutter analyze`: no issues.
- `flutter test`: all 8 tests passed.
- PostgreSQL syntax parse: all 5 SQL files passed (`149`, `3`, `80`, `24`, and `69` statements respectively).
- `flutter build web --release --no-wasm-dry-run -O2`: successful.

Android compilation still requires Android Studio/SDK and a compatible Java toolchain. iOS compilation requires macOS/Xcode. The platform source projects are included.
