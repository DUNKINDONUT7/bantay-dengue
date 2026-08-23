# Feature Screenshots

Captured 2026-08-19 against the **live** BantayDengue Supabase project (`bantay-dengue`),
using a `flutter build web --release` bundle and 4 real test accounts (one per role) signed
in through the actual login screen — not mocked or staged data.

| File | Shows |
|---|---|
| `00_landing_page.png` | Public landing page |
| `00_signin_form.png` | Login form (Supabase Auth) |
| `resident/01_home_dashboard.png` | Resident home — live weather-risk indicator, activity counts pulled from Supabase |
| `resident/02_report_hub.png` | Report hub — Create entry points (case / breeding site) |
| `resident/03_my_reports_crud.png` | **My Reports** — Edit/Delete on a real pending report (Update + Delete evidence) |
| `resident/04_hotspot_map.png` | OpenStreetMap hotspot map with breeding-condition indicator |
| `health_worker/01_dashboard.png` | Health Center dashboard — live reports-to-review count |
| `health_worker/02_verification_queue.png` | Verification queue (report review workflow) |
| `health_worker/03_appointments.png` | Staff appointments management |
| `health_worker/04_advisories.png` | Advisory publishing |
| `waste_personnel/01_dashboard.png` | Waste personnel dashboard — real pending/scheduled requests, status filters |
| `waste_personnel/02_hotspot_map.png` | Waste-role map view |
| `waste_personnel/03_account.png` | Waste personnel account workspace |
| `admin/01_analytics_dashboard.png` | Admin analytics — live user/report/waste-request counts, audited activity |
| `admin/02_user_management.png` | User management (search/filter, role/status control) |
| `admin/03_verification_queue.png` | Admin-side report verification |
| `admin/04_announcements.png` | Announcement publishing |

See `docs/archive/API_TEST_LOG.md` for the accompanying live API/RLS test evidence from that pass (archived — see `docs/archive/README.md`).
