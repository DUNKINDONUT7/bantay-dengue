# Archived docs — superseded, not maintained

These describe an earlier design of this project and are kept for history
only. **Do not follow instructions in these files** — several actively
contradict how the project actually works today.

| File | Why it's archived |
|---|---|
| `SUPABASE_SETUP.md` | Describes the abandoned PostGIS/`supabase db reset`/CLI-tracked-migrations design (the same one `supabase/_archive/README.md` documents as never applied to the live project). The real setup path is hand-run SQL files tracked in `supabase/README.md` — see the root `README.md` and `docs/DEPLOYMENT.md`, both of which are current. |
| `VALIDATION.md` | Same abandoned-migration assumption (references `supabase db reset` and `DEMO_TEST_PLAN.md`'s policy tests against that schema). |
| `DEMO_TEST_PLAN.md` | A specific historical test pass against that earlier schema. |
| `API_TEST_LOG.md` / `api_test_log_raw.txt` | The `curl`/RLS test evidence for that same historical pass. |
| `FULL_ROADMAP.md` | Planning doc written against the same abandoned PostGIS/jurisdiction-based schema — its feature list assumes tables and RPCs (`get_public_report_markers`, municipality/barangay jurisdiction columns) that were never applied. |

If you're setting this project up, use the root `README.md` (client) and
`supabase/README.md` (database, run order, what's live) instead — those are
the ones kept in sync with the actual codebase.
