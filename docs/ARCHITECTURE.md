# BantayDengue Architecture and Data Boundaries

## Overview

BantayDengue is a Flutter client backed by one Supabase project. Authentication state and the server-side `profiles.role` determine navigation and database access. Screens do not use local demo data as an authority; operational data is loaded through the signed-in Supabase session and Row Level Security (RLS).

```text
Flutter Web / Android / iOS
  ├─ Supabase Auth (session)
  ├─ PostgREST tables (RLS)
  ├─ Private Storage (RLS + short signed URLs)
  ├─ Edge Function: assistant-guidance → configured AI provider
  ├─ Edge Function: weather-risk → Open-Meteo
  ├─ WHO public surveillance service
  └─ OpenStreetMap tiles through flutter_map
```

No service-role key or private provider key belongs in Flutter. The browser-safe Supabase key identifies the project; authorization comes from the user JWT and database policies.

## Client layers

| Area | Main files | Responsibility |
|---|---|---|
| Startup/config | `lib/main.dart`, `lib/config/supabase_config.dart` | Initialize Supabase, theme, and app router; validate browser-safe key shape |
| Identity | `lib/services/auth_service.dart`, `lib/models/user_model.dart` | Sign-in/up/out, reset password, load profile/role, active-account compatibility |
| Navigation | `lib/navigation/app_router.dart`, `lib/navigation/main_shell.dart` | Session redirects, suspended-account route, role fences, responsive shell |
| Data gateway | `lib/services/database_service.dart` | Authenticated CRUD, profile administration, private uploads/signed URLs, audit calls |
| External services | `ai_service.dart`, `weather_service.dart`, `dengue_api_service.dart` | Bounded AI, breeding-condition context, WHO national surveillance presentation |
| Resident UI | `lib/screens/civilian/` and `dashboard_screen.dart` | Reports, appointments, waste, map, guidance, advisories, notifications, profile |
| Staff UI | `health_worker_dashboard.dart`, `staff_appointments_screen.dart`, `verification_queue_screen.dart` | Metrics, appointments, report review and evidence |
| Waste Personnel UI | `waste_management_dashboard.dart`, `waste_personnel_account_screen.dart` | Separate operational queue/account, private evidence, self-assignment, scheduling, collection completion |
| Admin UI | `admin_dashboard.dart`, `user_management_screen.dart`, `announcements_screen.dart` | Analytics, audited activity, roles/access, announcements |

## Identity and role mapping

Database values map to client roles as follows:

| Database | Client | Home |
|---|---|---|
| `resident` | `UserRole.civilian` | `/dashboard` |
| `health_worker` | `UserRole.doctor` | `/health-center` |
| `waste_personnel` | `UserRole.wastePersonnel` | `/waste-management` |
| `admin` | `UserRole.admin` | `/admin` |

The app reloads the profile after authentication and profile changes. Router redirects are convenience and user experience controls; RLS and database triggers are the security authority. A client route check alone must never be treated as authorization.

The client defaults profiles without `is_active` to active only for compatibility with the pre-migration schema. Once deployed, the migration enforces suspension in RLS and the app routes inactive users to the suspended-account screen.

## Operational tables

The original schema includes:

- `profiles`
- `reports`
- `appointments`
- `waste_requests`
- `notifications`
- `health_advisories`
- `hotspots`
- `announcements`
- `system_activity`

The additive migration introduces `status_history`, `profiles.is_active`, and waste evidence/assignment fields. It replaces operational policies without discarding existing rows.

Resident reports are submissions, not confirmed case records. Only reviewed/verified data should influence official operational decisions, and this application does not claim to replace public-health surveillance systems.

## Workflow state machines

Database trigger validation prevents UI bypasses:

```text
Report:
  pending ─┬─> under_review ─┬─> verified ─> resolved
           │                 └─> rejected
           ├─> verified
           └─> rejected

Appointment:
  pending ─┬─> approved ─┬─> completed
           │             └─> cancelled
           ├─> rejected
           └─> cancelled

Waste request:
  pending ─┬─> scheduled ─┬─> collected
           │              └─> cancelled
           └─> cancelled
```

Residents may cancel only their own pending/approved appointments. Waste Personnel are separate from residents: they receive the authorized queue and account workspace, may claim an unassigned collection, and cannot overwrite resident submission fields or complete work assigned to another personnel account. Staff operations are constrained by role policies and the state machine. Status-change triggers write history, resident notification, and audit activity after the update succeeds.

## Evidence privacy

- `report-evidence` and `waste-evidence` are private buckets.
- Client paths begin with the authenticated user's UUID.
- Owners may upload/delete only beneath their UUID folder while active.
- Owners and authorized domain staff may read; suspension blocks reads.
- Staff screens request a five-minute signed URL instead of making a bucket public.
- Files are limited to 5 MiB and JPEG/PNG/WebP MIME types by bucket configuration.

Signed URLs are bearer URLs during their short lifetime. Do not log, persist, or share them. Production deployments should define retention, deletion, and incident-response policies appropriate for health-related evidence.

## AI safety boundary

The client first detects common emergency/warning-sign phrases and immediately advises urgent in-person care. For other questions, authenticated calls go to `assistant-guidance`; the provider key remains an Edge Function secret. The system prompt limits output to general education and avoids diagnosis, prescribing, dosage, laboratory interpretation, certainty, or requests for personal identifiers.

If the function/provider is unavailable, the app uses conservative local guidance. Every route ends with a clinical disclaimer. This is not an emergency service.

## External information boundaries

- **WHO:** official national surveillance presentation; never described as Marilao/barangay counts.
- **Weather:** seven-day rainfall/warm-day formula for possible mosquito-breeding conditions; not a disease prediction or clinical risk score.
- **OpenStreetMap:** visible attribution is included. Public tiles have usage limits and are not an unrestricted production CDN.

## Compatibility strategy

The hosted original schema may not yet contain integration fields. Compatibility behavior includes:

- profile parsing treats a missing `is_active` as active;
- waste list queries attempt the richer columns, then retry the original column set only for a missing-column response;
- private evidence and `waste_personnel` operations clearly require the migration;
- Auth continues to use the original Supabase project/session rather than a parallel local identity store.

This compatibility does not replace deployment: security enforcement, evidence buckets, assignment ownership, suspension, history, and the fourth role become authoritative only after the migration is applied. The client reads legacy `waste_staff`/`waste_management` values during rollout but writes only `waste_personnel`.
