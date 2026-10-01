// SysQuest — Validador de salida de IA según contrato V0–V8
// docs/SysQuest_Contrato_Quest_IA.md sección 5

export interface OpcionIa {
  texto: string;
  calidad: 0 | 1 | 2;
  explicacion: string;
}

export interface EncuentroIa {
  numero: number;
  tipo_encuentro: 'normal' | 'jefe';
  enemigo: string;
  pregunta: string;
  codigo: string | null;
  opciones: OpcionIa[];
}

export interface QuestIa {
  titulo: string;
  descripcion: string;
  encuentros: EncuentroIa[];
}

export type ResultadoValidacionQuest =
  | { valido: true; quest: QuestIa }
  | { valido: false; codigo: string };

function normalizarTexto(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const REGEX_HIGIENE = /<[a-zA-Z]+>|```|\*\*|__|##/;

export function validarQuestJson(
  texto: string,
  categoria: string
): ResultadoValidacionQuest {
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

  // V2: Estructura y tipos requeridos
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }
  if (typeof data.titulo !== 'string' || data.titulo.trim() === '') {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }
  if (typeof data.descripcion !== 'string' || data.descripcion.trim() === '') {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }
  if (!Array.isArray(data.encuentros)) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }

  for (const enc of data.encuentros) {
    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (typeof enc.numero !== 'number' || !Number.isInteger(enc.numero)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (
      typeof enc.tipo_encuentro !== 'string' ||
      !['normal', 'jefe'].includes(enc.tipo_encuentro)
    ) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (typeof enc.enemigo !== 'string' || enc.enemigo.trim() === '') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (typeof enc.pregunta !== 'string' || enc.pregunta.trim() === '') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (!Array.isArray(enc.opciones)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    for (const op of enc.opciones) {
      if (!op || typeof op !== 'object' || Array.isArray(op)) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
      if (typeof op.texto !== 'string' || op.texto.trim() === '') {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
      if (
        typeof op.calidad !== 'number' ||
        !Number.isInteger(op.calidad) ||
        ![0, 1, 2].includes(op.calidad)
      ) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
      if (typeof op.explicacion !== 'string' || op.explicacion.trim() === '') {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
    }
  }

  // V3: Longitudes dentro de los rangos de la sección 4
  if (data.titulo.length < 5 || data.titulo.length > 80) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }
  if (data.descripcion.length < 10 || data.descripcion.length > 300) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
  }

  for (const enc of data.encuentros) {
    if (enc.enemigo.length < 3 || enc.enemigo.length > 40) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (enc.pregunta.length < 10 || enc.pregunta.length > 400) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
    }
    for (const op of enc.opciones) {
      if (op.texto.length < 3 || op.texto.length > 200) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
      if (op.explicacion.length < 10 || op.explicacion.length > 300) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO' };
      }
    }
  }

  // V4: Exactamente 3 encuentros; números 1, 2, 3 consecutivos sin huecos ni repetidos; jefe solo en el 3
  if (data.encuentros.length !== 3) {
    return { valido: false, codigo: 'IA_ENCUENTROS_INVALIDOS' };
  }
  for (let i = 0; i < 3; i++) {
    const enc = data.encuentros[i];
    if (enc.numero !== i + 1) {
      return { valido: false, codigo: 'IA_ENCUENTROS_INVALIDOS' };
    }
    if (i < 2 && enc.tipo_encuentro !== 'normal') {
      return { valido: false, codigo: 'IA_ENCUENTROS_INVALIDOS' };
    }
    if (i === 2 && enc.tipo_encuentro !== 'jefe') {
      return { valido: false, codigo: 'IA_ENCUENTROS_INVALIDOS' };
    }
  }

  // V5: Exactamente 4 opciones por encuentro; calidad ∈ {0,1,2}; exactamente una con calidad = 2; al menos una con calidad = 0
  for (const enc of data.encuentros) {
    if (enc.opciones.length !== 4) {
      return { valido: false, codigo: 'IA_OPCIONES_INVALIDAS' };
    }
    let cantCalidad2 = 0;
    let cantCalidad0 = 0;
    for (const op of enc.opciones) {
      if (op.calidad === 2) cantCalidad2++;
      if (op.calidad === 0) cantCalidad0++;
    }
    if (cantCalidad2 !== 1 || cantCalidad0 < 1) {
      return { valido: false, codigo: 'IA_OPCIONES_INVALIDAS' };
    }
  }

  // V6: Textos de opciones distintos entre sí dentro de cada encuentro (normalizados)
  for (const enc of data.encuentros) {
    const textosVistos = new Set<string>();
    for (const op of enc.opciones) {
      const normalizado = normalizarTexto(op.texto);
      if (textosVistos.has(normalizado)) {
        return { valido: false, codigo: 'IA_OPCIONES_INVALIDAS' };
      }
      textosVistos.add(normalizado);
    }
  }

  // V7: codigo debe ser null cuando categoria === 'libre'
  if (categoria === 'libre') {
    for (const enc of data.encuentros) {
      if (enc.codigo !== null) {
        return { valido: false, codigo: 'IA_CODIGO_NO_PERMITIDO' };
      }
    }
  }

  // V8: Higiene (sin HTML ni markdown en campos de texto: titulo, descripcion, enemigo, pregunta, texto, explicacion)
  if (
    REGEX_HIGIENE.test(data.titulo) ||
    REGEX_HIGIENE.test(data.descripcion)
  ) {
    return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO' };
  }

  for (const enc of data.encuentros) {
    if (
      REGEX_HIGIENE.test(enc.enemigo) ||
      REGEX_HIGIENE.test(enc.pregunta)
    ) {
      return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO' };
    }
    for (const op of enc.opciones) {
      if (
        REGEX_HIGIENE.test(op.texto) ||
        REGEX_HIGIENE.test(op.explicacion)
      ) {
        return { valido: false, codigo: 'IA_CONTENIDO_INVALIDO' };
      }
    }
  }

  return { valido: true, quest: data as QuestIa };
}
