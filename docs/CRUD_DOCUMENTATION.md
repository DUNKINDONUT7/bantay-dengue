# Week 4 — CRUD Implementation

**Entity:** `reports` (dengue case reports and mosquito breeding-site reports) —
the main data entity of the BantayDengue system.

**Storage:** Supabase (PostgreSQL) with Row-Level Security, accessed through
`supabase_flutter`. No mock/local data — every operation below reads or
writes the real `reports` table.

## Where each operation lives

| Operation | UI entry point | Code |
|---|---|---|
| **Create** | Report Case / Report Breeding Site screens (`lib/screens/civilian/report_case_screen.dart`, `report_breeding_screen.dart`, both built on `lib/widgets/report_form.dart`) | `DatabaseService.submitReport()` |
| **Read** | My Reports (`lib/screens/civilian/report_history_screen.dart`); staff Verification Queue (`lib/screens/verification_queue_screen.dart`) | `DatabaseService.fetchReports()` |
| **Update** | Edit button on a pending report in My Reports → `lib/widgets/edit_report_screen.dart` | `DatabaseService.updateReport()` |
| **Delete** | Delete button on a pending report in My Reports (confirmation dialog first) | `DatabaseService.deleteReport()` |

Update and Delete are intentionally scoped to reports the current user filed
themself, and only while `status = 'pending'`. Once a health worker starts
reviewing a report, editing/deleting locks — this reflects a real
verification workflow, where evidence shouldn't be alterable mid-review.

## Data validation

Client-side, in the report form (`Form` + `TextFormField.validator`):
- Location: required, minimum 3 characters
- Details: required, minimum 10 characters, capped at 1000
- Latitude/longitude: optional, but if entered must parse as a number

Server-side: Supabase Row-Level Security policies (see below) independently
enforce *who* may write to a row, regardless of what the client sends —
validation isn't just a UI nicety here, it's backed by the database.

## Delete is a soft delete

Pressing "Delete" removes the report from the list immediately and it never
appears again in the app — but the row is never actually erased from the
database. Instead the app sets a `deleted_at` timestamp on it, and every
read query filters out rows where `deleted_at` is not null. This is the
standard approach in production systems (and is required by most real
platforms' data-retention rules): user-initiated deletion should be
reversible and auditable, not a silent, permanent `DROP`. The `reports`
table's Row-Level Security policies also no longer grant a real `DELETE` at
all — even a tampered client couldn't hard-delete a row, only ever soft-
delete their own pending one.

## Persistence & security (Row-Level Security)

`supabase/schema.sql` already had:
```sql
reports_insert_own        -- residents can create their own reports
reports_select_own_or_staff -- residents see their own; staff see all
reports_update_staff_only -- health workers/admins can change status
```

There was no policy letting a resident edit their own report, and no delete
policy at all — Supabase denies any operation with no matching policy.
`supabase/APPLY_THIS_NOW.sql` adds:
```sql
reports_update_own_pending  -- resident may UPDATE their own row, pending only
```
It also adds the `deleted_at` column used for soft delete, and explicitly
drops any hard-delete grant — real `DELETE` on this table is not permitted
for anyone but a service-role/admin working directly in Supabase.

**Run this file once in Supabase Studio → SQL Editor before testing Update
or Delete** (after `schema.sql` has already been run). Create and Read need
no new setup — they already worked.

## User-friendly interface notes

- Edit and Delete buttons only appear on a report card when it's still
  `pending` — no dead-end taps on a report staff already reviewed.
- Edit screen pre-fills every field from the existing record.
- Delete asks for confirmation in a dialog naming the report's location
  before removing it, and cannot be triggered accidentally.
- Both operations show a snackbar on success or a plain-language error
  message on failure (e.g. if the report is no longer pending because staff
  started reviewing it between page load and the tap).
