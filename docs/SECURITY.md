# Security and privacy checklist

## Enforced in supplied artifacts

- Role-aware client routes for safer UX
- RLS enabled on every operational table
- Signups default to Resident regardless of user metadata
- Owner/jurisdiction policies for exact reports, appointments, and waste work
- Waste staff cannot read suspected-case rows
- Privacy-safe resident map RPC with bounded viewport and no personal fields
- Server-generated displacement for suspected-case public coordinates
- Private evidence storage with size/MIME restrictions
- Restricted workflow-column updates
- Authenticated Edge Functions for protected provider calls
- No AI/provider/service-role keys in Flutter
- Explicit medical and analytics disclaimers

## Required before a real launch

1. Obtain a Philippine privacy/legal review and complete a data protection impact assessment.
2. Name data owners, processors, retention periods, and incident contacts.
3. Add verified Supabase Auth flows, MFA for personnel/admin, and secure account recovery.
4. Test every RLS policy with positive and negative cases using real JWT roles and jurisdictions.
5. Add immutable audit events for role changes, exports, evidence access, and destructive actions.
6. Validate uploads by magic bytes, re-encode images, strip EXIF, scan where appropriate, and use signed URLs.
7. Add rate limits/abuse controls to reporting, login, assistant, and provider proxy endpoints.
8. Add consent notices, a privacy policy, deletion/correction workflows, and retention jobs.
9. Configure CSP, HTTPS, secure headers, domain allowlists, logging redaction, alerting, backups, and restore drills.
10. Replace direct public OSM tile use with an appropriately provisioned provider if deployment volume requires it.
11. Obtain clinical/public-health review of guidance text and escalation behavior.
12. Perform accessibility, penetration, and incident-response testing.
13. Replace the Android demo debug-signing configuration with a protected release keystore and CI signing process before publishing.

## Prohibited patterns

- Supabase service-role key in Flutter or browser code
- AI/SMS/geocoding private key in `--dart-define`
- Public evidence bucket containing health/location photos
- Client-selected administrator or staff role
- Exact suspected-case pins on a resident/public map
- Public-Nominatim autocomplete
- Calling app-generated risk a diagnosis, confirmed case count, or official forecast
- Logging free-text health prompts, tokens, or signed evidence URLs

## Reporting a vulnerability

Do not open a public issue containing real personal or health information. Contact the project owner through a private channel and include only the minimum reproduction data needed.
