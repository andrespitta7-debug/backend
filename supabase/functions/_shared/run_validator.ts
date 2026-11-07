// SysQuest — Validador para Run Extendida (Quest + Pool Narrativo + Preguntas Extra)
// Valida reglas N0–N3 para narrativa y E0–E2 para preguntas extra, además de V0–V9 para quests.

import {
  EncuentroIa,
  OpcionIa,
  QuestIa,
  validarQuestJson,
} from './quest_validator.ts';

export interface PoolNarrativoIa {
  intro: string[];
  entre_combates: string[];
  jefe_avistado: string[];
  ronda_completada: string[];
  retirada: string[];
  muerte: string[];
  critico: string[];
  contraataque: string[];
  [key: string]: string[];
}

export interface RunCompletaIa {
  quest_title?: string;
  resolved_topic?: string;
  quest: QuestIa;
  pool_narrativo?: PoolNarrativoIa;
  preguntas_extra: EncuentroIa[];
}

export type ResultadoValidacionPool =
  | { valido: true; pool: PoolNarrativoIa }
  | { valido: false; codigo: 'IA_POOL_INVALIDO' };

export type ResultadoValidacionPreguntasExtra =
  | { valido: true; preguntas: EncuentroIa[] }
  | { valido: false; codigo: 'IA_PREGUNTAS_INVALIDAS'; detalle?: string };

export type ResultadoValidacionRun =
  | { valido: true; run: RunCompletaIa }
  | { valido: false; codigo: string; detalle?: string };

export const CATEGORIAS_NARRATIVAS = [
  'intro',
  'entre_combates',
  'jefe_avistado',
  'ronda_completada',
  'retirada',
  'muerte',
  'critico',
  'contraataque',
] as const;

const REGEX_HIGIENE = /<[a-zA-Z]+>|```|\*\*|__|##/;

function normalizarTexto(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Valida un pool narrativo según reglas N0–N3:
 * N0: Tiene exactamente las 8 categorías requeridas.
 * N1: Cada categoría contiene exactamente 3 variantes.
 * N2: Cada variante es un string no vacío de 20 a 250 caracteres.
 * N3: Higiene: sin HTML ni formato markdown.
 */
export function validarPoolNarrativo(pool: unknown): ResultadoValidacionPool {
  if (!pool || typeof pool !== 'object' || Array.isArray(pool)) {
    console.error('[validarPoolNarrativo] N0 falla: el pool no es un objeto válido');
    return { valido: false, codigo: 'IA_POOL_INVALIDO' };
  }

  const poolRecord = pool as Record<string, unknown>;

  // N0: Exactamente las 8 categorías
  const llaves = Object.keys(poolRecord);
  if (llaves.length !== CATEGORIAS_NARRATIVAS.length) {
    console.error(
      '[validarPoolNarrativo] N0 falla: se esperaban 8 categorías exactas, se encontraron',
      llaves.length,
      llaves
    );
    return { valido: false, codigo: 'IA_POOL_INVALIDO' };
  }

  for (const cat of CATEGORIAS_NARRATIVAS) {
    if (!(cat in poolRecord)) {
      console.error('[validarPoolNarrativo] N0 falla: falta la categoría requerida', cat);
      return { valido: false, codigo: 'IA_POOL_INVALIDO' };
    }

    const variantes = poolRecord[cat];

    // N1: Exactamente 3 variantes por categoría
    if (!Array.isArray(variantes) || variantes.length !== 3) {
      console.error(
        '[validarPoolNarrativo] N1 falla en categoría',
        cat,
        ': se esperaban 3 variantes, se recibieron',
        Array.isArray(variantes) ? variantes.length : typeof variantes
      );
      return { valido: false, codigo: 'IA_POOL_INVALIDO' };
    }

    // N2 y N3: Tipo string, longitud 20-250, higiene
    for (const v of variantes) {
      if (typeof v !== 'string') {
        console.error('[validarPoolNarrativo] N2 falla en categoría', cat, ': la variante no es string');
        return { valido: false, codigo: 'IA_POOL_INVALIDO' };
      }
      const vTrim = v.trim();
      if (vTrim.length < 20 || vTrim.length > 250) {
        console.error(
          '[validarPoolNarrativo] N2 falla en categoría',
          cat,
          ': longitud fuera de rango 20-250 (longitud:',
          vTrim.length,
          '):',
          `"${vTrim.slice(0, 40)}..."`
        );
        return { valido: false, codigo: 'IA_POOL_INVALIDO' };
      }
      if (REGEX_HIGIENE.test(vTrim)) {
        console.error('[validarPoolNarrativo] N3 falla en categoría', cat, ': HTML/markdown detectado en variante:', vTrim);
        return { valido: false, codigo: 'IA_POOL_INVALIDO' };
      }
    }
  }

  return { valido: true, pool: pool as PoolNarrativoIa };
}

/**
 * Valida las preguntas extra según reglas E0–E2 (aplicando V2–V9 por pregunta):
 * E0: Exactamente 9 preguntas extra.
 * E1: Cada pregunta cumple con las especificaciones técnicas V2–V9.
 * E2: Numeradas consecutivamente del 4 al 12.
 */
export function validarPreguntasExtra(
  preguntas: unknown,
  categoria: string
): ResultadoValidacionPreguntasExtra {
  // E0: Exactamente 9 preguntas
  if (!Array.isArray(preguntas) || preguntas.length !== 9) {
    console.error(
      '[validarPreguntasExtra] E0 falla: se esperaban 9 preguntas, se recibieron',
      Array.isArray(preguntas) ? preguntas.length : typeof preguntas
    );
    return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `E0: se esperaban 9 preguntas, se recibieron ${Array.isArray(preguntas) ? preguntas.length : typeof preguntas}` };
  }

  for (let i = 0; i < 9; i++) {
    const enc = preguntas[i];

    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      console.error('[validarPreguntasExtra] Pregunta', i, 'falla: no es un objeto válido');
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} no es un objeto válido` };
    }

    // E2: Números 4 a 12 consecutivos
    if (typeof enc.numero !== 'number' || !Number.isInteger(enc.numero) || enc.numero !== i + 4) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'E2 falla: numero es',
        enc.numero,
        'pero se esperaba',
        i + 4
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} E2: numero es ${enc.numero}, esperado ${i + 4}` };
    }

    // E1: Estructura de encuentro (V2, V3)
    if (
      typeof enc.tipo_encuentro !== 'string' ||
      !['normal', 'jefe'].includes(enc.tipo_encuentro)
    ) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V2 falla: tipo_encuentro inválido:',
        enc.tipo_encuentro
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V2: tipo_encuentro inválido ${enc.tipo_encuentro}` };
    }

    if (
      typeof enc.enemigo !== 'string' ||
      enc.enemigo.trim().length < 3 ||
      enc.enemigo.trim().length > 40
    ) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V3 falla: enemigo con longitud',
        enc.enemigo?.trim?.()?.length,
        '(rango 3-40):',
        enc.enemigo
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: enemigo '${enc.enemigo}' longitud ${enc.enemigo?.trim?.()?.length} fuera de rango 3-40` };
    }

    if (
      typeof enc.pregunta !== 'string' ||
      enc.pregunta.trim().length < 10 ||
      enc.pregunta.trim().length > 400
    ) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V3 falla: pregunta con longitud',
        enc.pregunta?.trim?.()?.length,
        '(rango 10-400):',
        enc.pregunta
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: pregunta longitud ${enc.pregunta?.trim?.()?.length} fuera de rango 10-400` };
    }

    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      console.error('[validarPreguntasExtra] Pregunta', i, 'V2 falla: codigo no es string ni null');
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V2: codigo no es string ni null` };
    }

    if (enc.semantic_hint !== undefined && enc.semantic_hint !== null && typeof enc.semantic_hint !== 'string') {
      console.error('[validarPreguntasExtra] Pregunta', i, 'V2 falla: semantic_hint no es string ni null');
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V2: semantic_hint no es string ni null` };
    }

    if (typeof enc.semantic_hint === 'string' && enc.semantic_hint.length > 150) {
      console.error('[validarPreguntasExtra] Pregunta', i, 'V3 falla: semantic_hint longitud > 150:', enc.semantic_hint.length);
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: semantic_hint longitud > 150` };
    }

    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      console.error('[validarPreguntasExtra] Pregunta', i, 'V3 falla: codigo con longitud > 600:', enc.codigo.length);
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: codigo longitud > 600` };
    }

    // V7: código debe ser null en categoría 'libre'
    if (categoria === 'libre' && enc.codigo !== null) {
      console.error('[validarPreguntasExtra] Pregunta', i, 'V7 falla: codigo debe ser null en categoria libre');
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V7: codigo debe ser null en categoria libre` };
    }

    // V8: Higiene en encuentro
    if (
      REGEX_HIGIENE.test(enc.enemigo) ||
      REGEX_HIGIENE.test(enc.pregunta) ||
      (typeof enc.semantic_hint === 'string' && REGEX_HIGIENE.test(enc.semantic_hint))
    ) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V8 falla: HTML/markdown detectado en enemigo o pregunta'
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V8: markdown detectado en enemigo o pregunta` };
    }

    // Opciones (V5, V6, V8, V9)
    if (!Array.isArray(enc.opciones) || enc.opciones.length !== 4) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V4/V5 falla: se esperaban 4 opciones, se recibieron',
        Array.isArray(enc.opciones) ? enc.opciones.length : typeof enc.opciones
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V4: se esperaban 4 opciones` };
    }

    let cantCalidad2 = 0;
    let cantCalidad0 = 0;
    const textosVistos = new Set<string>();

    for (const op of enc.opciones) {
      if (!op || typeof op !== 'object' || Array.isArray(op)) {
        console.error('[validarPreguntasExtra] Pregunta', i, 'falla: opción no es objeto válido');
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} opción no es objeto válido` };
      }

      if (
        typeof op.texto !== 'string' ||
        op.texto.trim().length < 3 ||
        op.texto.trim().length > 200
      ) {
        console.error(
          '[validarPreguntasExtra] Pregunta',
          i,
          'V3 falla: texto de opción longitud',
          op.texto?.trim?.()?.length,
          '(rango 3-200):',
          op.texto
        );
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: texto opción longitud ${op.texto?.trim?.()?.length} fuera de rango 3-200` };
      }

      if (
        typeof op.calidad !== 'number' ||
        !Number.isInteger(op.calidad) ||
        ![0, 1, 2].includes(op.calidad)
      ) {
        console.error('[validarPreguntasExtra] Pregunta', i, 'V2 falla: calidad inválida:', op.calidad);
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V2: calidad inválida ${op.calidad}` };
      }

      if (
        typeof op.explicacion !== 'string' ||
        op.explicacion.trim().length < 10 ||
        op.explicacion.trim().length > 300
      ) {
        console.error(
          '[validarPreguntasExtra] Pregunta',
          i,
          'V3 falla: explicacion longitud',
          op.explicacion?.trim?.()?.length,
          '(rango 10-300):',
          op.explicacion
        );
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V3: explicacion longitud ${op.explicacion?.trim?.()?.length} fuera de rango 10-300 ('${op.explicacion}')` };
      }

      if (REGEX_HIGIENE.test(op.texto) || REGEX_HIGIENE.test(op.explicacion)) {
        console.error(
          '[validarPreguntasExtra] Pregunta',
          i,
          'V8 falla: HTML/markdown detectado en opción:',
          op.texto,
          op.explicacion
        );
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V8: markdown detectado en opción` };
      }

      if (op.calidad === 2) cantCalidad2++;
      if (op.calidad === 0) cantCalidad0++;

      const textoNorm = normalizarTexto(op.texto);
      if (textosVistos.has(textoNorm)) {
        console.error('[validarPreguntasExtra] Pregunta', i, 'V6 falla: textos de opciones repetidos:', op.texto);
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V6: textos de opciones repetidos` };
      }
      textosVistos.add(textoNorm);
    }

    if (cantCalidad2 !== 1 || cantCalidad0 < 1) {
      console.error(
        '[validarPreguntasExtra] Pregunta',
        i,
        'V5 falla: cantidad de calidad 2 =',
        cantCalidad2,
        '(esperada 1), calidad 0 =',
        cantCalidad0,
        '(esperada >= 1)'
      );
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS', detalle: `Pregunta ${i} V5: calidad 2 = ${cantCalidad2} (esp 1), calidad 0 = ${cantCalidad0} (esp >= 1)` };
    }

    // V9: Balance de longitud de opciones
    const opcionCorrecta = enc.opciones.find((op: { calidad: number }) => op.calidad === 2);
    if (opcionCorrecta) {
      const longitudesOtras = enc.opciones
        .filter((op: { calidad: number }) => op.calidad !== 2)
        .map((op: { texto: string }) => op.texto.trim().length);
      const promedioOtras =
        longitudesOtras.reduce((a: number, b: number) => a + b, 0) / longitudesOtras.length;
      const longitudCorrecta = opcionCorrecta.texto.trim().length;
      if (promedioOtras > 0 && longitudCorrecta > promedioOtras * 2) {
        console.error(
          '[validarPreguntasExtra] Pregunta',
          i,
          'V9 falla: opción correcta (',
          longitudCorrecta,
          'chars) es más del doble del promedio (',
          promedioOtras,
          'chars). Opción correcta:',
          opcionCorrecta.texto
        );
        return {
          valido: false,
          codigo: 'IA_PREGUNTAS_INVALIDAS',
          detalle: `Pregunta ${i + 4} V9: opción correcta (${longitudCorrecta}c) excede el doble del promedio (${promedioOtras.toFixed(1)}c)`
        };
      }
    }
  }

  return { valido: true, preguntas: preguntas as EncuentroIa[] };
}

/**
 * Valida la respuesta completa de la IA para una run extendida.
 * Puede validar tanto una respuesta con pool narrativo como una sin él (si viene de caché).
 */
export function validarRunCompleta(
  texto: string,
  categoria: string,
  _requierePool = false
): ResultadoValidacionRun {
  // V0: Texto vacío
  if (!texto || texto.trim() === '') {
    return { valido: false, codigo: 'IA_RESPUESTA_VACIA' };
  }

  // V1: Parsear JSON (limpiar fences ```json si existen)
  let jsonLimpio = texto.trim();
  if (jsonLimpio.startsWith('```')) {
    jsonLimpio = jsonLimpio
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/\s*```$/, '')
      .trim();
  }

  // deno-lint-ignore no-explicit-any
  let data: any;
  try {
    data = JSON.parse(jsonLimpio);
  } catch {
    return { valido: false, codigo: 'IA_JSON_INVALIDO' };
  }

  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }

  // =========================================================================
  // FORMA 1: Nuevo formato académico desacoplado (quest_title, resolved_topic, questions)
  // =========================================================================
  const questTitle = data.quest_title ?? data.titulo;
  const resolvedTopic = data.resolved_topic ?? data.tema;
  const rawQuestions = data.questions ?? data.preguntas;

  if (Array.isArray(rawQuestions)) {
    if (typeof questTitle !== 'string' || questTitle.trim().length < 3 || questTitle.trim().length > 80) {
      console.error('[validarRunCompleta] quest_title fuera de rango (3-80):', questTitle);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'quest_title debe tener entre 3 y 80 caracteres' };
    }

    if (typeof resolvedTopic !== 'string' || resolvedTopic.trim().length < 2 || resolvedTopic.trim().length > 80) {
      console.error('[validarRunCompleta] resolved_topic fuera de rango (2-80):', resolvedTopic);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'resolved_topic debe tener entre 2 y 80 caracteres' };
    }

    // Aceptamos entre 5 y 12 preguntas para que no falle si la IA devuelve 8 o 10
    if (rawQuestions.length < 5 || rawQuestions.length > 12) {
      console.error('[validarRunCompleta] questions fuera de rango (5-12):', rawQuestions.length);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Se esperaban entre 5 y 12 preguntas, se recibieron ${rawQuestions.length}` };
    }

    const preguntasValidadas: EncuentroIa[] = [];

    for (let i = 0; i < rawQuestions.length; i++) {
      const q = rawQuestions[i];
      if (!q || typeof q !== 'object' || Array.isArray(q)) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Pregunta ${i} no es un objeto válido` };
      }

      const preguntaTexto = q.pregunta ?? q.enunciado ?? q.question;
      if (typeof preguntaTexto !== 'string' || preguntaTexto.trim().length < 5 || preguntaTexto.trim().length > 300) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Pregunta ${i} enunciado fuera de rango (5-300 chars)` };
      }

      if (REGEX_HIGIENE.test(preguntaTexto)) {
        return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO', detalle: `Pregunta ${i} contiene markdown o HTML no permitido` };
      }

      const opcionesRaw = q.opciones ?? q.options;
      if (!Array.isArray(opcionesRaw) || opcionesRaw.length !== 4) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Pregunta ${i} debe tener exactamente 4 opciones` };
      }

      let correctIndex = typeof q.correct_index === 'number' ? q.correct_index : -1;
      if (correctIndex < 0 || correctIndex > 3) {
        if (typeof q.correcta === 'number' && q.correcta >= 0 && q.correcta <= 3) {
          correctIndex = q.correcta;
        } else {
          correctIndex = 0;
        }
      }

      const hintRaw = q.semantic_hint ?? q.pista ?? '';
      let semanticHint: string | undefined;
      if (typeof hintRaw === 'string' && hintRaw.trim().length > 0) {
        if (hintRaw.trim().length > 150) {
          return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Pregunta ${i} semantic_hint excede 150 caracteres` };
        }
        if (REGEX_HIGIENE.test(hintRaw)) {
          return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO', detalle: `Pregunta ${i} semantic_hint contiene formato no permitido` };
        }
        semanticHint = hintRaw.trim();
      }

      const opcionesMapeadas: OpcionIa[] = [];
      const textosVistos = new Set<string>();

      for (let j = 0; j < 4; j++) {
        const opVal = opcionesRaw[j];
        const textoOp = typeof opVal === 'string' ? opVal.trim() : (opVal?.texto ?? String(opVal)).trim();
        if (!textoOp) {
          return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `Pregunta ${i} opción ${j} vacía` };
        }
        if (REGEX_HIGIENE.test(textoOp)) {
          return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO', detalle: `Pregunta ${i} opción ${j} contiene formato no permitido` };
        }

        const norm = normalizarTexto(textoOp);
        if (textosVistos.has(norm)) {
          return { valido: false, codigo: 'IA_OPCIONES_INVALIDAS', detalle: `Pregunta ${i} opciones duplicadas` };
        }
        textosVistos.add(norm);

        const esCorrecta = j === correctIndex;
        let calidad: 0 | 1 | 2 = 1;
        if (esCorrecta) {
          calidad = 2;
        } else if (j === (correctIndex === 0 ? 1 : 0)) {
          calidad = 0;
        }

        opcionesMapeadas.push({
          texto: textoOp,
          calidad,
          explicacion: esCorrecta
            ? 'Respuesta correcta y óptima.'
            : (calidad === 0 ? 'Respuesta incorrecta.' : 'Respuesta parcialmente acertada pero subóptima.'),
        });
      }

      const esJefe = i === 2;
      preguntasValidadas.push({
        numero: i + 1,
        tipo_encuentro: esJefe ? 'jefe' : 'normal',
        enemigo: esJefe ? `Señor de la Mazmorra` : `Guardián ${i + 1}`,
        vida_enemigo: esJefe ? 100 : 50,
        concepto: `${resolvedTopic.trim()} (Fase ${i + 1})`,
        pregunta: preguntaTexto.trim(),
        codigo: null,
        semantic_hint: semanticHint,
        opciones: opcionesMapeadas,
      });
    }

    const encuentrosQuest = preguntasValidadas.slice(0, 3);
    const preguntasExtra = preguntasValidadas.slice(3).map((p, idx) => ({
      ...p,
      numero: idx + 4,
      tipo_encuentro: 'normal' as const,
      vida_enemigo: 50,
    }));

    return {
      valido: true,
      run: {
        quest_title: questTitle.trim(),
        resolved_topic: resolvedTopic.trim(),
        quest: {
          titulo: questTitle.trim(),
          tema: resolvedTopic.trim(),
          descripcion: `Misión académica sobre ${resolvedTopic.trim()}`,
          encuentros: encuentrosQuest,
        },
        pool_narrativo: undefined,
        preguntas_extra: preguntasExtra,
      },
    };
  }

  // =========================================================================
  // FORMA 2: Formato heredado (quest + preguntas_extra)
  // =========================================================================
  const questData = data.quest ?? (data.titulo && data.encuentros ? data : null);
  if (!questData) {
    console.error('[validarRunCompleta] falta clave quest o questions en data:', Object.keys(data));
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }

  const resQuest = validarQuestJson(JSON.stringify(questData), categoria);
  if (!resQuest.valido) {
    console.error('[validarRunCompleta] resQuest inválido:', resQuest.detalle);
    return { valido: false, codigo: resQuest.codigo, detalle: resQuest.detalle };
  }

  // Pool narrativo es opcional y NUNCA causa fallo con IA_POOL_INVALIDO
  let poolValido: PoolNarrativoIa | undefined = undefined;
  if (data.pool_narrativo && typeof data.pool_narrativo === 'object') {
    const resPool = validarPoolNarrativo(data.pool_narrativo);
    if (resPool.valido) {
      poolValido = resPool.pool;
    }
  }

  // Validar Preguntas Extra si están presentes
  let preguntasExtra: EncuentroIa[] = [];
  if (Array.isArray(data.preguntas_extra)) {
    const resPreguntas = validarPreguntasExtra(data.preguntas_extra, categoria);
    if (!resPreguntas.valido) {
      return { valido: false, codigo: resPreguntas.codigo, detalle: resPreguntas.detalle };
    }
    preguntasExtra = resPreguntas.preguntas;
  }

  return {
    valido: true,
    run: {
      quest_title: resQuest.quest.titulo,
      resolved_topic: resQuest.quest.tema ?? '',
      quest: resQuest.quest,
      pool_narrativo: poolValido,
      preguntas_extra: preguntasExtra,
    },
  };
}

export type ResultadoValidacionLoteExtra =
  | { valido: true; encuentros: EncuentroIa[] }
  | { valido: false; codigo: string; detalle?: string };

export function validarLoteEncuentrosExtra(
  encuentros: unknown,
  categoria: string,
  ultimoNumero: number
): ResultadoValidacionLoteExtra {
  if (!Array.isArray(encuentros) || encuentros.length !== 3) {
    return {
      valido: false,
      codigo: 'IA_ENCUENTROS_INVALIDOS',
      detalle: `Se esperaban 3 encuentros, se recibieron ${Array.isArray(encuentros) ? encuentros.length : typeof encuentros}`,
    };
  }

  for (let i = 0; i < 3; i++) {
    const enc = encuentros[i];
    const numeroEsperado = ultimoNumero + i + 1;

    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i} no es un objeto válido`,
      };
    }

    if (typeof enc.numero !== 'number' || !Number.isInteger(enc.numero) || enc.numero !== numeroEsperado) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: número es ${enc.numero}, esperado ${numeroEsperado}`,
      };
    }

    if (
      typeof enc.tipo_encuentro !== 'string' ||
      !['normal', 'jefe'].includes(enc.tipo_encuentro)
    ) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: tipo_encuentro inválido '${enc.tipo_encuentro}'`,
      };
    }

    if (
      typeof enc.enemigo !== 'string' ||
      enc.enemigo.trim().length < 3 ||
      enc.enemigo.trim().length > 40
    ) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: enemigo '${enc.enemigo}' longitud ${enc.enemigo?.trim?.()?.length} fuera de rango 3-40`,
      };
    }

    if (
      typeof enc.pregunta !== 'string' ||
      enc.pregunta.trim().length < 10 ||
      enc.pregunta.trim().length > 400
    ) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: pregunta longitud fuera de rango 10-400`,
      };
    }

    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: codigo no es string ni null`,
      };
    }

    if (enc.semantic_hint !== undefined && enc.semantic_hint !== null && typeof enc.semantic_hint !== 'string') {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: semantic_hint no es string ni null`,
      };
    }

    if (typeof enc.semantic_hint === 'string' && enc.semantic_hint.length > 150) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: semantic_hint longitud > 150`,
      };
    }

    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: codigo longitud > 600`,
      };
    }

    if (categoria === 'libre' && enc.codigo !== null) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: codigo debe ser null en categoría libre`,
      };
    }

    if (
      REGEX_HIGIENE.test(enc.enemigo) ||
      REGEX_HIGIENE.test(enc.pregunta) ||
      (typeof enc.semantic_hint === 'string' && REGEX_HIGIENE.test(enc.semantic_hint))
    ) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: markdown o html detectado en enemigo o pregunta`,
      };
    }

    if (!Array.isArray(enc.opciones) || enc.opciones.length !== 4) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: se esperaban 4 opciones`,
      };
    }

    let cantCalidad2 = 0;
    let cantCalidad0 = 0;
    const textosVistos = new Set<string>();

    for (const op of enc.opciones) {
      if (!op || typeof op !== 'object' || Array.isArray(op)) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: opción no es un objeto válido`,
        };
      }

      if (
        typeof op.texto !== 'string' ||
        op.texto.trim().length < 3 ||
        op.texto.trim().length > 200
      ) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: texto opción longitud fuera de rango 3-200`,
        };
      }

      if (
        typeof op.calidad !== 'number' ||
        !Number.isInteger(op.calidad) ||
        ![0, 1, 2].includes(op.calidad)
      ) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: calidad opción inválida (${op.calidad})`,
        };
      }

      if (
        typeof op.explicacion !== 'string' ||
        op.explicacion.trim().length < 10 ||
        op.explicacion.trim().length > 300
      ) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: explicacion longitud fuera de rango 10-300`,
        };
      }

      if (REGEX_HIGIENE.test(op.texto) || REGEX_HIGIENE.test(op.explicacion)) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: markdown o html detectado en opciones`,
        };
      }

      if (op.calidad === 2) cantCalidad2++;
      if (op.calidad === 0) cantCalidad0++;

      const textoNorm = normalizarTexto(op.texto);
      if (textosVistos.has(textoNorm)) {
        return {
          valido: false,
          codigo: 'IA_ENCUENTROS_INVALIDOS',
          detalle: `Encuentro ${i}: textos de opciones repetidos`,
        };
      }
      textosVistos.add(textoNorm);
    }

    if (cantCalidad2 !== 1 || cantCalidad0 < 1) {
      return {
        valido: false,
        codigo: 'IA_ENCUENTROS_INVALIDOS',
        detalle: `Encuentro ${i}: calidad 2 = ${cantCalidad2} (esp 1), calidad 0 = ${cantCalidad0} (esp >= 1)`,
      };
    }

    // V9: Balance de longitud de opciones
    const opcionCorrecta = enc.opciones.find((op: { calidad: number }) => op.calidad === 2);
    if (opcionCorrecta) {
      const longitudesOtras = enc.opciones
        .filter((op: { calidad: number }) => op.calidad !== 2)
        .map((op: { texto: string }) => op.texto.trim().length);
      const promedioOtras =
        longitudesOtras.reduce((a: number, b: number) => a + b, 0) /
        longitudesOtras.length;
      const longitudCorrecta = opcionCorrecta.texto.trim().length;

      if (promedioOtras > 0 && longitudCorrecta > promedioOtras * 2) {
        return {
          valido: false,
          codigo: 'IA_OPCIONES_DESBALANCEADAS',
          detalle: `Encuentro ${i}: opción correcta (${longitudCorrecta}c) excede el doble del promedio (${promedioOtras.toFixed(1)}c)`,
        };
      }
    }
  }

  return { valido: true, encuentros: encuentros as EncuentroIa[] };
}
