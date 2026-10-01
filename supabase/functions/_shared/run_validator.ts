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
  quest: QuestIa;
  pool_narrativo?: PoolNarrativoIa;
  preguntas_extra: EncuentroIa[];
}

export type ResultadoValidacionPool =
  | { valido: true; pool: PoolNarrativoIa }
  | { valido: false; codigo: 'IA_POOL_INVALIDO' };

export type ResultadoValidacionPreguntasExtra =
  | { valido: true; preguntas: EncuentroIa[] }
  | { valido: false; codigo: 'IA_PREGUNTAS_INVALIDAS' };

export type ResultadoValidacionRun =
  | { valido: true; run: RunCompletaIa }
  | { valido: false; codigo: string };

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
 * N1: Cada categoría contiene exactamente 4 variantes.
 * N2: Cada variante es un string no vacío de 20 a 250 caracteres.
 * N3: Higiene: sin HTML ni formato markdown.
 */
export function validarPoolNarrativo(pool: unknown): ResultadoValidacionPool {
  if (!pool || typeof pool !== 'object' || Array.isArray(pool)) {
    return { valido: false, codigo: 'IA_POOL_INVALIDO' };
  }

  const poolRecord = pool as Record<string, unknown>;

  // N0: Exactamente las 8 categorías
  const llaves = Object.keys(poolRecord);
  if (llaves.length !== CATEGORIAS_NARRATIVAS.length) {
    return { valido: false, codigo: 'IA_POOL_INVALIDO' };
  }

  for (const cat of CATEGORIAS_NARRATIVAS) {
    if (!(cat in poolRecord)) {
      return { valido: false, codigo: 'IA_POOL_INVALIDO' };
    }

    const variantes = poolRecord[cat];

    // N1: Exactamente 4 variantes por categoría
    if (!Array.isArray(variantes) || variantes.length !== 4) {
      return { valido: false, codigo: 'IA_POOL_INVALIDO' };
    }

    // N2 y N3: Tipo string, longitud 20-250, higiene
    for (const v of variantes) {
      if (typeof v !== 'string') {
        return { valido: false, codigo: 'IA_POOL_INVALIDO' };
      }
      const vTrim = v.trim();
      if (vTrim.length < 20 || vTrim.length > 250) {
        return { valido: false, codigo: 'IA_POOL_INVALIDO' };
      }
      if (REGEX_HIGIENE.test(vTrim)) {
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
    return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
  }

  for (let i = 0; i < 9; i++) {
    const enc = preguntas[i];

    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    // E2: Números 4 a 12 consecutivos
    if (typeof enc.numero !== 'number' || !Number.isInteger(enc.numero) || enc.numero !== i + 4) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    // E1: Estructura de encuentro (V2, V3)
    if (
      typeof enc.tipo_encuentro !== 'string' ||
      !['normal', 'jefe'].includes(enc.tipo_encuentro)
    ) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (
      typeof enc.enemigo !== 'string' ||
      enc.enemigo.trim().length < 3 ||
      enc.enemigo.trim().length > 40
    ) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (
      typeof enc.pregunta !== 'string' ||
      enc.pregunta.trim().length < 10 ||
      enc.pregunta.trim().length > 400
    ) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    // V7: código debe ser null en categoría 'libre'
    if (categoria === 'libre' && enc.codigo !== null) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    // V8: Higiene en encuentro
    if (REGEX_HIGIENE.test(enc.enemigo) || REGEX_HIGIENE.test(enc.pregunta)) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    // Opciones (V5, V6, V8, V9)
    if (!Array.isArray(enc.opciones) || enc.opciones.length !== 4) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    let cantCalidad2 = 0;
    let cantCalidad0 = 0;
    const textosVistos = new Set<string>();

    for (const op of enc.opciones) {
      if (!op || typeof op !== 'object' || Array.isArray(op)) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (
        typeof op.texto !== 'string' ||
        op.texto.trim().length < 3 ||
        op.texto.trim().length > 200
      ) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (
        typeof op.calidad !== 'number' ||
        !Number.isInteger(op.calidad) ||
        ![0, 1, 2].includes(op.calidad)
      ) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (
        typeof op.explicacion !== 'string' ||
        op.explicacion.trim().length < 10 ||
        op.explicacion.trim().length > 300
      ) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (REGEX_HIGIENE.test(op.texto) || REGEX_HIGIENE.test(op.explicacion)) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (op.calidad === 2) cantCalidad2++;
      if (op.calidad === 0) cantCalidad0++;

      const textoNorm = normalizarTexto(op.texto);
      if (textosVistos.has(textoNorm)) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }
      textosVistos.add(textoNorm);
    }

    if (cantCalidad2 !== 1 || cantCalidad0 < 1) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
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
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
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
  requierePool = true
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

  // 1. Extraer y validar Quest
  const questData = data.quest ?? (data.titulo && data.encuentros ? data : null);
  if (!questData) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }

  const resQuest = validarQuestJson(JSON.stringify(questData), categoria);
  if (!resQuest.valido) {
    return { valido: false, codigo: resQuest.codigo };
  }

  // 2. Validar Pool Narrativo si es requerido
  let poolValido: PoolNarrativoIa | undefined;
  if (requierePool) {
    const resPool = validarPoolNarrativo(data.pool_narrativo);
    if (!resPool.valido) {
      return { valido: false, codigo: resPool.codigo };
    }
    poolValido = resPool.pool;
  }

  // 3. Validar Preguntas Extra
  const resPreguntas = validarPreguntasExtra(data.preguntas_extra, categoria);
  if (!resPreguntas.valido) {
    return { valido: false, codigo: resPreguntas.codigo };
  }

  return {
    valido: true,
    run: {
      quest: resQuest.quest,
      pool_narrativo: poolValido,
      preguntas_extra: resPreguntas.preguntas,
    },
  };
}
