import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json } from '../_shared/cors.ts';

const emergencyPattern = /bleeding|pagdurugo|hirap huminga|difficulty breathing|severe abdominal|matinding sakit|persistent vomiting|tuloy-tuloy na pagsusuka|faint|unconscious/i;
const systemPrompt = `You are Bantay AI, a dengue information assistant for Marilao, Bulacan. Reply in the user's language (Filipino, English, or mixed). Give concise, evidence-aligned general education and prevention guidance only. Never diagnose, prescribe, calculate dosage, interpret a laboratory result, or claim certainty. Tell users with warning signs to seek urgent in-person care. Mention that the service does not replace a health professional. Do not ask for names, addresses, phone numbers, or other identifying health information.`;

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);
  const token = auth.slice('Bearer '.length);

  // Verify the caller's identity from their own token — never trust a
  // client-supplied user id. SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY are
  // injected automatically into every Edge Function; no manual secret
  // needed for these three.
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData?.user) return json({ error: 'Invalid or expired session' }, 401);

  // Real, database-enforced rate limit (see
  // supabase/RATE_LIMIT_AI_ASSISTANT.sql) — the client-side cooldown in
  // ai_chat_screen.dart deters accidental spam, this is what actually stops
  // a script hitting this function directly with a valid token from burning
  // AI provider quota/cost.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: allowed, error: rateLimitError } = await adminClient.rpc(
    'check_and_log_ai_request',
    { p_user_id: userData.user.id },
  );
  if (rateLimitError) {
    console.error('Rate limit check failed', rateLimitError);
    return json({ error: 'Guidance service is temporarily unavailable' }, 502);
  }
  if (!allowed) {
    return json(
      {
        error: 'Too many questions in a short time. Please wait a moment before asking again.',
        code: 'rate_limited',
      },
      429,
    );
  }

  let message = '';
  try {
    const body = await request.json();
    message = String(body?.message ?? '').trim();
  } catch {
    return json({ error: 'Invalid JSON body' }, 400);
  }
  if (message.length < 1 || message.length > 1000) return json({ error: 'Message must contain 1–1000 characters' }, 400);

  if (emergencyPattern.test(message)) {
    return json({
      reply: 'Maaaring warning sign iyan. Huwag maghintay sa chat—pumunta agad sa pinakamalapit na health center o emergency facility. Kung may matinding pagdurugo, hirap huminga, sobrang panghihina, o tuloy-tuloy na pagsusuka, humingi agad ng emergency help.',
      urgent: true,
      disclaimer: 'General information only; not a diagnosis or emergency service.',
    });
  }

  const apiKey = Deno.env.get('AI_API_KEY');
  const baseUrl = (Deno.env.get('AI_BASE_URL') ?? 'https://api.openai.com/v1').replace(/\/$/, '');
  const model = Deno.env.get('AI_MODEL') ?? 'gpt-4.1-mini';
  if (!apiKey) return json({ error: 'AI provider is not configured', code: 'provider_not_configured' }, 503);

  const upstream = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      max_completion_tokens: 350,
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: message }],
    }),
  });

  if (!upstream.ok) {
    // Log the upstream body too (never the health message) — this is the
    // one piece of information the Supabase dashboard logs can't give you
    // without digging, and it's usually the exact reason (bad model name,
    // bad key, wrong base URL).
    const errorBody = await upstream.text().catch(() => '<unreadable>');
    console.error('AI provider failure', upstream.status, errorBody);
    return json(
      { error: 'Guidance service is temporarily unavailable', upstream_status: upstream.status },
      502,
    );
  }
  const result = await upstream.json();
  const reply = String(result?.choices?.[0]?.message?.content ?? '').trim();
  if (!reply) return json({ error: 'Guidance service returned an empty response' }, 502);
  return json({ reply, urgent: false, disclaimer: 'General information only; not a diagnosis or emergency service.' });
});
