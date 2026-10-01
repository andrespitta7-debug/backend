// Supabase Edge Function: generar-quest-completa
// Endpoint: POST /functions/v1/generar-quest-completa
// Propósito: Generar en una sola llamada a IA (o reutilizando caché narrativo):
// 1. La quest principal (3 encuentros + 12 opciones)
// 2. El pool narrativo inicial (8 categorías × 4 variantes = 32 variantes)
// 3. Las preguntas extra (9 preguntas para runs extendidas, números 4 a 12)
// Persistir todo atómicamente creando la quest, encuentros y partida inicial.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, jsonResponse } from '../_shared/response.ts';
import { obtenerProveedor } from '../_shared/ai/ai_factory.ts';
import { MEGA_JSON_SCHEMA, RUN_SIN_POOL_SCHEMA } from '../_shared/run_schema.ts';
import { validarRunCompleta } from '../_shared/run_validator.ts';
import {
  SYSTEM_PROMPT_NARRATIVA,
  construirUserPromptRun,
} from '../_shared/narrativa_prompts.ts';
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

function barajarArray<T>(array: T[]): T[] {
  const copia = [...array];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

Deno.serve(async (req: Request) => {
  // 1. Manejo de preflight CORS (OPTIONS)
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  // 2. Validación de método HTTP: solo POST
  if (req.method !== 'POST') {
    return jsonResponse(
      { ok: false, codigo: 'METODO_NO_PERMITIDO' },
      405
    );
  }

  // 3. Autenticación: Validar JWT del usuario
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
    console.error('Faltan variables de entorno SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.');
    return jsonResponse(
      { ok: false, codigo: 'ERROR_PERSISTENCIA', usar_fallback: false },
      500
    );
  }

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return jsonResponse({ ok: false, codigo: 'NO_AUTORIZADO' }, 401);
  }

  const userId = userData.user.id;

  // 4. Parsear body JSON
  let body: Record<string, unknown>;
  try {
    body = await req.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return jsonResponse(
        {
          ok: false,
          codigo: 'INPUT_INVALIDO',
          detalle: 'El cuerpo debe ser un objeto JSON válido.',
        },
        400
      );
    }
  } catch (_err) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'El cuerpo de la petición no es un JSON válido.',
      },
      400
    );
  }

  // 5. Validar campos requeridos
  const temaRaw = body.tema;
  if (typeof temaRaw !== 'string') {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'tema debe ser un texto.',
      },
      400
    );
  }

  // deno-lint-ignore no-control-regex
  const REGEX_CONTROL = new RegExp('[\\x00-\\x1F\\x7F]', 'g');
  const temaLimpio = temaRaw
    .replace(REGEX_CONTROL, '')
    .replace(/<<</g, '')
    .replace(/>>>/g, '')
    .trim();

  if (temaLimpio.length < 3 || temaLimpio.length > 100) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'tema debe tener entre 3 y 100 caracteres.',
      },
      400
    );
  }

  if (
    typeof body.categoria !== 'string' ||
    !CATEGORIAS_VALIDAS.includes(body.categoria)
  ) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: `categoria debe ser una de: ${CATEGORIAS_VALIDAS.join(', ')}.`,
      },
      400
    );
  }

  if (
    typeof body.dificultad !== 'string' ||
    !DIFICULTADES_VALIDAS.includes(body.dificultad)
  ) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: `dificultad debe ser una de: ${DIFICULTADES_VALIDAS.join(', ')}.`,
      },
      400
    );
  }

  const categoria = body.categoria;
  const dificultad = body.dificultad;

  // 6. Consultar si existe pool narrativo en caché
  let poolEnMemoria: unknown = null;
  let fuentePool: 'AI' | 'CACHE' = 'AI';

  const { data: cacheData, error: cacheErr } = await supabaseAdmin
    .from('pool_narrativo_cache')
    .select('id, pool, usos')
    .eq('tema', temaLimpio)
    .eq('categoria', categoria)
    .eq('dificultad', dificultad)
    .maybeSingle();

  if (!cacheErr && cacheData?.pool) {
    poolEnMemoria = cacheData.pool;
    fuentePool = 'CACHE';
    // Incrementar contador de usos de la caché en segundo plano
    supabaseAdmin
      .from('pool_narrativo_cache')
      .update({ usos: (cacheData.usos ?? 0) + 1 })
      .eq('id', cacheData.id)
      .then();
  }

  const conPool = poolEnMemoria === null;
  const schema = conPool ? MEGA_JSON_SCHEMA : RUN_SIN_POOL_SCHEMA;
  const userPrompt = construirUserPromptRun(temaLimpio, categoria, dificultad, conPool);

  // 7. Llamar al proveedor de IA con medición de latencia
  const proveedor = obtenerProveedor();
  const inicioMs = Date.now();
  const resultadoIa = await proveedor.generarQuest({
    systemInstruction: SYSTEM_PROMPT_NARRATIVA,
    userPrompt,
    schema,
  });
  const latenciaMs = Date.now() - inicioMs;

  function registrarFalloIa(codigo: string) {
    console.error(
      JSON.stringify({
        evento: 'ia_fallo_run_completa',
        codigo,
        proveedor: resultadoIa.proveedor,
        tema: temaLimpio,
        categoria,
        dificultad,
        user_id: userId,
        latencia_ms: latenciaMs,
        timestamp: new Date().toISOString(),
      })
    );
  }

  // 8. Manejo de errores de IA
  if (!resultadoIa.ok) {
    registrarFalloIa(resultadoIa.codigo);
    if (resultadoIa.codigo === 'CONFIG_FALTANTE') {
      return jsonResponse(
        { ok: false, codigo: 'CONFIG_FALTANTE', usar_fallback: true },
        500
      );
    }
    if (resultadoIa.codigo === 'IA_TIMEOUT') {
      return jsonResponse(
        { ok: false, codigo: 'IA_TIMEOUT', usar_fallback: true },
        504
      );
    }
    return jsonResponse(
      { ok: false, codigo: resultadoIa.codigo, usar_fallback: true },
      502
    );
  }

  // 9. Validar respuesta (V0-V9 para quest, N0-N3 para pool narrativo si aplica, E0-E2 para preguntas extra)
  const resultadoValidacion = validarRunCompleta(
    resultadoIa.texto,
    categoria,
    conPool
  );

  if (!resultadoValidacion.valido) {
    registrarFalloIa(resultadoValidacion.codigo);
    return jsonResponse(
      { ok: false, codigo: resultadoValidacion.codigo, usar_fallback: true },
      502
    );
  }

  const runIa = resultadoValidacion.run;
  const questIa = runIa.quest;
  const poolFinal = conPool ? runIa.pool_narrativo : poolEnMemoria;
  const preguntasExtraIa = runIa.preguntas_extra;

  // 10 y 11. Barajar opciones (Fisher-Yates), asignar letras y calcular vida_enemigo
  const encuentrosQuestParaRpc = questIa.encuentros.map((encuentro) => {
    const vidaEnemigo = calcularVidaEnemigo(dificultad, encuentro.tipo_encuentro);
    const opcionesBarajadas = barajarArray(encuentro.opciones).map((op, idx) => ({
      letra: LETRAS[idx],
      texto: op.texto,
      calidad: op.calidad,
      explicacion: op.explicacion,
    }));

    return {
      numero: encuentro.numero,
      tipo_encuentro: encuentro.tipo_encuentro,
      dificultad,
      vida_enemigo: vidaEnemigo,
      enemigo: encuentro.enemigo,
      pregunta: encuentro.pregunta,
      codigo: encuentro.codigo ?? null,
      opciones: opcionesBarajadas,
    };
  });

  const preguntasExtraParaRpc = preguntasExtraIa.map((encuentro) => {
    const vidaEnemigo = calcularVidaEnemigo(dificultad, encuentro.tipo_encuentro);
    const opcionesBarajadas = barajarArray(encuentro.opciones).map((op, idx) => ({
      letra: LETRAS[idx],
      texto: op.texto,
      calidad: op.calidad,
      explicacion: op.explicacion,
    }));

    return {
      numero: encuentro.numero,
      tipo_encuentro: encuentro.tipo_encuentro,
      dificultad,
      vida_enemigo: vidaEnemigo,
      enemigo: encuentro.enemigo,
      pregunta: encuentro.pregunta,
      codigo: encuentro.codigo ?? null,
      opciones: opcionesBarajadas,
    };
  });

  // 12. Generar semilla aleatoria para reproducibilidad
  const semilla = Math.floor(Math.random() * 2147483647);

  // 13. Invocar RPC transaccional crear_run_completa
  const questParaRpc = {
    titulo: questIa.titulo,
    tema: temaLimpio,
    categoria,
    dificultad,
    descripcion: questIa.descripcion,
    fuente_generacion: 'AI',
    encuentros: encuentrosQuestParaRpc,
  };

  const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc(
    'crear_run_completa',
    {
      p_quest: questParaRpc,
      p_pool_narrativo: poolFinal,
      p_preguntas_extra: preguntasExtraParaRpc,
      p_semilla: semilla,
      p_id_usuario: userId,
    }
  );

  if (rpcError || !rpcData?.id_quest || !rpcData?.id_partida) {
    console.error(
      'Error al invocar RPC crear_run_completa:',
      rpcError?.message ?? 'IDs nulos devueltos'
    );
    return jsonResponse(
      { ok: false, codigo: 'ERROR_PERSISTENCIA', usar_fallback: false },
      500
    );
  }

  const idQuest = rpcData.id_quest as string;
  const idPartida = rpcData.id_partida as string;

  // 14. Guardar en caché si el pool fue generado con IA
  if (conPool && poolFinal) {
    supabaseAdmin
      .from('pool_narrativo_cache')
      .upsert(
        {
          tema: temaLimpio,
          categoria,
          dificultad,
          pool: poolFinal,
          usos: 1,
        },
        { onConflict: 'tema,categoria,dificultad' }
      )
      .then();
  }

  // 15. Consultar los UUIDs asignados en base de datos para encuentros y opciones
  const { data: encuentrosDb } = await supabaseAdmin
    .from('encuentro')
    .select(`
      id,
      numero,
      opcion_encuentro (
        id,
        letra
      )
    `)
    .eq('id_quest', idQuest);

  const encuentroIdMap = new Map<number, string>();
  const opcionIdMap = new Map<string, string>();

  if (encuentrosDb && Array.isArray(encuentrosDb)) {
    for (const enc of encuentrosDb) {
      encuentroIdMap.set(enc.numero, enc.id);
      if (enc.opcion_encuentro && Array.isArray(enc.opcion_encuentro)) {
        for (const op of enc.opcion_encuentro) {
          opcionIdMap.set(`${enc.numero}_${op.letra}`, op.id);
        }
      }
    }
  }

  const questRespuesta = {
    id: idQuest,
    titulo: questParaRpc.titulo,
    tema: questParaRpc.tema,
    categoria: questParaRpc.categoria,
    dificultad: questParaRpc.dificultad,
    descripcion: questParaRpc.descripcion,
    fuente_generacion: questParaRpc.fuente_generacion,
    version: 1,
    encuentros: encuentrosQuestParaRpc.map((enc) => ({
      id: encuentroIdMap.get(enc.numero) ?? null,
      numero: enc.numero,
      tipo_encuentro: enc.tipo_encuentro,
      dificultad: enc.dificultad,
      vida_enemigo: enc.vida_enemigo,
      enemigo: enc.enemigo,
      pregunta: enc.pregunta,
      codigo: enc.codigo,
      opciones: enc.opciones.map((op) => ({
        id: opcionIdMap.get(`${enc.numero}_${op.letra}`) ?? null,
        letra: op.letra,
        texto: op.texto,
        calidad: op.calidad,
        explicacion: op.explicacion,
      })),
    })),
  };

  const preguntasExtraRespuesta = preguntasExtraParaRpc.map((enc) => ({
    id: encuentroIdMap.get(enc.numero) ?? null,
    numero: enc.numero,
    tipo_encuentro: enc.tipo_encuentro,
    dificultad: enc.dificultad,
    vida_enemigo: enc.vida_enemigo,
    enemigo: enc.enemigo,
    pregunta: enc.pregunta,
    codigo: enc.codigo,
    opciones: enc.opciones.map((op) => ({
      id: opcionIdMap.get(`${enc.numero}_${op.letra}`) ?? null,
      letra: op.letra,
      texto: op.texto,
      calidad: op.calidad,
      explicacion: op.explicacion,
    })),
  }));

  return jsonResponse(
    {
      ok: true,
      fuente: fuentePool,
      proveedor_ia: fuentePool === 'CACHE' ? 'cache' : resultadoIa.proveedor,
      id_partida: idPartida,
      semilla,
      quest: questRespuesta,
      pool_narrativo: poolFinal,
      preguntas_extra: preguntasExtraRespuesta,
    },
    201
  );
});
