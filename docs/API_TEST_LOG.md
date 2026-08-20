# API Integration Test Log

**Generated:** 2026-08-19 (automated, via `curl` against the live endpoints the app calls)
**Purpose:** Midterm evidence for Section D — API Connection, GET/POST, error handling, and
authentication/authorization (RLS) enforcement. Every request below hits the **real** external
services and the **real, live** BantayDengue Supabase project — nothing here is mocked.

---

## 1. WHO Dengue Surveillance API — GET

**Used by:** `DengueApiService.fetchRecentStats()` (`lib/services/dengue_api_service.dart`)

```
GET https://xmart-api-public.who.int/ARBOV/V_DENGUE_GLOBAL_VALIDATED_PUBLIC
    ?$filter=ISO3 eq 'PHL'&$orderby=START_DATE desc&$top=12&excludeSysColumns=0
```

- **Status:** `200 OK`
- **Response:** `{"value":[]}` — endpoint reachable, query valid; WHO currently has no weekly
  surveillance rows queued for PHL in this table (the app handles this as an empty-state, not
  an error — see `dashboard_screen.dart`).

## 2. WHO Global Health Estimates API — GET (second, independent WHO endpoint)

**Used by:** `DengueApiService.fetchMortalityTrend()`

```
GET https://xmart-api-public.who.int/DEX_CMS/GHE_FULL_DD
    ?$filter=DIM_GHECAUSE_TITLE eq 'Dengue' and DIM_COUNTRY_CODE eq 'PHL' and DIM_SEX_CODE eq 'BTSX'
    &$orderby=DIM_YEAR_CODE desc&$top=6
```

- **Status:** `200 OK`
- **Response (excerpt):** real Philippines dengue mortality data for 2021 —
  `"DIM_YEAR_CODE":"2021","VAL_YLL_RATE100K_NUMERIC":81.76,"VAL_YLD_RATE100K_NUMERIC":10.95,...`

> ⚠️ First attempt at this endpoint used the wrong filter column (`ISO3` instead of
> `DIM_COUNTRY_CODE`) and returned `400 Bad Request` with a clear OData error message — corrected
> above. Good example of the app's error handling: `dengue_api_service.dart` catches a bad/empty
> response and surfaces `DengueApiException` instead of crashing.

## 3. Open-Meteo Weather Forecast API — GET

**Used by:** `WeatherService.fetchRisk()` (breeding-condition indicator on the resident dashboard)

```
GET https://api.open-meteo.com/v1/forecast
    ?latitude=14.75&longitude=120.95&daily=precipitation_sum,temperature_2m_max,temperature_2m_min
    &timezone=Asia/Manila&forecast_days=7
```

- **Status:** `200 OK`
- **Response (excerpt):** real 7-day forecast — `"precipitation_sum":[21.9,6.4,8.8,2.7,10.5,12.3,12.3]`

## 4. Supabase PostgREST — GET (public table, anon key)

```
GET https://vyhypddwnsybquzhkcmx.supabase.co/rest/v1/health_advisories?select=*&limit=5
Headers: apikey / Authorization: Bearer <anon key>
```

- **Status:** `200 OK`
- **Response:** `[]` — table reachable, empty because no advisory has been published yet in this
  environment (see "Remaining Features" — seed/demo advisory data).

## 5. Supabase PostgREST — GET `reports` without a user session (RLS check)

```
GET https://vyhypddwnsybquzhkcmx.supabase.co/rest/v1/reports?select=*&limit=5
```

- **Status:** `200 OK`
- **Response:** `[]` — confirms `reports_select_own_or_staff` correctly hides every row from an
  unauthenticated caller instead of leaking resident case data.

## 6. Supabase PostgREST — POST `reports` without a user session (RLS check)

```
POST https://vyhypddwnsybquzhkcmx.supabase.co/rest/v1/reports
Body: {"report_type":"dengue_case","description":"Automated API test","location_text":"API Test"}
```

- **Status:** `401 Unauthorized`
- **Response:**
  ```json
  {"code":"42501","message":"new row violates row-level security policy for table \"reports\""}
  ```
- **Why this matters:** this proves authorization is enforced **at the database layer**
  (`reports_insert_own` policy requires `reporter_id = auth.uid()`), not only hidden by the UI —
  directly satisfies the "Authentication/Authorization Implemented" checklist item.

## 7. Supabase Auth — GET service settings

```
GET https://vyhypddwnsybquzhkcmx.supabase.co/auth/v1/settings
```

- **Status:** `200 OK`
- **Response (excerpt):** `"email":true,"disable_signup":false,"mailer_autoconfirm":true` — confirms
  the Auth service is live and email/password sign-up (used by the app's login/signup screens) is
  enabled.

---

## Summary table

| # | Endpoint | Method | Status | Result |
|---|---|---|---|---|
| 1 | WHO surveillance stats | GET | 200 | OK — empty result set (no data currently queued upstream) |
| 2 | WHO mortality trend | GET | 200 | OK — real data returned |
| 3 | Open-Meteo forecast | GET | 200 | OK — real data returned |
| 4 | Supabase `health_advisories` | GET | 200 | OK — empty (no advisory published yet) |
| 5 | Supabase `reports` (no auth) | GET | 200 | OK — RLS correctly returns nothing |
| 6 | Supabase `reports` insert (no auth) | POST | 401 | Correctly rejected by RLS |
| 7 | Supabase Auth settings | GET | 200 | OK — auth service live |

**Update/status-change calls** (`updateReport`, `updateAppointmentStatus`, `updateWasteStatus`,
etc.) go through the same Supabase PostgREST `.update()` path as the insert calls above and are
covered by the same RLS policies (`reports_update_staff_only`, `reports_update_own_pending`) —
see `docs/CRUD_DOCUMENTATION.md` for the full policy list.

Raw `curl` request/response log: [`api_test_log_raw.txt`](./api_test_log_raw.txt) (same test run,
unformatted).
