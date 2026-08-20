# Midterm Project Submission Checklist — Bantay Dengue

**Student Name:** Villacorte, John Carlo B.
**Section / Group:** ITE 233
**Project Title:** Bantay Dengue
**Submission Date:** Aug 24, 2026

Filled in against a direct audit of this repository (commit `0b7bf97`), a live
`flutter analyze` / `flutter test` run (0 issues, 8/8 passing), and the
Supabase Table Editor screenshots captured 2026-08-20. Two items below are
flagged **action needed** — read those before signing the declaration.

## A. Project Documentation

- [x] Project Title and Description — `README.md`
- [x] Project Objectives Defined — `docs/FULL_ROADMAP.md` §1 "Project Goal" + README
- [x] Scope and Limitations Identified — README "Public-health boundary" note + `docs/SECURITY.md`
- [x] Updated System Flowchart / Architecture Diagram — `docs/ARCHITECTURE.md`
- [x] Database Design (ERD or Schema) — `supabase/schema.sql`, `supabase/BantayDengue_FINAL.sql`; 13 live tables confirmed in Supabase Table Editor
- [x] Project Progress Report (Current Accomplishments) — see "List of Completed Features" below

## B. System Implementation

- [x] User Interface (UI) Developed — 4 role dashboards (resident, health worker, waste personnel, admin)
- [x] Navigation and Routing Functional — GoRouter + role fences, covered by widget tests
- [x] Core Features Implemented — reports, verification queue, appointments, waste requests, hotspot map, advisories, AI chat, profile
- [x] Forms and Data Validation Working — `docs/CRUD_DOCUMENTATION.md`
- [x] Error Handling Implemented — API fallback/empty states, `DengueApiException`, offline AI guidance fallback

## C. CRUD Functionality

- [x] Create Operation Working — `DatabaseService.submitReport()`
- [x] Read/View Operation Working — `DatabaseService.fetchReports()`
- [x] Update Operation Working — `DatabaseService.updateReport()`
- [x] Delete Operation Working — `DatabaseService.deleteReport()` (soft delete)
- [x] Search/Filter Feature — admin user search/filter, waste dashboard status filter

## D. API Integration and Testing

- [x] API Connection Successfully Established — Supabase, WHO xMart, Open-Meteo
- [x] GET Requests Tested — 5 live GET calls logged in `docs/API_TEST_LOG.md`
- [x] POST Requests Tested — unauthenticated insert correctly rejected (401, RLS policy)
- [x] PUT/PATCH Requests Tested *(via app, not curl)* — exercised live through the Edit-report flow; no standalone curl/Postman log yet
- [x] DELETE Requests Tested *(via app, not curl)* — exercised live through the Delete-report flow (soft delete); same caveat
- [x] API Responses Properly Displayed — dashboard stat cards, weather-risk card, WHO trend panel
- [x] Error Responses Properly Handled — empty-state handling, typed exceptions
- [x] Authentication/Authorization Implemented — RLS proven live (unauthenticated write → `42501` policy violation)
- [x] API Documentation Available — `docs/API_TEST_LOG.md` + raw curl transcript

## E. Project Demonstration Materials

- [x] Source Code Available and Organized — pushed to GitHub, clean `lib/` structure
- [ ] **System Ready for Live Demonstration — action needed.** Appointment booking is currently broken pending one migration. Run `supabase/APPLY_APPOINTMENTS_FIX.sql` in Supabase Studio → SQL Editor before demoing, then check this off.
- [ ] **Presentation Slides Prepared — confirm with instructor** whether required for this milestone; not part of the repo
- [x] Sample Data Available for Testing — one test account per role, `docs/DEMO_TEST_PLAN.md`
- [x] Project Repository Updated — pushed to `github.com/DUNKINDONUT7/bantay-dengue`, commit `0b7bf97`

## F. Midterm Progress Evidence

- [x] Screenshots of Implemented Features — 16 screenshots across all 4 roles, `docs/screenshots/`
- [x] API Testing Screenshots/Logs — `docs/API_TEST_LOG.md`, `docs/api_test_log_raw.txt`
- [x] Database Screenshot — Supabase Table Editor (13 tables) + live `reports` rows captured; save the image files into `docs/screenshots/database/` so they travel with the repo
- [x] Source Code Samples for Key Features — referenced by file/function throughout `CRUD_DOCUMENTATION.md`
- [x] List of Completed Features — see below
- [x] List of Remaining Features for Final Project — see below

## Project Completion Status

| Component | Status |
|---|---|
| UI/UX Development | Complete |
| Navigation & Structure | Complete |
| CRUD Features | Complete |
| API Integration | In Progress |
| Documentation | Complete |

## List of Completed Features

- Role-based auth and navigation (resident, health worker, waste personnel, admin) via Supabase Auth + Row-Level Security
- Full CRUD on dengue-case and breeding-site reports, including soft delete and edit-while-pending
- Report verification workflow (pending → under_review → verified/rejected → resolved) with status history
- Interactive OpenStreetMap hotspot map — privacy-safe resident view vs. exact operational staff view
- Appointment booking and staff appointment management
- Waste/cleanup request workflow with status tracking
- Health advisories and in-app notifications
- AI health assistant with safety guardrails (Supabase Edge Function, emergency-language escalation)
- Admin analytics dashboard, user management, announcements
- WHO surveillance and Open-Meteo weather integration on the resident dashboard
- Live API/RLS test evidence, CRUD documentation, and screenshots for all four roles

## List of Remaining Features for Final Project

- Apply pending `APPLY_APPOINTMENTS_FIX.sql` and `AVATAR_STORAGE.sql` migrations to the live database
- Add standalone curl/Postman evidence for authenticated PUT/PATCH and DELETE calls
- Avatar upload / profile photo storage (blocked on the migration above)
- Push/SMS notification delivery — in-app notifications only for now
- CSV/PDF export for admin analytics
- QR check-in for appointments

## Declaration

I certify that the submitted project update, source code, documentation, and demonstration materials are my/our current work and accurately reflect the progress achieved as of the midterm evaluation.

**Student Signature:** ________________________________
**Date:** ________________________________

*Note: This checklist aligns with the evaluation areas in Midterm_Examination_Week6, particularly the requirements for system checking, progress presentation, CRUD functionality, and API integration.*
