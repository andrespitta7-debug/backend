// Supabase Edge Function: generar-encuentros-extra
// Endpoint: POST /functions/v1/generar-encuentros-extra
// Propósito: Generar encuentros dinámicamente para runs infinitas

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, jsonResponse } from '../_shared/response.ts';
import { obtenerProveedor } from '../_shared/ai/ai_factory.ts';
import { ENCUENTROS_EXTRA_SCHEMA } from '../_shared/run_schema.ts';
import { calcularVidaEnemigo } from '../_shared/vida_enemigo.ts';

const CATEGORIAS_VALIDAS = [
  'debug',
  'database',
  'algorithm',
  'network',
  'architecture',
  'cyber',
  'libre',
];

const DIFICULTADES_VALIDAS = ['facil', 'medio', 'dificil'];
const LETRAS = ['A', 'B', 'C', 'D'];

const SYSTEM_PROMPT = `Eres un diseñador de contenido educativo para SysQuest, un juego RPG por turnos para estudiantes universitarios de Ingeniería de Sistemas. Generas encuentros adicionales para una "run infinita".

REGLAS ESTRICTAS:
- Responde ÚNICAMENTE con un objeto JSON válido con la propiedad "encuentros". Sin texto antes ni después.
- Escribe todo el contenido en español.
- Genera exactamente 3 encuentros numerados secuencialmente a partir del número indicado por el usuario.
- Todos los encuentros tienen tipo_encuentro "normal".
- Cada encuentro tiene un enemigo con nombre temático y una pregunta clara.
- Cada encuentro tiene exactamente 4 opciones. Exactamente UNA opción con calidad 2 (correcta y óptima), al menos UNA con calidad 0 (incorrecta) y las restantes con calidad 1.
- Las opciones incorrectas deben ser plausibles.
- Todas las opciones de un encuentro deben tener longitud similar (dentro de un rango de ±30% respecto a la media del encuentro). NO hagas que la opción con calidad 2 sea significativamente más larga que las demás.
- Cada opción incluye una explicación breve.
- El contenido técnico debe ser correcto.
- No uses HTML ni formato markdown dentro de los textos.`;

function barajarArray<T>(array: T[]): T[] {
  const copia = [...array];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

function normalizarTexto(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const REGEX_HIGIENE = /<[a-zA-Z]+>|```|\*\*|__|##/;

// Adaptación de los validadores existentes
function validarEncuentrosGenerados(preguntas: any, categoria: string, ultimoNumero: number) {
  if (!Array.isArray(preguntas) || preguntas.length !== 3) {
    return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
  }

  for (let i = 0; i < 3; i++) {
    const enc = preguntas[i];
    if (!enc || typeof enc !== 'object' || Array.isArray(enc)) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (enc.numero !== ultimoNumero + i + 1) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (typeof enc.tipo_encuentro !== 'string' || enc.tipo_encuentro !== 'normal') {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (typeof enc.enemigo !== 'string' || enc.enemigo.trim().length < 3 || enc.enemigo.trim().length > 40) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (typeof enc.pregunta !== 'string' || enc.pregunta.trim().length < 10 || enc.pregunta.trim().length > 400) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (enc.codigo !== null && typeof enc.codigo !== 'string') {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (typeof enc.codigo === 'string' && enc.codigo.length > 600) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (categoria === 'libre' && enc.codigo !== null) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

    if (REGEX_HIGIENE.test(enc.enemigo) || REGEX_HIGIENE.test(enc.pregunta)) {
      return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
    }

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

      if (typeof op.texto !== 'string' || op.texto.trim().length < 3 || op.texto.trim().length > 200) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (typeof op.calidad !== 'number' || !Number.isInteger(op.calidad) || ![0, 1, 2].includes(op.calidad)) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }

      if (typeof op.explicacion !== 'string' || op.explicacion.trim().length < 10 || op.explicacion.trim().length > 300) {
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

    const opcionCorrecta = enc.opciones.find((op: any) => op.calidad === 2);
    if (opcionCorrecta) {
      const longitudesOtras = enc.opciones
        .filter((op: any) => op.calidad !== 2)
        .map((op: any) => op.texto.trim().length);
      const promedioOtras = longitudesOtras.reduce((a: number, b: number) => a + b, 0) / longitudesOtras.length;
      const longitudCorrecta = opcionCorrecta.texto.trim().length;
      if (promedioOtras > 0 && longitudCorrecta > promedioOtras * 2) {
        return { valido: false, codigo: 'IA_PREGUNTAS_INVALIDAS' };
      }
    }
  }

  return { valido: true, preguntas };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, codigo: 'METODO_NO_PERMITIDO' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return jsonResponse({ ok: false, codigo: 'NO_AUTORIZADO' }, 401);
  }

  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return jsonResponse({ ok: false, codigo: 'NO_AUTORIZADO' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return jsonResponse({ ok: false, codigo: 'ERROR_PERSISTENCIA' }, 500);
  }

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return jsonResponse({ ok: false, codigo: 'NO_AUTORIZADO' }, 401);
  }

  let body: Record<string, any>;
  try {
    body = await req.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
    }
  } catch (_err) {
    return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
  }

  const { id_quest, tema, categoria, dificultad, ultimo_numero } = body;

  if (typeof id_quest !== 'string') return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
  if (typeof tema !== 'string' || tema.trim().length < 3) return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
  if (typeof categoria !== 'string' || !CATEGORIAS_VALIDAS.includes(categoria)) return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
  if (typeof dificultad !== 'string' || !DIFICULTADES_VALIDAS.includes(dificultad)) return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);
  if (typeof ultimo_numero !== 'number' || !Number.isInteger(ultimo_numero)) return jsonResponse({ ok: false, codigo: 'INPUT_INVALIDO' }, 400);

  const proveedorIA = obtenerProveedor();

  const userPrompt = \`Genera 3 encuentros normales sobre el tema "\${tema}" y la categoria "\${categoria}". IMPORTANTE: Los números de los encuentros generados deben ser \${ultimo_numero + 1}, \${ultimo_numero + 2} y \${ultimo_numero + 3}.\`;

  let responseTexto = '';
  try {
    responseTexto = await proveedorIA.generarQuest({
      systemInstruction: SYSTEM_PROMPT,
      userPrompt,
      schema: ENCUENTROS_EXTRA_SCHEMA,
      timeoutMs: 15000,
    });
  } catch (error: any) {
    if (error.message?.includes('TIMEOUT')) {
      return jsonResponse({ ok: false, codigo: 'IA_TIMEOUT' }, 504);
    }
    return jsonResponse({ ok: false, codigo: 'IA_NO_DISPONIBLE' }, 502);
  }

  let jsonLimpio = responseTexto.trim();
  if (jsonLimpio.startsWith('\`\`\`')) {
    jsonLimpio = jsonLimpio.replace(/^\`\`\`(?:json)?\s*/i, '').replace(/\s*\`\`\`$/, '').trim();
  }

  let dataIA: any;
  try {
    dataIA = JSON.parse(jsonLimpio);
  } catch {
    return jsonResponse({ ok: false, codigo: 'IA_JSON_INVALIDO' }, 502);
  }

  const resVal = validarEncuentrosGenerados(dataIA.encuentros, categoria, ultimo_numero);
  if (!resVal.valido) {
    return jsonResponse({ ok: false, codigo: resVal.codigo }, 502);
  }

  // 4. Barajar las opciones y asignar letras A-D.
  // 5. Calcular vida_enemigo
  const incrementoVida = Math.floor(ultimo_numero / 10) * 0.2; // 20% más cada 10 niveles
  const multiplicadorMito = 1 + incrementoVida;

  const encuentrosProcesados = resVal.preguntas.map((enc: any) => {
    let vidaBase = calcularVidaEnemigo(dificultad, enc.tipo_encuentro);
    enc.vida_enemigo = Math.floor(vidaBase * multiplicadorMito);
    
    enc.opciones = barajarArray(enc.opciones);
    for (let j = 0; j < 4; j++) {
      enc.opciones[j].letra = LETRAS[j];
    }
    return enc;
  });

  // 6. Llamar a la RPC insertar_encuentros_extra
  const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc('insertar_encuentros_extra', {
    p_id_quest: id_quest,
    p_encuentros: encuentrosProcesados
  });

  if (rpcError) {
    console.error('Error insertando encuentros extra', rpcError);
    return jsonResponse({ ok: false, codigo: 'ERROR_PERSISTENCIA' }, 500);
  }

  // 7. Devolver 201 Created
  return jsonResponse({ ok: true, encuentros: rpcData }, 201);
});
