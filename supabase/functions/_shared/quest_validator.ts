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
  vida_enemigo?: number;
  concepto?: string;
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
  | { valido: false; codigo: string; detalle?: string };

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
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'data no es un objeto' };
  }
  if (typeof data.titulo !== 'string' || data.titulo.trim() === '') {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'titulo faltante o vacio' };
  }
  if (typeof data.descripcion !== 'string' || data.descripcion.trim() === '') {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'descripcion faltante o vacia' };
  }
  if (!Array.isArray(data.encuentros)) {
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: 'encuentros no es un array' };
  }

  for (let i = 0; i < data.encuentros.length; i++) {
    const enc = data.encuentros[i];
    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} no es un objeto` };
    }
    if (typeof enc.numero !== 'number' || !Number.isInteger(enc.numero)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} numero invalido` };
    }
    if (
      typeof enc.tipo_encuentro !== 'string' ||
      !['normal', 'jefe'].includes(enc.tipo_encuentro)
    ) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} tipo_encuentro invalido` };
    }
    if (typeof enc.enemigo !== 'string' || enc.enemigo.trim() === '') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} enemigo faltante o vacio` };
    }
    if (typeof enc.pregunta !== 'string' || enc.pregunta.trim() === '') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} pregunta faltante o vacia` };
    }
    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} codigo invalido` };
    }
    if (!Array.isArray(enc.opciones)) {
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} opciones no es un array` };
    }
    for (let j = 0; j < enc.opciones.length; j++) {
      const op = enc.opciones[j];
      if (!op || typeof op !== 'object' || Array.isArray(op)) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} opcion ${j} no es un objeto` };
      }
      if (typeof op.texto !== 'string' || op.texto.trim() === '') {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} opcion ${j} texto vacio` };
      }
      if (
        typeof op.calidad !== 'number' ||
        !Number.isInteger(op.calidad) ||
        ![0, 1, 2].includes(op.calidad)
      ) {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} opcion ${j} calidad invalida (${op.calidad})` };
      }
      if (typeof op.explicacion !== 'string' || op.explicacion.trim() === '') {
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `encuentro ${i} opcion ${j} explicacion vacia` };
      }
    }
  }

  // V3: Longitudes dentro de los rangos de la sección 4
  if (data.titulo.length < 5 || data.titulo.length > 80) {
    console.error('[validarQuestJson] titulo fuera de rango (5-80):', data.titulo.length, data.titulo);
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `titulo longitud ${data.titulo.length} fuera de rango 5-80` };
  }
  if (data.descripcion.length < 10 || data.descripcion.length > 300) {
    console.error('[validarQuestJson] descripcion fuera de rango (10-300):', data.descripcion.length, data.descripcion);
    return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `descripcion longitud ${data.descripcion.length} fuera de rango 10-300` };
  }

  for (const enc of data.encuentros) {
    if (enc.enemigo.length < 3 || enc.enemigo.length > 40) {
      console.error('[validarQuestJson] enemigo fuera de rango (3-40):', enc.enemigo?.length, enc.enemigo);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `enemigo longitud ${enc.enemigo?.length} fuera de rango 3-40` };
    }
    if (enc.pregunta.length < 10 || enc.pregunta.length > 400) {
      console.error('[validarQuestJson] pregunta fuera de rango (10-400):', enc.pregunta?.length, enc.pregunta);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `pregunta longitud ${enc.pregunta?.length} fuera de rango 10-400` };
    }
    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      console.error('[validarQuestJson] codigo fuera de rango (>600):', enc.codigo.length);
      return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `codigo longitud ${enc.codigo.length} > 600` };
    }
    for (const op of enc.opciones) {
      if (op.texto.length < 3 || op.texto.length > 200) {
        console.error('[validarQuestJson] opcion texto fuera de rango (3-200):', op.texto?.length, op.texto);
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `opcion texto longitud ${op.texto?.length} fuera de rango 3-200` };
      }
      if (op.explicacion.length < 10 || op.explicacion.length > 300) {
        console.error('[validarQuestJson] opcion explicacion fuera de rango (10-300):', op.explicacion?.length, op.explicacion);
        return { valido: false, codigo: 'IA_ESQUEMA_INVALIDO', detalle: `opcion explicacion longitud ${op.explicacion?.length} fuera de rango 10-300` };
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

  // V9 añade validación de balance de longitudes. Se considera fallo
  // de IA (el prompt no se respetó) y activa fallback.
  // La opción con calidad 2 no debe ser más del doble de larga que
  // el promedio de las otras 3 opciones.
  for (const enc of data.encuentros) {
    const longitudes = enc.opciones.map(
      (op: { texto: string }) => op.texto.trim().length
    );
    const opcionCorrecta = enc.opciones.find(
      (op: { calidad: number }) => op.calidad === 2
    );
    if (!opcionCorrecta) {
      // V5 ya garantiza que existe. Si no existe, es error de otra
      // validación anterior y no llegamos aquí.
      continue;
    }
    const longitudesOtras = enc.opciones
      .filter((op: { calidad: number }) => op.calidad !== 2)
      .map((op: { texto: string }) => op.texto.trim().length);
    const promedioOtras =
      longitudesOtras.reduce((a: number, b: number) => a + b, 0) /
      longitudesOtras.length;
    const longitudCorrecta = opcionCorrecta.texto.trim().length;
    if (promedioOtras > 0 && longitudCorrecta > promedioOtras * 2) {
      return { valido: false, codigo: 'IA_OPCIONES_DESBALANCEADAS' };
    }
  }

  return { valido: true, quest: data as QuestIa };
}
