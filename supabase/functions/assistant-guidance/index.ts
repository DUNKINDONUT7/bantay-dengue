import { corsHeaders, json } from '../_shared/cors.ts';

const emergencyPattern = /bleeding|pagdurugo|hirap huminga|difficulty breathing|severe abdominal|matinding sakit|persistent vomiting|tuloy-tuloy na pagsusuka|faint|unconscious/i;
const systemPrompt = `You are Bantay AI, a dengue information assistant for Marilao, Bulacan. Reply in the user's language (Filipino, English, or mixed). Give concise, evidence-aligned general education and prevention guidance only. Never diagnose, prescribe, calculate dosage, interpret a laboratory result, or claim certainty. Tell users with warning signs to seek urgent in-person care. Mention that the service does not replace a health professional. Do not ask for names, addresses, phone numbers, or other identifying health information.`;

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);

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
      max_tokens: 350,
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: message }],
    }),
  });

  if (!upstream.ok) {
    console.error('AI provider failure', upstream.status); // Never log the health message.
    return json({ error: 'Guidance service is temporarily unavailable' }, 502);
  }
  const result = await upstream.json();
  const reply = String(result?.choices?.[0]?.message?.content ?? '').trim();
  if (!reply) return json({ error: 'Guidance service returned an empty response' }, 502);
  return json({ reply, urgent: false, disclaimer: 'General information only; not a diagnosis or emergency service.' });
});
