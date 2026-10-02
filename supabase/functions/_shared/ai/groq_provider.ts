// SysQuest — Proveedor de IA utilizando Groq API
// Modelo: llama-3.3-70b-versatile en modo JSON Object (OpenAI compatible)

import {
  AiProvider,
  QuestGenerationParams,
  QuestGenerationResult,
} from './ai_provider.ts';

export class GroqProvider implements AiProvider {
  readonly nombre = 'groq';

  async generarQuest(
    params: QuestGenerationParams
  ): Promise<QuestGenerationResult> {
    const apiKey = Deno.env.get('GROQ_API_KEY');
    if (!apiKey) {
      return { ok: false, codigo: 'CONFIG_FALTANTE', proveedor: this.nombre };
    }

    const endpoint = 'https://api.groq.com/openai/v1/chat/completions';

    const requestBody = {
      model: 'qwen/qwen3.8-27b',
      messages: [
        { role: 'system', content: params.systemInstruction },
        { role: 'user', content: params.userPrompt },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
      max_tokens: 8000,
    };

    const timeoutMs = params.timeoutMs ?? 60000;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

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
        return {
          ok: false,
          codigo: 'IA_NO_DISPONIBLE',
          proveedor: this.nombre,
        };
      }

      const data = await response.json();
      const content = data?.choices?.[0]?.message?.content;

      if (typeof content === 'string' && content.trim() !== '') {
        return {
          ok: true,
          texto: content,
          proveedor: this.nombre,
        };
      }

      return {
        ok: false,
        codigo: 'IA_RESPUESTA_VACIA',
        proveedor: this.nombre,
      };
    } catch (error: unknown) {
      const esAbort =
        error instanceof DOMException && error.name === 'AbortError';
      if (esAbort) {
        return { ok: false, codigo: 'IA_TIMEOUT', proveedor: this.nombre };
      }
      console.error('Error de red o ejecución en GroqProvider:', error);
      return {
        ok: false,
        codigo: 'IA_NO_DISPONIBLE',
        proveedor: this.nombre,
      };
    } finally {
      clearTimeout(timeoutId);
    }
  }
}
