# BantayDengue — Full Development Roadmap

**Baseline version:** 1.0  
**Roadmap date:** 11 August 2026 (Asia/Manila)  
**Target:** Responsive web + mobile application  
**Primary client framework:** Flutter  
**Programming language:** Dart  
**Backend selected:** Supabase  
**Map selected:** `flutter_map` + OpenStreetMap-compatible tile provider  

> **Important:** Flutter ang framework/SDK; **Dart** ang programming language. Iisang Flutter codebase ang gagamitin para sa Android at responsive Web. Pananatilihing iOS-compatible ang architecture, kahit Android + Web muna ang primary release targets.

---

## 1. Project Goal

Ang BantayDengue ay community dengue surveillance at health-management platform para sa:

- maagang pag-report ng suspected dengue cases;
- pag-report ng mosquito breeding sites na may larawan at lokasyon;
- verification at response ng Barangay Health Center;
- real-time hotspot monitoring;
- appointment scheduling;
- waste/cleanup requests;
- outbreak advisories at notifications;
- dengue guidance mula sa AI assistant na may malinaw na safety limits;
- national/international context mula sa WHO data; at
- rainfall-based prevention context.

Hindi dapat ituring na medical diagnosis ang app. Ang final clinical assessment ay para sa lisensiyadong health professional.

---

## 2. Locked Technical Decisions

| Area | Final decision | Notes |
|---|---|---|
| Client | Flutter | Isang responsive codebase para sa Web at Mobile |
| Language | Dart | Lahat ng client-side app code |
| Navigation | GoRouter | Ipagpapatuloy ang kasalukuyang responsive `ShellRoute` approach |
| State management | Riverpod (recommended) | I-audit muna kung may kasalukuyang state-management package bago mag-migrate |
| Backend of record | Supabase | PostgreSQL, Auth, Storage, Realtime, Row Level Security, Edge Functions |
| Geographic database | Supabase PostgreSQL + PostGIS | Point storage, distance, viewport at hotspot queries |
| Map client | `flutter_map` | Cross-platform Flutter map widget |
| Map data | OpenStreetMap data | Dapat laging may visible attribution |
| Tile delivery | Compliant OSM-compatible provider | Public OSM tiles para lang sa light development/testing; production provider/self-hosting decision bago release |
| Location capture | GPS + draggable map pin + PSGC fields | Hindi aasa sa typed address lang |
| Secret APIs | Supabase Edge Functions | Walang OpenAI/Gemini/Semaphore/service-role key sa Flutter bundle |
| Local QR | `qr_flutter` or equivalent | Hindi kailangan ng external QR API |
| Source control | GitHub | Feature branches, pull requests, tagged releases |

### Backend conflict resolved

Ang Phase 2 PDF ay may Firebase stack, habang ang Week 5/prior plan ay tumutukoy sa Supabase. **Supabase na ang napiling main backend.** Kung gagamit ng Firebase Cloud Messaging, notification transport lang iyon—hindi Firebase ang database o authentication backend.

---

## 3. Current Baseline and Audit Status

Ang status sa ibaba ay base sa dalawang PDF na ibinigay. Hindi pa kasama ang source-code/build audit, kaya ang “reported implemented” ay hindi pa katumbas ng verified production-ready.

### Status legend

- ✅ **Verified complete** — nasuri sa code, build at tests
- 🟡 **Reported implemented; audit pending** — nakasaad sa documentation pero hindi pa nasusuri ang source
- 🔵 **Planned / not yet confirmed**
- ⛔ **Blocked** — may kailangang desisyon o dependency
- 🔁 **Needs revision** — may existing implementation pero kailangang baguhin

| ID | Existing item | Current status | Verification needed |
|---|---|---:|---|
| BASE-01 | Flutter environment/project structure | 🟡 | `flutter doctor`, dependency audit, clean build |
| BASE-02 | Clean folders for screens/widgets/models/services/navigation/theme/utils | 🟡 | Source-tree review; decide whether to keep or migrate to feature-first structure |
| BASE-03 | GoRouter + responsive ShellRoute | 🟡 | Route tests, deep-link tests, browser refresh tests |
| BASE-04 | 11 scaffolded screens | 🟡 | Screen inventory, mobile/web responsive review |
| BASE-05 | User/report/appointment/hotspot models | 🟡 | Compare models with final Supabase schema |
| BASE-06 | WHO weekly surveillance endpoint | 🟡 | Run live request, validate schema, timeout/error/cache behavior |
| BASE-07 | WHO mortality endpoint | 🟡 | Run live request and validate field names/results |
| BASE-08 | WHO country filter, refresh, loading/error states | 🟡 | Widget and integration tests; capture screenshots |
| BASE-09 | Real report persistence | 🔵 | Supabase schema and insert flow |
| BASE-10 | Real geographic map populated by reports | 🔵 | PostGIS + `flutter_map` integration |
| BASE-11 | Authentication and role-based authorization | 🔵 | Supabase Auth + RLS |
| BASE-12 | Appointments, waste, alerts and AI connected to backend | 🔵 | End-to-end implementation |

### First rule before new coding

**Audit first, then extend.** Hindi mag-a-assume na working ang documented feature hangga’t hindi pumapasa sa:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

---

## 4. Scope by Release

## 4.1 MVP — Core surveillance

Ito ang minimum na dapat gumana bago idagdag ang “advanced” features:

1. Supabase authentication at role-based access.
2. Standardized PSGC location selection.
3. Resident report form na may GPS/map pin, image at validation.
4. Report saved sa Supabase at may status history.
5. Health worker queue para mag-review, verify o reject.
6. Verified reports na lumalabas sa real interactive map.
7. Barangay-level hotspot/risk summary.
8. Resident report-status tracking.
9. Basic health advisories.
10. RLS, privacy protection, audit logs at core tests.

## 4.2 Version 1 — Community operations

1. Appointments at health-center schedules.
2. Waste/cleanup requests at assignment workflow.
3. In-app realtime notifications.
4. Push/SMS notification option.
5. Admin dashboard, analytics at CSV/PDF export.
6. WHO panel fully verified and documented.

## 4.3 Version 1.1 — Prevention intelligence

1. Open-Meteo rainfall forecast.
2. Configurable breeding-risk calculation.
3. Duplicate-report detection.
4. AI Health Assistant with guardrails and curated dengue knowledge.
5. QR check-in for appointments.
6. Advanced clustering/heatmap or barangay choropleth.

---

## 5. Target Architecture

```text
Flutter Web / Android
│
├── Presentation
│   ├── Screens and responsive layouts
│   ├── Widgets, forms, maps, charts
│   └── Riverpod providers/controllers
│
├── Domain
│   ├── Entities
│   ├── Repository contracts
│   ├── Use cases
│   └── Business/risk rules
│
├── Data
│   ├── Supabase repositories
│   ├── External API clients
│   ├── DTOs/mappers
│   └── Local cache
│
└── Supabase
    ├── Auth
    ├── PostgreSQL + PostGIS
    ├── Storage
    ├── Realtime
    ├── RLS policies
    ├── Database functions/triggers
    └── Edge Functions
        ├── AI assistant proxy
        ├── SMS/push alert sender
        ├── geocoding proxy/cache
        └── scheduled API sync/cache jobs
```

### Recommended Flutter feature structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── bootstrap.dart
├── core/
│   ├── config/
│   ├── errors/
│   ├── network/
│   ├── theme/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── reports/
│   ├── map/
│   ├── hotspots/
│   ├── appointments/
│   ├── waste/
│   ├── advisories/
│   ├── notifications/
│   ├── ai_assistant/
│   ├── who_watch/
│   └── admin/
└── main.dart

supabase/
├── migrations/
├── seed.sql
└── functions/
    ├── ai-health-assistant/
    ├── send-alert/
    ├── geocode-location/
    └── sync-weather/
```

Refactor nang paunti-unti; huwag sirain ang working routes para lamang maiba ang folder names.

---

## 6. Proposed Supabase Data Model

## 6.1 Core tables

| Table | Purpose | Important fields |
|---|---|---|
| `profiles` | Public app profile linked to `auth.users` | `id`, `full_name`, `phone`, `barangay_code`, `created_at`, `is_active` |
| `user_roles` | Role assignments | `user_id`, `role` (`resident`, `health_worker`, `waste_staff`, `admin`) |
| `health_centers` | Barangay health-center records | `id`, `name`, `address`, `location`, `contact_number` |
| `staff_assignments` | Staff scope/jurisdiction | `user_id`, `health_center_id`, `barangay_code`, `active` |
| `psgc_locations` | Locally cached standardized locations | `code`, `name`, `level`, `parent_code`, `dataset_version` |
| `reports` | Common report information | `id`, `reporter_id`, `type`, `description`, `location`, PSGC codes, `status`, timestamps |
| `report_photos` | One or more private evidence images | `id`, `report_id`, `storage_path`, `uploaded_by` |
| `case_details` | Dengue-specific health details | `report_id`, `age_group`, `symptoms`, `symptom_onset`, `has_warning_signs` |
| `breeding_site_details` | Site-specific information | `report_id`, `site_type`, `standing_water`, `access_notes` |
| `report_status_history` | Immutable report timeline | `report_id`, `from_status`, `to_status`, `changed_by`, `note`, `created_at` |
| `report_assignments` | Health-worker assignment | `report_id`, `assigned_to`, `assigned_by`, `assigned_at` |
| `hotspot_snapshots` | Computed barangay risk by period | `barangay_code`, `risk_level`, `risk_score`, components, `computed_at` |
| `audit_logs` | Sensitive/admin activity trace | `actor_id`, `action`, `entity_type`, `entity_id`, metadata, timestamp |

## 6.2 Operations tables

| Table | Purpose |
|---|---|
| `appointment_slots` | Health-center availability/capacity |
| `appointments` | Booking, approval, rejection, reschedule and completion |
| `appointment_status_history` | Appointment timeline |
| `waste_requests` | Cleanup/collection requests |
| `waste_assignments` | Crew assignment and schedule |
| `advisories` | Barangay health announcements and outbreak notices |
| `advisory_audiences` | Target barangays/roles |
| `notifications` | In-app notification inbox |
| `push_tokens` | Mobile/web push tokens per device |
| `notification_deliveries` | Push/SMS delivery status |

## 6.3 External-data/cache tables

| Table | Purpose |
|---|---|
| `geocode_cache` | Avoid repeated geocoding requests |
| `weather_snapshots` | Forecast by barangay/coordinates and fetch time |
| `who_weekly_stats_cache` | Optional WHO API cache/fallback |
| `who_mortality_cache` | Optional mortality cache/fallback |
| `ai_conversations` | Optional minimal conversation metadata; avoid unnecessary health-data retention |

## 6.4 Geospatial fields

- Use PostGIS `geography(Point, 4326)` for report coordinates.
- Create a GiST spatial index.
- Store latitude/longitude as derived display values only if needed.
- Remember: point creation uses **longitude first, latitude second**.
- Add RPC/database functions for:
  - reports inside the current map viewport;
  - verified reports within a radius;
  - report counts per barangay and date range;
  - nearest health center; and
  - duplicate-candidate search.

---

## 7. Role and Permission Matrix

| Action | Resident | Health worker | Waste staff | Admin |
|---|:---:|:---:|:---:|:---:|
| Create own case/breeding report | ✅ | ✅ | — | ✅ |
| View own exact reports | ✅ | Scoped | — | Scoped |
| View other residents’ exact identity/location | — | Assigned jurisdiction only | Only assigned waste data | Audited, minimum necessary |
| Review/verify health report | — | ✅ | — | ✅ |
| View public hotspot summary | ✅ | ✅ | ✅ | ✅ |
| Create appointment | ✅ | ✅ | — | ✅ |
| Manage appointment slots/status | — | ✅ | — | ✅ |
| Create waste request | ✅ | ✅ | ✅ | ✅ |
| Update collection status | — | Limited | ✅ | ✅ |
| Publish advisory | — | Scoped | — | ✅ |
| Manage users/roles | — | — | — | ✅ |
| View audit logs | — | Limited | — | ✅ |

### RLS rule

Lahat ng public tables na may personal o operational data ay may Row Level Security. Hindi sapat ang pagtatago ng buttons sa UI; kailangang ipatupad din ang permission sa database.

---

## 8. API Integration Plan and Priority

| API/service | Priority | Actual use | Integration pattern | Key caution |
|---|---:|---|---|---|
| Supabase | P0 | Auth, DB, Storage, Realtime, Functions | `supabase_flutter` | RLS required; service-role key never in app |
| PSA PSGC | P0 | Standard region/province/city/barangay codes | Server-side sync into `psgc_locations` | Official endpoint uses a token; do not call on every dropdown change |
| Device GPS | P0 | Current location | Flutter geolocation package | Explicit permission, fallback manual pin |
| `flutter_map` + OSM data | P0 | Interactive report/hotspot map | Flutter map layer + compliant tile provider | Attribution, caching and tile-provider policy |
| Nominatim | P1 | Explicit geocode/reverse-geocode | Edge Function + cache + throttling | Public service forbids client-side autocomplete and limits heavy use |
| WHO xMart weekly dengue | P1 / existing | National/global weekly trend | Existing Flutter service; optional backend cache | Validate live schema and empty-data behavior |
| WHO GHE mortality | P1 / existing | Long-term mortality trend | Existing Flutter service; optional backend cache | Independent failure handling |
| Open-Meteo | P1 | Rain forecast as prevention context | Edge Function or controlled client fetch + cache | Forecast is context, not proof of outbreak |
| Push gateway (e.g. FCM) | P1 | Outbreak/fogging/appointment alerts | Edge Function → push provider | Consent, token lifecycle, web setup |
| Semaphore SMS | P2 | Critical alert fallback | Edge Function only | Not assumed free; budget, opt-out and delivery logging |
| OpenAI or Gemini | P2 | AI dengue guidance | Authenticated, rate-limited Edge Function | No secret key/client calls; no diagnosis |
| Local QR package | P2 | Appointment check-in token | Generate locally in Flutter | Use signed/opaque ID, not exposed personal data |

### Correction to the earlier autocomplete idea

Do **not** implement “type every character → public Nominatim request.” Sa public Nominatim service, bawal ang client-side autocomplete. Ang safe design ay:

1. PSGC dropdown/search from our own `psgc_locations` table;
2. GPS or draggable map pin as the primary exact-location method;
3. explicit **Search address** button only when needed;
4. server-side throttling and cache; and
5. switchable geocoding provider configuration.

### OSM tile release rule

Ang OpenStreetMap data ay open, pero ang public `tile.openstreetmap.org` server ay community-funded at may usage policy. Bago production:

- configure a unique app identifier/User-Agent where supported;
- display attribution;
- honor caching;
- disable bulk/offline prefetch on that public server; at
- choose a production-ready tile provider or self-host if projected traffic is more than light use.

---

## 9. Reports-to-Map Data Flow

```text
Resident opens Report form
  → chooses report type
  → selects standardized PSGC location
  → grants GPS OR drops a pin manually
  → adds details/photo
  → client validates required fields
  → image uploads to private Supabase Storage
  → report INSERT executes under resident RLS policy
  → status history records “submitted”
  → Supabase Realtime notifies scoped health-worker dashboard
  → health worker reviews report
  → report becomes verified/rejected/needs_information
  → hotspot calculation uses verified records only
  → map query retrieves allowed records in current viewport
  → resident sees privacy-safe barangay risk; worker sees authorized operational details
```

### Map privacy rules

- Residents must **not** see another patient’s name, contact number or exact home pin.
- Public/resident map shows aggregated barangay risk, displaced/rounded points, or clusters.
- Health workers may see exact locations only within assigned jurisdiction and only when operationally necessary.
- Breeding-site/waste points can have a separate visibility rule from suspected-patient locations.

---

## 10. Hotspot and Risk Logic

## 10.1 MVP logic

Only **verified** reports count toward official operational risk.

Potential components by barangay:

- verified suspected/confirmed cases in the last 7 and 14 days;
- change versus the preceding period;
- unresolved verified breeding sites;
- recent/forecast rainfall;
- population-normalized rate when reliable population data is available.

## 10.2 Risk levels

- `low`
- `moderate`
- `high`
- `critical`

Thresholds and weights must be:

- configurable in an admin-only table;
- documented with formula/version;
- reviewed by the partner Barangay Health Center;
- presented as operational decision support, not a medical diagnosis; and
- recalculated after verification/status changes and by scheduled job.

## 10.3 Do not hard-code arbitrary clinical claims

The app may say “increased reporting activity” or “elevated breeding risk based on configured indicators,” but should not announce a confirmed outbreak unless an authorized health office publishes that advisory.

---

# 11. Implementation Roadmap

## Phase 0 — Repository and Code Audit

**Target:** 2–3 working days  
**Dependency:** Source project access  
**Goal:** Establish a reproducible starting point.

### Tasks

- [ ] `P0-01` Clone/open the actual repository and inventory branches.
- [ ] `P0-02` Record Flutter/Dart versions and run `flutter doctor`.
- [ ] `P0-03` Audit `pubspec.yaml`; remove dead/off-topic packages and screens.
- [ ] `P0-04` Run analyze, tests, Web build and Android debug build.
- [ ] `P0-05` Inventory all 11 documented screens and routes.
- [ ] `P0-06` Confirm that FakeStore/Product Market code is fully removed.
- [ ] `P0-07` Test both WHO endpoints from the actual app.
- [ ] `P0-08` Capture baseline screenshots and open defects.
- [ ] `P0-09` Create `.env.example`/build-configuration documentation without secrets.
- [ ] `P0-10` Tag the baseline release in Git.

### Definition of Done

- Clean clone can build on Web and Android.
- Every known error/warning is listed.
- Existing functionality is classified as keep, fix, replace or remove.

---

## Phase 1 — Supabase Foundation and Security

**Target:** Week 1  
**Dependency:** Phase 0

### Tasks

- [ ] `P1-01` Create development and production Supabase environments/projects.
- [ ] `P1-02` Add `supabase_flutter` initialization using build-time public config.
- [ ] `P1-03` Create SQL migrations; do not rely only on dashboard clicks.
- [ ] `P1-04` Enable PostGIS and create spatial indexes.
- [ ] `P1-05` Create `profiles`, `user_roles`, `health_centers`, `staff_assignments`.
- [ ] `P1-06` Create report tables, histories and audit logs.
- [ ] `P1-07` Create private Storage buckets and file rules.
- [ ] `P1-08` Enable RLS and write policies for each role.
- [ ] `P1-09` Seed test users and one pilot municipality/barangay set.
- [ ] `P1-10` Add repository interfaces and Supabase implementations in Flutter.
- [ ] `P1-11` Add structured error mapping and logging.

### Definition of Done

- Anonymous users cannot read/write sensitive data.
- Resident can only access own records.
- Scoped health worker can access assigned jurisdiction.
- Admin-only operations fail for non-admin users even when called outside the UI.

---

## Phase 2 — Authentication and Role-Based App Shell

**Target:** Week 2  
**Dependency:** Phase 1

### Tasks

- [ ] `P2-01` Signup/login/logout/password-reset flows.
- [ ] `P2-02` Profile completion and PSGC home barangay.
- [ ] `P2-03` Auth-state listener and session recovery.
- [ ] `P2-04` GoRouter redirect guards.
- [ ] `P2-05` Role-based menu/navigation items.
- [ ] `P2-06` Unauthorized and suspended-account screens.
- [ ] `P2-07` Responsive test at phone, tablet and desktop widths.
- [ ] `P2-08` Auth and route widget/integration tests.

### Definition of Done

- Refreshing a Flutter Web URL preserves the authenticated route.
- Users cannot enter another role’s protected page using a direct URL.
- Database RLS and route guard results are consistent.

---

## Phase 3 — PSGC Location Data, GPS and Geocoding

**Target:** Week 3  
**Dependency:** Phase 1

### Tasks

- [ ] `P3-01` Obtain/configure PSA PSGC API token or approved dataset source.
- [ ] `P3-02` Build server-side import/sync into `psgc_locations`.
- [ ] `P3-03` Add dataset version and last-sync metadata.
- [ ] `P3-04` Implement Region → Province → City/Municipality → Barangay selectors.
- [ ] `P3-05` Add local search over cached PSGC records.
- [ ] `P3-06` Implement geolocation permissions for Android and Web.
- [ ] `P3-07` Add “Use my current location.”
- [ ] `P3-08` Add draggable pin and coordinate validation.
- [ ] `P3-09` Add optional reverse-geocode/search through a cached Edge Function.
- [ ] `P3-10` Add fallback when GPS/geocoder is unavailable.

### Definition of Done

- A report cannot save invalid coordinates.
- Spelling and PSGC codes are standardized.
- Users can still submit by manually placing a pin if GPS is denied.
- Public geocoder requests are throttled and cached.

---

## Phase 4 — Functional Reporting and Evidence Upload

**Target:** Week 4  
**Dependency:** Phases 1–3

### Tasks

- [ ] `P4-01` Build one guided report flow with type-specific steps.
- [ ] `P4-02` Add suspected dengue symptom and onset fields.
- [ ] `P4-03` Add breeding-site fields.
- [ ] `P4-04` Add image picker/camera and compression.
- [ ] `P4-05` Upload evidence to private Supabase Storage.
- [ ] `P4-06` Insert report and initial history in one reliable transaction/RPC.
- [ ] `P4-07` Add validation, upload progress and retry behavior.
- [ ] `P4-08` Prevent accidental double-submit with an idempotency key.
- [ ] `P4-09` Build “My Reports” and status timeline.
- [ ] `P4-10` Add draft recovery for interrupted forms where appropriate.
- [ ] `P4-11` Add unit/widget/integration tests.

### Definition of Done

- New report exists in Supabase with valid coordinates and secure image path.
- Failed upload does not leave an inconsistent final report.
- Resident sees the report’s status but cannot self-verify it.

---

## Phase 5 — Health-Worker Verification Workflow

**Target:** Week 5  
**Dependency:** Phase 4

### Tasks

- [ ] `P5-01` Realtime pending-report queue.
- [ ] `P5-02` Filters for date, barangay, type, status and priority.
- [ ] `P5-03` Review screen with evidence and map location.
- [ ] `P5-04` Status actions: `needs_information`, `verified`, `rejected`, `resolved`.
- [ ] `P5-05` Require reason/note for status changes.
- [ ] `P5-06` Assign report to a health worker.
- [ ] `P5-07` Add status history and audit logs.
- [ ] `P5-08` Notify reporter of status change.
- [ ] `P5-09` Add duplicate-candidate flagging; human decides final merge/link.
- [ ] `P5-10` Test concurrent updates and permission boundaries.

### Definition of Done

- Only authorized staff can verify.
- Every status change has actor, time and reason.
- Realtime update appears without manual dashboard refresh.

---

## Phase 6 — Real Interactive Map and Hotspots

**Target:** Weeks 6–7  
**Dependency:** Phases 3–5

### Tasks

- [ ] `P6-01` Add `flutter_map`, coordinate model and attribution layer.
- [ ] `P6-02` Select/configure development and production tile provider.
- [ ] `P6-03` Query reports only inside current map viewport.
- [ ] `P6-04` Add marker clustering and filters.
- [ ] `P6-05` Separate case, breeding-site and waste markers.
- [ ] `P6-06` Build privacy-safe resident map.
- [ ] `P6-07` Build authorized operational health-worker map.
- [ ] `P6-08` Create barangay aggregation RPC/materialized view.
- [ ] `P6-09` Implement first configurable risk calculator.
- [ ] `P6-10` Add hotspot legend, date range and risk explanation.
- [ ] `P6-11` Refresh affected map data after verification/status changes.
- [ ] `P6-12` Load/performance test with seeded data.
- [ ] `P6-13` Optional: evaluate licensed barangay boundary GeoJSON for choropleth.

### Definition of Done

- A newly verified report appears on the appropriate map.
- Resident view does not leak a patient’s exact location or identity.
- Map remains usable with hundreds/thousands of seeded reports.
- Risk score has a documented version and breakdown.

---

## Phase 7 — Appointments and QR Check-In

**Target:** Week 8  
**Dependency:** Phases 1–2

### Tasks

- [ ] `P7-01` Health-center schedule and slot capacity management.
- [ ] `P7-02` Resident booking flow.
- [ ] `P7-03` Prevent overlapping or over-capacity booking.
- [ ] `P7-04` Approve, reject, reschedule, cancel and complete actions.
- [ ] `P7-05` Appointment timeline and reminders.
- [ ] `P7-06` Generate local QR containing an opaque signed/check-in token.
- [ ] `P7-07` Health-worker QR scanning/manual code fallback.
- [ ] `P7-08` Expiry, replay prevention and audit logging.

### Definition of Done

- Booking respects slot capacity and role permissions.
- QR does not expose patient name/contact in plain text.
- Scanner validates the token against the backend before check-in.

---

## Phase 8 — Waste and Cleanup Operations

**Target:** Week 9  
**Dependency:** Phases 3–4

### Tasks

- [ ] `P8-01` Waste request form with GPS/photo.
- [ ] `P8-02` Waste-staff queue and jurisdiction filters.
- [ ] `P8-03` Assignment, schedule and collection-status workflow.
- [ ] `P8-04` Before/after photo support.
- [ ] `P8-05` Resident status timeline.
- [ ] `P8-06` Link waste request to related breeding-site report when applicable.
- [ ] `P8-07` Add completion audit and operational metrics.

### Definition of Done

- Assigned staff can update only permitted requests.
- Resident receives status changes.
- Resolved locations stop contributing as unresolved breeding/waste risk.

---

## Phase 9 — Advisories and Notifications

**Target:** Week 10  
**Dependency:** Phases 1–2, 5

### Tasks

- [ ] `P9-01` Advisory compose, review/publish and expiry workflow.
- [ ] `P9-02` Target by barangay/role and severity.
- [ ] `P9-03` In-app realtime notification inbox.
- [ ] `P9-04` Read/unread state and deep links.
- [ ] `P9-05` Push-token registration and cleanup.
- [ ] `P9-06` Edge Function for push delivery.
- [ ] `P9-07` Optional Semaphore SMS for critical opted-in recipients.
- [ ] `P9-08` Delivery result/retry logging.
- [ ] `P9-09` Quiet hours, consent and unsubscribe handling.
- [ ] `P9-10` Prevent residents from publishing outbreak alerts.

### Definition of Done

- Authorized health worker/admin can target an advisory safely.
- Recipients see it in-app; configured push/SMS channels log delivery outcome.
- Expired/retracted advisory is handled correctly.

---

## Phase 10 — WHO Dengue Watch Hardening

**Target:** 2–3 working days; may run in parallel after Phase 0  
**Dependency:** Phase 0 audit

### Tasks

- [ ] `P10-01` Verify current WHO weekly endpoint and fields.
- [ ] `P10-02` Verify current WHO mortality endpoint and fields.
- [ ] `P10-03` Confirm country ISO3 filters and empty-result handling.
- [ ] `P10-04` Preserve independent loading/error/retry state per endpoint.
- [ ] `P10-05` Add response cache with fetch timestamp.
- [ ] `P10-06` Add “official national/global context” label; do not mix with local reports.
- [ ] `P10-07` Add API service unit tests using mocked JSON.
- [ ] `P10-08` Capture required request/response and UI screenshots.
- [ ] `P10-09` Update Week 5 documentation using actual—not illustrative—screenshots.

### Definition of Done

- Both sections work independently.
- Stale/cached data is visibly timestamped.
- No invented figures are displayed as live WHO data.

---

## Phase 11 — Rainfall and Breeding-Risk Forecast

**Target:** Week 11  
**Dependency:** Phase 6

### Tasks

- [ ] `P11-01` Define representative coordinates per covered barangay.
- [ ] `P11-02` Fetch precipitation probability/sum from Open-Meteo.
- [ ] `P11-03` Cache forecast with retrieval and validity timestamps.
- [ ] `P11-04` Add weather failure fallback.
- [ ] `P11-05` Combine rainfall with verified local indicators using configurable weights.
- [ ] `P11-06` Display indicator breakdown and disclaimer.
- [ ] `P11-07` Add admin/health-worker threshold configuration.
- [ ] `P11-08` Review wording with health-center stakeholder.

### Definition of Done

- Rainfall does not create a fake “confirmed outbreak.”
- Users can see why a risk level changed.
- API failure does not break local-report maps.

---

## Phase 12 — AI Health Assistant

**Target:** Week 12  
**Dependency:** Auth, Edge Functions, approved content

### Tasks

- [ ] `P12-01` Choose OpenAI or Gemini after cost/quality test.
- [ ] `P12-02` Create authenticated Edge Function; store provider key as secret.
- [ ] `P12-03` Ground answers in approved DOH/WHO dengue content where possible.
- [ ] `P12-04` Add scope: dengue education, symptoms, prevention and service navigation.
- [ ] `P12-05` Block diagnosis, prescriptions and false certainty.
- [ ] `P12-06` Add emergency/warning-sign escalation message.
- [ ] `P12-07` Add rate limits, token/cost limits and abuse protection.
- [ ] `P12-08` Minimize or disable sensitive conversation retention by default.
- [ ] `P12-09` Add prompt-injection and unsafe-answer evaluation set.
- [ ] `P12-10` Add visible AI disclaimer and “Contact Health Center” action.

### Definition of Done

- API secret is absent from Web/Android bundles.
- Assistant consistently refuses diagnosis and routes urgent cases to professional care.
- Basic red-team and health-content tests pass.

---

## Phase 13 — Analytics and Administration

**Target:** Week 13  
**Dependency:** Stable operational data

### Tasks

- [ ] `P13-01` Dashboard KPIs by date, barangay, report type and status.
- [ ] `P13-02` Trend charts and turnaround-time metrics.
- [ ] `P13-03` Appointment/no-show and waste completion metrics.
- [ ] `P13-04` User/role and health-center management.
- [ ] `P13-05` CSV export with role-based field redaction.
- [ ] `P13-06` Printable/PDF summary if required by capstone rubric.
- [ ] `P13-07` Audit-log viewer.
- [ ] `P13-08` Retention/archive controls.

### Definition of Done

- Export contains only data the requester is permitted to access.
- Dashboard totals match direct database queries for the same filters.

---

## Phase 14 — Quality, Security, Deployment and Documentation

**Target:** Weeks 14–15  
**Dependency:** Feature complete

### Tasks

- [ ] `P14-01` Unit tests for models, repositories, validators and risk logic.
- [ ] `P14-02` Widget tests for forms, loading/error/empty states and role UI.
- [ ] `P14-03` Integration tests for resident → worker → map flow.
- [ ] `P14-04` SQL/RLS permission tests for every role.
- [ ] `P14-05` Web responsive, keyboard and accessibility checks.
- [ ] `P14-06` Android permission and low-network tests.
- [ ] `P14-07` Image-size, map-load and large-list performance tests.
- [ ] `P14-08` Threat review: IDOR, exposed secrets, insecure storage, mass assignment, spam.
- [ ] `P14-09` Privacy notice, consent, data minimization and retention review.
- [ ] `P14-10` Backup/restore and incident-response procedure.
- [ ] `P14-11` GitHub Actions for analyze, format, test and build.
- [ ] `P14-12` Deploy Web staging and production.
- [ ] `P14-13` Produce signed Android AAB/APK for testing/release.
- [ ] `P14-14` Create user manual, admin manual, API documentation and demo script.
- [ ] `P14-15` Conduct user acceptance testing with residents and health workers.
- [ ] `P14-16` Fix launch blockers and tag `v1.0.0`.

### Definition of Done

- CI passes from a clean commit.
- No production secret is inside the Flutter bundle or repository.
- UAT sign-off is documented.
- Rollback and backup instructions exist.

---

## 12. Suggested 15-Week Delivery Calendar

| Week | Main output |
|---:|---|
| 0 | Code/repository audit and verified baseline |
| 1 | Supabase schema, PostGIS, Storage and RLS |
| 2 | Auth, profiles, roles and protected navigation |
| 3 | PSGC, GPS, draggable pin and geocoding fallback |
| 4 | Functional reporting and uploads |
| 5 | Health-worker verification and realtime queue |
| 6 | Real map, viewport queries and marker clusters |
| 7 | Hotspot aggregation, privacy-safe resident map and risk rules |
| 8 | Appointments and QR check-in |
| 9 | Waste/cleanup operations |
| 10 | Advisories, in-app alerts and push/SMS plumbing |
| 11 | WHO hardening + Open-Meteo rainfall context |
| 12 | AI assistant and safety testing |
| 13 | Admin analytics and exports |
| 14 | QA, security, accessibility and performance |
| 15 | UAT, deployment, documentation and final demo |

If school deadline is shorter, deliver **MVP Phases 0–6 first**. AI, SMS, QR and advanced forecast are not allowed to delay the reports-to-map core.

---

## 13. Master Progress Tracker

Update this table at the end of every work session.

| Milestone | Status | Target | Evidence/link | Blocker | Next action |
|---|---|---|---|---|---|
| M0 Baseline audited | 🟡 | Week 0 | Two PDFs received; source audit pending | Source repository not yet reviewed | Open repo and run build/test commands |
| M1 Supabase secured | 🔵 | Week 1 | — | — | Create migrations and RLS matrix |
| M2 Auth/RBAC working | 🔵 | Week 2 | — | M1 | Implement login/profile/route guards |
| M3 Standard location working | 🔵 | Week 3 | — | PSA token/dataset | Sync PSGC and build selectors |
| M4 Reports saved | 🔵 | Week 4 | — | M1–M3 | Connect form, Storage and DB |
| M5 Reports verified | 🔵 | Week 5 | — | M4 | Worker queue and status history |
| M6 Reports visible on map | 🔵 | Weeks 6–7 | — | M3–M5 | PostGIS viewport query + markers |
| M7 Hotspot risk working | 🔵 | Week 7 | — | M6 + stakeholder rules | Implement configurable calculation |
| M8 Appointments working | 🔵 | Week 8 | — | M2 | Slots and booking workflow |
| M9 Waste workflow working | 🔵 | Week 9 | — | M3–M4 | Assignment and collection status |
| M10 Alerts working | 🔵 | Week 10 | — | M2/M5 | Advisory and notifications |
| M11 WHO integration verified | 🟡 | Week 11 | Week 5 PDF | Live/code/screenshots pending | Execute and test both endpoints |
| M12 Rainfall forecast working | 🔵 | Week 11 | — | M6 | Open-Meteo cache and risk input |
| M13 AI assistant safe | 🔵 | Week 12 | — | Provider choice/knowledge base | Build secured Edge Function |
| M14 Analytics complete | 🔵 | Week 13 | — | Stable data | KPI queries and exports |
| M15 Release ready | 🔵 | Week 15 | — | All critical milestones | QA, UAT and deployment |

### Weekly status template

```md
## Weekly Update — YYYY-MM-DD

### Completed
- [ ]

### In progress
- [ ]

### Blocked
- [ ] Blocker — owner — expected resolution

### Test evidence
- Commit:
- Build:
- Screenshots/video:
- Test result:

### Next three tasks
1.
2.
3.
```

---

## 14. Definition of Done for Every Feature

Hindi “done” ang feature dahil lang visible ang screen. Done lamang kapag:

- [ ] UI works on mobile and web.
- [ ] Real backend data ang gamit; walang fake delay o hard-coded production data.
- [ ] Loading, empty, validation and error states exist.
- [ ] Authorization works in both UI and database RLS.
- [ ] Sensitive data is not logged or leaked.
- [ ] Unit/widget/integration test appropriate to the feature exists.
- [ ] `flutter analyze` and test suite pass.
- [ ] Acceptance criteria are demonstrated with evidence.
- [ ] Documentation and progress tracker are updated.
- [ ] Code is committed with a clear message and reviewed before merge.

---

## 15. Testing Matrix

| Layer | Minimum tests |
|---|---|
| Dart unit | JSON parsing, validators, risk calculations, status transitions |
| Repository | Supabase success/error mapping, API timeout/empty/malformed response |
| Widget | Forms, role menus, loading/error/empty states, responsive layouts |
| Integration | Signup/login, report submit, worker verify, report-to-map, booking, waste workflow |
| Database | RLS allow/deny matrix, RPC permissions, trigger/history behavior |
| API contract | WHO/Open-Meteo/PSGC/geocoder response fixtures and schema changes |
| Security | Direct URL access, IDOR attempts, unauthorized Storage access, rate limiting |
| Performance | Map viewport with seeded reports, image upload size, long lists |
| Accessibility | Keyboard navigation, labels, contrast, text scaling and touch target size |
| Resilience | Offline/slow network, API unavailable, token expired, retry behavior |

---

## 16. Security and Privacy Non-Negotiables

1. Never place `service_role`, OpenAI/Gemini or Semaphore secrets in Flutter code, `.env` shipped to Web, or GitHub.
2. Supabase URL and public/publishable client key may be client configuration, but security must come from RLS—not secrecy of the public key.
3. Evidence images use private buckets and signed URLs with short expiry.
4. Public/resident map must not expose exact patient homes.
5. Collect minimum necessary health/contact data.
6. Add consent, purpose notice, access control, retention and deletion/archival policy.
7. Audit all verification, role change, export and advisory actions.
8. Add server-side rate limits and abuse controls to reports, SMS and AI.
9. Do not let an AI response replace professional care or issue a diagnosis.
10. Use synthetic/test data for demos unless proper permission exists.

---

## 17. Key Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Scope too large | Core map/report flow unfinished | Lock MVP; AI/SMS/QR remain after reports-to-map |
| Firebase/Supabase duplication | Confusing data/auth flow | Supabase is the only backend of record |
| Public OSM/Nominatim abuse | Blocking or broken maps/search | Cache, throttle, attribution, compliant production providers |
| Incorrect/duplicate reports | Misleading hotspot | Verification, status history, duplicate candidates |
| Exact patient location leak | Serious privacy issue | Aggregate/displace resident map; strict RLS |
| Arbitrary risk formula | False confidence | Configurable versioned formula and health-center review |
| AI hallucination | Unsafe health advice | Grounding, guardrails, escalation and evaluations |
| API schema/outage | Broken dashboard | Timeouts, fixtures, independent errors, cache and last-updated label |
| Web API secrets | Key theft and cost abuse | Edge Functions only |
| Weak capstone evidence | Hard to prove completion | Screenshots, commits, test logs, Postman/API evidence and UAT records |

---

## 18. School/Capstone Deliverables Checklist

- [ ] Updated project proposal with Supabase and OSM architecture.
- [ ] Functional and non-functional requirements.
- [ ] Use-case diagram and role matrix.
- [ ] ERD with table relationships.
- [ ] Architecture/data-flow diagram.
- [ ] API integration documentation with real requests/responses.
- [ ] RLS/security-policy documentation.
- [ ] Test plan, test cases and results.
- [ ] Screenshots for mobile and web.
- [ ] GitHub commit history and tagged release.
- [ ] Deployment URL and Android test build.
- [ ] User/admin manual.
- [ ] Data privacy and AI disclaimer text.
- [ ] UAT feedback/sign-off.
- [ ] Final presentation/demo flow.

### Recommended final demo flow

1. Resident logs in.
2. Resident submits breeding-site or suspected-case report with GPS/photo.
3. Health worker receives the report in realtime.
4. Health worker verifies it.
5. Verified data updates the map/hotspot summary.
6. Resident sees status change.
7. Health worker publishes a targeted advisory.
8. Show WHO context and rainfall panel without confusing them with local verified data.
9. Demonstrate privacy: resident cannot open another resident’s exact report.

---

## 19. Immediate Next Actions

### Next action 1 — Source-code audit

Ibigay/open ang actual Flutter project repository. Susuriin ang current folders, dependencies, routes, static data, WHO service at build errors.

### Next action 2 — Supabase migration pack

Pagkatapos ng audit, gawin ang first SQL migration para sa:

- PostGIS;
- profiles and roles;
- health centers and assignments;
- reports, details, photos and status history;
- audit logs;
- RLS policies; at
- development seed data.

### Next action 3 — First vertical slice

Unang complete end-to-end slice:

```text
Resident login
→ submit breeding-site report with GPS/photo
→ save to Supabase
→ health-worker realtime queue
→ verify report
→ marker appears on authorized map
→ resident sees updated status
```

Ito ang pinakamahalagang proof na “buhay” na ang BantayDengue at hindi na static UI.

---

## 20. Reference Links

- PSA PSGC API documentation: https://psa.gov.ph/classifications-api/psgc
- Supabase Flutter: https://supabase.com/docs/reference/dart/introduction
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Supabase PostGIS: https://supabase.com/docs/guides/database/extensions/postgis
- `flutter_map`: https://docs.fleaflet.dev/
- OpenStreetMap tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- Nominatim usage policy: https://operations.osmfoundation.org/policies/nominatim/
- Open-Meteo forecast API: https://open-meteo.com/en/docs
- WHO Global Dengue Surveillance dashboard/API reference: https://worldhealthorg.shinyapps.io/dengue_global/

---

**Roadmap rule:** Kapag may bagong feature request, ilagay muna sa tamang release at phase. Huwag isingit agad kung maaantala nito ang MVP reports-to-map flow.
