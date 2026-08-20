# Archive — do not run, do not `supabase db push`

Everything in here is **not part of the live database's real history**. `supabase migration list --linked` confirms none of these 3 files are recorded as applied — the live schema was built by hand-pasting `schema.sql` → `APPLY_THIS_NOW.sql` → `BantayDengue_FINAL.sql` → `RATE_LIMIT_ADDITIONS.sql` into Supabase Studio's SQL Editor, never through `supabase db push`.

## `migrations/202608110001_initial_schema.sql` — the root cause of the 2026-08-19 bugs

This is a **different, abandoned database redesign** — different table shapes (`type` instead of `report_type`, a PostGIS geography column instead of `latitude`/`longitude`, a separate `barangays` table, a custom `appointment_status` enum, etc.) that nothing in `lib/` was ever written against. At some point, parts of it got applied directly to the live project anyway (likely by hand, table-by-table, not via this migrations folder), leaving `public.reports`, `public.waste_requests`, and `public.appointments` with columns/types from this file mixed in with the real `schema.sql` columns.

This caused three confirmed incidents:
- `reports`/`waste_requests` — wrong columns entirely (`type` vs `report_type`, etc.) — fixed in `../APPLY_THIS_NOW.sql`.
- `appointments` — extra NOT NULL columns (`patient_name`, `health_center`, `appointment_at`) plus a `status` enum missing `approved`/`rejected` — fixed in `../APPLY_APPOINTMENTS_FIX.sql`.
- `hotspots` — extra NOT NULL `name` column plus a `risk_level` enum using `medium` instead of `moderate` — fixed directly in app code (`lib/services/database_service.dart`, `lib/screens/civilian/hotspot_map_screen.dart`).

**Never run this file, and never run `supabase db push` while it sits in a `migrations/` folder** — that command applies every untracked migration it finds, and this one would immediately reintroduce the same contamination in whatever table it touches next.

## `migrations/202608110001_existing_system_integration.sql` and `202608110002_waste_personnel_canonical_role.sql`

Written to layer on top of `202608110001_initial_schema.sql`'s table shapes (not `schema.sql`'s), and were never applied via `db push` either. `BantayDengue_FINAL.sql` and `RATE_LIMIT_ADDITIONS.sql` (already applied, confirmed live) cover the same ground — Waste Personnel role, account suspension, status history, notifications, audit — but written against the real `schema.sql` shape. Kept here for reference only.

## If you ever need a real migration again

Start a fresh file directly in `supabase/` (like `APPLY_APPOINTMENTS_FIX.sql`) and apply it by hand in Supabase Studio's SQL Editor, the same way every other change to this database has been applied. Don't resurrect this `migrations/` folder — the CLI's migration tracking was never wired up for this project, and mixing it back in now risks the CLI trying to "catch up" by pushing everything in here.
