// SysQuest — Interfaz común para proveedores de IA
// Define el puerto abstracto para desacoplar el motor de generación
// de cualquier proveedor específico (Groq, Gemini, OpenAI, Claude, etc.).
//
// Para agregar un nuevo proveedor:
//  1. Crear un archivo nuevo implementando la interfaz AiProvider.
//  2. Agregarlo al switch de ai_factory.ts.
//  3. Configurar la API key correspondiente como secreto de Supabase.
//  4. Cambiar la variable de entorno AI_PROVIDER o dejarla en 'auto'.

export interface QuestGenerationParams {
  systemInstruction: string;
  userPrompt: string;
  schema: object;
}

export type QuestGenerationResult =
  | { ok: true; texto: string; proveedor: string }
  | { ok: false; codigo: string; proveedor: string };

export interface AiProvider {
  readonly nombre: string;
  generarQuest(params: QuestGenerationParams): Promise<QuestGenerationResult>;
}
