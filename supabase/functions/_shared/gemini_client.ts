// SysQuest — Cliente HTTP para Google Gemini (Interactions API 2026)
// Comunica con la API de Gemini usando structured outputs con JSON schema.
// Se usa un único modelo (gemini-3.8-flash) sin retry para
// respetar la cuota del free tier (5 RPM / 20 RPD). Cuando
// haya presupuesto para tier Paid, se puede reactivar el retry.

import { QUEST_JSON_SCHEMA } from './quest_schema.ts';

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
  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return { ok: false, codigo: 'CONFIG_FALTANTE' };
  }

  const endpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions';

  const requestBody = {
    model: 'gemini-3.8-flash',
    system_instruction: systemInstruction,
    input: userPrompt,
    response_format: {
      type: 'text',
      mime_type: 'application/json',
      schema: QUEST_JSON_SCHEMA,
    },
    generation_config: {
      temperature: 0.7,
      max_output_tokens: 6000,
    },
  };

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Gemini error:', response.status, errorText);
      return { ok: false, codigo: 'IA_NO_DISPONIBLE' };
    }

    const data = await response.json();

    // La Interactions API devuelve el texto dentro de `steps`,
    // no en un campo `output_text` directo.
    let outputText: string | null = null;
    if (Array.isArray(data?.steps)) {
      for (const step of data.steps) {
        if (step?.type === 'model_output' && Array.isArray(step?.content)) {
          const partes = step.content
            .filter((c: { type?: string; text?: string }) =>
              c?.type === 'text' && typeof c?.text === 'string'
            )
            .map((c: { text: string }) => c.text);
          if (partes.length > 0) {
            outputText = partes.join('');
          }
        }
      }
    }

    if (typeof outputText === 'string' && outputText.trim() !== '') {
      return { ok: true, texto: outputText };
    }

    return { ok: false, codigo: 'IA_RESPUESTA_VACIA' };
  } catch (error: unknown) {
    const esAbort =
      error instanceof DOMException && error.name === 'AbortError';
    if (esAbort) {
      return { ok: false, codigo: 'IA_TIMEOUT' };
    }
    console.error('Error de red o ejecución en llamarGemini:', error);
    return { ok: false, codigo: 'IA_NO_DISPONIBLE' };
  } finally {
    clearTimeout(timeoutId);
  }
}
