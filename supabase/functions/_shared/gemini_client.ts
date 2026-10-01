// OBSOLETO: Se mantiene como referencia histórica.
// Usar supabase/functions/_shared/ai/ai_factory.ts para nuevos desarrollos.
// SysQuest — Adaptador para generación con IA (legacy)

export interface LlamarGeminiParams {
  systemInstruction: string;
  userPrompt: string;
}

export type LlamarGeminiResultado =
  | { ok: true; texto: string }
  | { ok: false; codigo: string };

export async function llamarGemini({
  systemInstruction,
  userPrompt,
}: LlamarGeminiParams): Promise<LlamarGeminiResultado> {
  const apiKey = Deno.env.get('GROQ_API_KEY') ?? Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return { ok: false, codigo: 'CONFIG_FALTANTE' };
  }

  const endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  const requestBody = {
    model: 'llama-3.3-70b-versatile',
    messages: [
      { role: 'system', content: systemInstruction },
      { role: 'user', content: userPrompt },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.7,
    max_tokens: 6000,
  };

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Groq error:', response.status, errorText);
      return { ok: false, codigo: 'IA_NO_DISPONIBLE' };
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content;

    if (typeof content === 'string' && content.trim() !== '') {
      return { ok: true, texto: content };
    }

    return { ok: false, codigo: 'IA_RESPUESTA_VACIA' };
  } catch (error: unknown) {
    const esAbort =
      error instanceof DOMException && error.name === 'AbortError';
    if (esAbort) {
      return { ok: false, codigo: 'IA_TIMEOUT' };
    }
    console.error('Error de red o ejecución en cliente IA (Groq):', error);
    return { ok: false, codigo: 'IA_NO_DISPONIBLE' };
  } finally {
    clearTimeout(timeoutId);
  }
}
