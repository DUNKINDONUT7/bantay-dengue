# Manual demo test plan

Run with `APP_MODE=demo`. Restart between scenarios when a clean seed is needed.

## Resident

1. Select Resident and enter the demo.
2. Confirm Home shows metrics, quick actions, advisories, weather context, and WHO context/fallback.
3. Open **Report a case**. Validate required symptoms, urgent warning guidance, location capture, and submit.
4. Open **Breeding site** or a Waste report. Enable evidence simulation and submit.
5. Open Reports and confirm only Juan Dela Cruz’s reports are listed.
6. Open Map. Confirm privacy notice and displaced/generalized suspected-case behavior.
7. Try a different resident’s report-detail URL and confirm it is blocked as protected.
8. Book an appointment. Confirm it appears Pending.
9. Open an Approved appointment QR and confirm the demo-token disclaimer.
10. Ask Bantay AI about prevention, symptoms, and severe bleeding; confirm the last case escalates to in-person care without diagnosis.

## Health Worker

1. Select Health Worker.
2. Open Reports and a pending item.
3. Test Verify, Request information, Reject, and Resolve actions across available reports.
4. Confirm reviewer note and assignment update.
5. Open Appointments and change Pending to Approved/Rescheduled/Completed.
6. Open Map and inspect exact operational details.
7. Publish an advisory with audience and severity.
8. Confirm direct navigation to Users or Analytics redirects to Dashboard.

## Waste Staff

1. Select Waste Staff.
2. Confirm Reports and Map omit suspected-case records.
3. Open Requests, search/filter, and move an item from Scheduled → Assigned → In progress → Collected.
4. Click Start route and confirm feedback.
5. Confirm direct Appointments, Users, Analytics, and Assistant routes redirect to Dashboard.

## Administrator

1. Select Administrator.
2. Open Users, add a demo user, and deactivate/reactivate a non-admin account.
3. Confirm the admin account cannot be deactivated through the demo control.
4. Open Analytics and switch 7/30/90-day filters.
5. Export CSV; confirm the preview appears and text is copied.
6. Review reports and publish an advisory.

## Automated checks

```bash
flutter analyze
flutter test
```

For Supabase integration, add policy tests that authenticate one account per role and verify cross-role/cross-barangay denials before connecting real data.
