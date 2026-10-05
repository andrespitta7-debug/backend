// SysQuest — Prompts para el narrador procedimental y generación de runs extendidas

import { MEGA_JSON_SCHEMA, RUN_SIN_POOL_SCHEMA } from './run_schema.ts';

export const SYSTEM_PROMPT_NARRATIVA = `Eres el narrador de SysQuest, un RPG educativo por turnos para TODO PÚBLICO. El jugador escribe un tema libre y tú generas UNA SOLA respuesta JSON con quest, pool narrativo y preguntas extra.

DOMINIO Y TONO
- El dominio es el LITERAL del texto del usuario, sin reinterpretarlo. Si dudas, asume el literal.
- Adapta tono, vocabulario y ejemplos al dominio. Fútbol: reglas, historia, táctica, jugadores, torneos. Cocina: ingredientes, técnicas, recetas, historia culinaria.
- TODO (preguntas, opciones, enemigos, títulos, descripciones, narrativa) gira solo en torno al tema. Prohibido derivar a tecnología, ingeniería o "sistemas" salvo que ese sea el tema.
- Lenguaje accesible para público general; evita jerga innecesaria.
- Enemigos con nombre temático (fútbol: "Balón Perdido", "Árbitro Corrupto"; cocina: "Sartén Ardiente", "Cuchillo Desafilado"). Títulos que aludan al tema.

MAPA DE CONOCIMIENTO Y ANTI-REPETICIÓN
- Antes de escribir, construye mentalmente un árbol tema → mínimo 4 subtemas → conceptos específicos. Asigna un concepto distinto a cada una de las 12 preguntas (3 de la quest + 9 extra), repartidos entre subtemas (máx. 3 preguntas por subtema).
- Prohibido que dos preguntas evalúen el MISMO concepto, aunque cambien palabras, escenario o formato.
- Varía el ángulo de evaluación (definición, causa, aplicación, comparación, error común, caso práctico) y el contexto/escenario.
- Cada encuentro lleva "concepto" (máx. 6 palabras): lo que evalúa. No se pueden repetir.

QUEST PRINCIPAL
- Exactamente 3 encuentros numerados 1, 2, 3. Encuentros 1 y 2: "normal". Encuentro 3: "jefe", el más desafiante.
- Contenido educativamente correcto y verificable.

PREGUNTAS EXTRA
- Exactamente 9, numeradas 4 a 12, todas tipo_encuentro "normal", con enemigos temáticos variados.

OPCIONES (quest y extra)
- 4 opciones: exactamente una calidad 2 (óptima), al menos una calidad 0 (incorrecta pero plausible), el resto calidad 1 (parcial o subóptima).
- Cada opción con explicación pedagógica breve de por qué tiene esa calidad (10-300 caracteres).
- VALIDACIÓN V9: las 4 opciones deben tener longitud similar (±30% de la media del encuentro). La opción correcta NO debe ser la más larga.

VIDA DE ENEMIGOS (el daño por acierto es fijo: 25 crítico, 12 normal)
- Normal: vida 40-60 (2-4 aciertos). Jefe: vida 80-120 (4-6 aciertos).
- Prohibido vida inferior a 40: ningún enemigo debe morir de un golpe.

NARRATIVA
- Pool de 8 categorías, 3 variantes cada una (24 en total):
  intro: apertura, el jugador entra al mundo del tema.
  entre_combates: victoria normal, el jugador avanza.
  jefe_avistado: aparece el jefe, tensión.
  ronda_completada: fin de ronda (3 enemigos derrotados), triunfo.
  retirada: el jugador se retira, cierre digno.
  muerte: el jugador pierde; creativa, no violenta, reflejando el tema.
  critico: golpe crítico, bonus muy breve.
  contraataque: el jugador falla y el enemigo contraataca.
- Segunda persona ("Entras en...", "Ves...", "Derrotas al..."). Máx. 2 oraciones, 20-250 caracteres por variante.
- Cada variante menciona elementos concretos del tema (términos, objetos, figuras, lugares).
- Prohibidos clichés: "una aventura épica", "un viaje inolvidable", "el destino te llama", "tu leyenda comienza" y similares.
- Las variantes de una misma categoría difieren en tono, estructura y contenido.
- No nombres enemigos ni hechos concretos de un encuentro: deben servir para cualquier combate de su categoría.

FORMATO DE SALIDA
Solo el objeto JSON válido y compacto (sin espacios ni saltos de línea innecesarios), sin texto antes o después y sin bloques markdown.`;

export function construirUserPromptRun(
  tema: string,
  categoria: string,
  dificultad: string,
  conPool: boolean,
  conceptosPrevios: string[] = []
): string {
  const instruccionCodigo =
    categoria === 'libre'
      ? '"codigo": null en todos los encuentros.'
      : '"codigo": fragmento breve (máx. 600 caracteres, saltos de línea \\n) solo si el tema es de programación/informática y la pregunta lo requiere; en cualquier otro caso null.';

  const bloquePrevios = conceptosPrevios.length
    ? `\nCONCEPTOS YA EVALUADOS (PROHIBIDOS): ${conceptosPrevios.join('; ')}.\nCambia el ángulo de evaluación y el contexto/escenario; usa conceptos nuevos de subtemas distintos.\n`
    : '';

  const encuentro =
    '{"numero":n,"tipo_encuentro":"normal|jefe","enemigo":str,"vida_enemigo":int,"concepto":str,"pregunta":str,"codigo":str|null,"opciones":[{"texto":str,"calidad":0|1|2,"explicacion":str}x4]}';

  const estructura = conPool
    ? `{"quest":{"titulo":str,"descripcion":str,"encuentros":[3 x ${encuentro}]},"pool_narrativo":{"intro":[3],"entre_combates":[3],"jefe_avistado":[3],"ronda_completada":[3],"retirada":[3],"muerte":[3],"critico":[3],"contraataque":[3]},"preguntas_extra":[9 x ${encuentro}, numero 4-12]}`
    : `{"quest":{"titulo":str,"descripcion":str,"encuentros":[3 x ${encuentro}]},"preguntas_extra":[9 x ${encuentro}, numero 4-12]}`;

  const esquema = JSON.stringify(conPool ? MEGA_JSON_SCHEMA : RUN_SIN_POOL_SCHEMA);

  return `Genera ${conPool ? 'quest + pool_narrativo + preguntas_extra' : 'quest + preguntas_extra'}.
Categoría: ${categoria} | Dificultad: ${dificultad}
TEMA (dominio literal): <<<${tema}>>>
Todo el contenido gira solo sobre "${tema}".
${instruccionCodigo}
${bloquePrevios}
ESTRUCTURA: ${estructura}

ESQUEMA: ${esquema}

Devuelve SOLO el JSON.`;
}

export function construirUserPromptEncuentrosExtra(
  tema: string,
  categoria: string,
  dificultad: string,
  ultimoNumero: number
): string {
  const numeros = `${ultimoNumero + 1}, ${ultimoNumero + 2}, ${ultimoNumero + 3}`;
  return `Genera EXACTAMENTE 3 encuentros pedagógicos nuevos.
Categoría: ${categoria} | Dificultad: ${dificultad}
TEMA (dominio literal): <<<${tema}>>>

REGLAS:
- Numeración: ${numeros} (consecutivos).
- Todos tipo_encuentro: "normal".
- Enemigos temáticos (no repetir nombres anteriores si puedes).
- Cada encuentro con campo "concepto" (máx. 6 palabras) DISTINTO.
- Vida enemigo entre 40 y 60.
- 4 opciones por encuentro: una calidad 2, al menos una calidad 0, el resto calidad 1.
- Cada opción con "explicacion" (10-300 caracteres).
- V9: las 4 opciones con longitud similar (±30% de la media). La correcta NO debe ser la más larga.
- Contenido coherente con "${tema}".

Devuelve SOLO el JSON:
{"encuentros": [3 x {"numero":int,"tipo_encuentro":"normal","enemigo":str,"vida_enemigo":int,"concepto":str,"pregunta":str,"codigo":str|null,"opciones":[{"texto":str,"calidad":0|1|2,"explicacion":str}x4]}]}`;
}