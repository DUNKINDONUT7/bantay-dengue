import { corsHeaders, json } from '../_shared/cors.ts';

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  if (!request.headers.get('Authorization')?.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);

  let latitude = 14.7566;
  let longitude = 120.9558;
  try {
    const body = await request.json().catch(() => ({}));
    latitude = Number(body.latitude ?? latitude);
    longitude = Number(body.longitude ?? longitude);
  } catch {
    return json({ error: 'Invalid request' }, 400);
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return json({ error: 'Invalid coordinates' }, 400);
  }

  const query = new URLSearchParams({
    latitude: latitude.toString(),
    longitude: longitude.toString(),
    daily: 'precipitation_sum,temperature_2m_max,temperature_2m_min',
    timezone: 'Asia/Manila',
    forecast_days: '7',
  });
  const upstream = await fetch(`https://api.open-meteo.com/v1/forecast?${query}`, { headers: { 'User-Agent': 'BantayDengue/1.0 community-health-demo' } });
  if (!upstream.ok) return json({ error: 'Weather service unavailable' }, 502);
  const data = await upstream.json();
  const rainfall: number[] = data?.daily?.precipitation_sum ?? [];
  const maxTemps: number[] = data?.daily?.temperature_2m_max ?? [];
  const totalRainMm = rainfall.reduce((sum, value) => sum + Number(value || 0), 0);
  const warmDays = maxTemps.filter((value) => Number(value) >= 27).length;

  // Operational breeding-condition indicator only; never a clinical prediction.
  const score = Math.min(100, Math.round(totalRainMm * 1.5 + warmDays * 5));
  const level = score >= 70 ? 'high' : score >= 35 ? 'moderate' : 'low';
  return json({
    level,
    score,
    total_rain_mm: Number(totalRainMm.toFixed(1)),
    warm_days: warmDays,
    source: 'Open-Meteo forecast',
    methodology: 'App-defined breeding-condition indicator based on seven-day forecast rainfall and warm days.',
    disclaimer: 'Not a dengue forecast, diagnosis, or official surveillance measure.',
    fetched_at: new Date().toISOString(),
  });
});
