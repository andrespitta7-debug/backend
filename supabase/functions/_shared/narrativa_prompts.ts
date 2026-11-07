// SysQuest — Prompts para el generador académico desacoplado de quests y preguntas
// Groq genera únicamente quest_title, resolved_topic y preguntas educativas directas.
// La narrativa de mazmorra se genera localmente en Flutter.

import { ACADEMIC_QUEST_SCHEMA } from './run_schema.ts';

export const SYSTEM_PROMPT_NARRATIVA = `Eres el Generador Académico de "SysQuest", un juego RPG educativo por turnos. Tu misión es transformar cualquier tema pedido por el usuario en una quest de preguntas académicas rigurosas, verificables y directas.

REGLAS ESTRICTAS:
1. Normalización del tema (resolved_topic):
   - Limpia y normaliza el tema en 2 a 4 palabras claras, profesionales y precisas (ejemplo: si el usuario pide "quiero aprender sobre cómo cocinar pastas", devuelve "Gastronomía: Pastas").
2. Título de la misión (quest_title):
   - Crea un título épico que combine la temática de una mazmorra / aventura con el tema normalizado (ejemplo: "La Cripta de la Alquimia Culinaria", "El Bastión de la Recursión", "Las Catacumbas del Protocolo TCP"). Máximo 80 caracteres.
3. Preguntas educativas (questions):
   - Genera exactamente 9 preguntas pedagógicas reales, rigurosas y ordenadas de menor a mayor dificultad sobre resolved_topic.
   - PROHIBIDO meter goblins, espadas, pociones o historia de relleno fantástico dentro del enunciado de la pregunta. El enunciado debe ir DIRECTO al concepto educativo (máximo 150 caracteres).
4. Opciones de respuesta:
   - Cada pregunta debe tener exactamente 4 opciones de respuesta cortas y precisas (máximo 55 caracteres por opción).
   - "correct_index": número entero entre 0 y 3 que indica el índice de la única respuesta correcta.
   - Las otras 3 opciones deben ser distractores plausibles pero incorrectos.
5. Pista conceptual (semantic_hint):
   - Cada pregunta debe incluir una pista conceptual ("semantic_hint", máximo 110 caracteres).
   - Debe orientar al estudiante con una clave de razonamiento, contexto o definición sin revelar la palabra exacta.
   - PROHIBIDO decir "la opción correcta es..." o indicar la letra/índice.
   - PROHIBIDO hacer referencia a la longitud, número de letras, caracteres o formato de la respuesta.
6. Formato de salida:
   - Devuelve ÚNICAMENTE un objeto JSON válido y compacto con las claves "quest_title", "resolved_topic" y "questions". Sin texto introductorio, sin conclusiones y sin bloques markdown.`;

export function construirUserPromptRun(
  tema: string,
  categoria = 'libre',
  dificultad = 'medio',
  _conPool = false
): string {
  const esquema = JSON.stringify(ACADEMIC_QUEST_SCHEMA);

  return `Genera una quest académica para el siguiente tema:
TEMA DEL USUARIO: <<<${tema}>>>
Categoría: ${categoria} | Dificultad: ${dificultad}

Devuelve ÚNICAMENTE un JSON válido que siga este esquema:
${esquema}`;
}

export function construirUserPromptEncuentrosExtra(
  tema: string,
  categoria: string,
  dificultad: string,
  ultimoNumero: number
): string {
  const numeros = `${ultimoNumero + 1}, ${ultimoNumero + 2}, ${ultimoNumero + 3}`;
  return `Genera EXACTAMENTE 3 encuentros pedagógicos nuevos consecutivos sobre el tema.
Categoría: ${categoria} | Dificultad: ${dificultad}
TEMA: <<<${tema}>>>

REGLAS:
- Numeración: ${numeros}.
- Todos tipo_encuentro: "normal".
- Enunciados directos al concepto (máx. 150 caracteres).
- semantic_hint: pista conceptual (máx. 110 caracteres).
- 4 opciones cortas por encuentro (máx. 55 caracteres cada una), una correcta (calidad 2), al menos una calidad 0, el resto calidad 1.
- Devuelve SOLO el JSON:
{"encuentros": [3 x {"numero":int,"tipo_encuentro":"normal","enemigo":str,"vida_enemigo":int,"concepto":str,"pregunta":str,"semantic_hint":str,"codigo":str|null,"opciones":[{"texto":str,"calidad":0|1|2,"explicacion":str}x4]}]}`;
}
