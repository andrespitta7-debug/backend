// SysQuest — Factory de proveedores de IA
// Selecciona dinámicamente el proveedor de IA según la configuración de entorno.

import { AiProvider, QuestGenerationResult } from './ai_provider.ts';
import { GroqProvider } from './groq_provider.ts';

class GeminiProviderStub implements AiProvider {
  readonly nombre = 'gemini';

  generarQuest(): Promise<QuestGenerationResult> {
    throw new Error(
      'GeminiProvider no está activo en este momento. Configure AI_PROVIDER=groq o use el proveedor por defecto.'
    );
  }
}

class ConfigFaltanteProvider implements AiProvider {
  readonly nombre = 'desconocido';

  generarQuest(): Promise<QuestGenerationResult> {
    return Promise.resolve({
      ok: false,
      codigo: 'CONFIG_FALTANTE',
      proveedor: this.nombre,
    });
  }
}

export function obtenerProveedor(): AiProvider {
  const modo = (Deno.env.get('AI_PROVIDER') ?? 'auto').toLowerCase();

  switch (modo) {
    case 'groq':
      return new GroqProvider();
    case 'gemini':
      return new GeminiProviderStub();
    case 'auto':
    default: {
      const groqKey = Deno.env.get('GROQ_API_KEY');
      if (groqKey) {
        return new GroqProvider();
      }
      return new ConfigFaltanteProvider();
    }
  }
}
