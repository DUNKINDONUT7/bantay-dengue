// Basic k6 smoke/load test against this project's Supabase REST endpoints.
//
// WHY THIS EXISTS: I (the assistant) have no network access in my sandbox —
// I can't run this against your live Supabase project myself. This script
// is for YOU to run locally before you sign off.
//
// WHAT IT DOES: hits read-only, RLS-public-safe endpoints (advisories,
// hotspots) with a ramping number of virtual users, and checks response
// time + status code. It does NOT attempt to sign up, submit reports, or
// otherwise write data — running a write-heavy load test against your real
// database would pollute it with junk rows.
//
// HOW TO RUN:
//   1. Install k6: https://k6.io/docs/get-started/installation/
//   2. Set two environment variables (same values as your env.json):
//        export SUPABASE_URL="https://YOUR-PROJECT-REF.supabase.co"
//        export SUPABASE_ANON_KEY="your-anon-or-publishable-key"
//   3. Run:
//        k6 run loadtest/k6-smoke.js
//
// WHAT TO LOOK FOR: k6's summary at the end. http_req_duration p(95) should
// stay reasonably low (a few hundred ms is fine for Supabase's shared free
// tier), and http_req_failed should be ~0%. If failures spike as VUs ramp
// up, that's your real signal — not something a client-side app change can
// fix; it means the Supabase project tier needs to scale or a query needs
// an index.

import http from 'k6/http';
import { check, sleep } from 'k6';

const SUPABASE_URL = __ENV.SUPABASE_URL;
const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error(
    'Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables first — see the comment at the top of this file.'
  );
}

export const options = {
  scenarios: {
    ramping_smoke: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 10 }, // ramp to 10 concurrent users
        { duration: '40s', target: 10 }, // hold
        { duration: '20s', target: 30 }, // spike to 30
        { duration: '20s', target: 0 },  // ramp down
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'], // fewer than 2% failed requests
    http_req_duration: ['p(95)<1500'], // 95% of requests under 1.5s
  },
};

const headers = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
};

export default function () {
  // Public advisories list — matches what advisories_screen.dart fetches.
  const advisories = http.get(
    `${SUPABASE_URL}/rest/v1/health_advisories?select=id,title,created_at&order=created_at.desc&limit=20`,
    { headers }
  );
  check(advisories, {
    'health_advisories status is 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // Public hotspots — matches what hotspot_map_screen.dart fetches.
  const hotspots = http.get(
    `${SUPABASE_URL}/rest/v1/hotspots?select=id,latitude,longitude,risk_level&limit=100`,
    { headers }
  );
  check(hotspots, {
    'hotspots status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
