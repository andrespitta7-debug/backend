// Supabase Edge Function: finalizar-partida
// Endpoint: POST /functions/v1/finalizar-partida
// Propósito: Recibir el resultado de una partida, extraer el usuario del JWT y llamar
// a la función RPC finalizar_partida para persistir atómicamente la partida y actualizar el progreso.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, jsonResponse } from '../_shared/response.ts';

Deno.serve(async (req: Request) => {
  // 1. Preflight CORS
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  // 2. Método HTTP permitido: solo POST
  if (req.method !== 'POST') {
    return jsonResponse(
      { ok: false, codigo: 'METODO_NO_PERMITIDO' },
      405
    );
  }

  // 3. Autenticación: Validar JWT en cabecera Authorization
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
    return jsonResponse({ ok: false, codigo: 'ERROR_PERSISTENCIA' }, 500);
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

  // 5. Validar campos obligatorios
  const idQuestRaw = body.id_quest;
  if (typeof idQuestRaw !== 'string' || idQuestRaw.trim().length === 0) {
    return jsonResponse({
      ok: false,
      codigo: 'INPUT_INVALIDO',
      detalle: 'El campo id_quest es obligatorio.',
    }, 400);
  }
  const idQuest = idQuestRaw.trim();

  const estadoRaw = body.estado;
  if (estadoRaw !== 'ganada' && estadoRaw !== 'perdida') {
    return jsonResponse({
      ok: false,
      codigo: 'INPUT_INVALIDO',
      detalle: 'El campo estado debe ser "ganada" o "perdida".',
    }, 400);
  }
  const estado = estadoRaw;

  const enemigosRaw = body.enemigos_derrotados;
  if (typeof enemigosRaw !== 'number' || !Number.isInteger(enemigosRaw) || enemigosRaw < 0) {
    return jsonResponse({
      ok: false,
      codigo: 'INPUT_INVALIDO',
      detalle: 'enemigos_derrotados debe ser un entero >= 0.',
    }, 400);
  }
  const enemigosDerrotados = enemigosRaw;

  // 6. Consultar dificultad de la quest y total de encuentros
  const { data: questData, error: questError } = await supabaseAdmin
    .from('quest')
    .select('dificultad')
    .eq('id', idQuest)
    .single();

  if (questError || !questData) {
    return jsonResponse({
      ok: false,
      codigo: 'QUEST_NO_ENCONTRADA',
    }, 404);
  }

  const { count: totalEncuentros, error: countError } = await supabaseAdmin
    .from('encuentro')
    .select('*', { count: 'exact', head: true })
    .eq('id_quest', idQuest);

  if (countError || totalEncuentros === null) {
    return jsonResponse({
      ok: false,
      codigo: 'ERROR_PERSISTENCIA',
    }, 500);
  }

  // 7. Validar que enemigos_derrotados no exceda el total real
  if (enemigosDerrotados > totalEncuentros) {
    return jsonResponse({
      ok: false,
      codigo: 'INPUT_INVALIDO',
      detalle: `enemigos_derrotados (${enemigosDerrotados}) excede el total de encuentros de la quest (${totalEncuentros}).`,
    }, 400);
  }

  // 8. Calcular score y XP server-side con desglose
  const rachaRaw = typeof body.racha_maxima === 'number' && Number.isInteger(body.racha_maxima) && body.racha_maxima >= 0
    ? body.racha_maxima
    : 0;
  const maxRachaPermitida = (totalEncuentros ?? 1) * 5;
  const rachaMaxima = Math.min(rachaRaw, maxRachaPermitida);

  const rondasRaw = typeof body.rondas_temerarias === 'number' && Number.isInteger(body.rondas_temerarias) && body.rondas_temerarias >= 0
    ? body.rondas_temerarias
    : 0;
  const maxRondasPosibles = Math.max(1, Math.floor((totalEncuentros ?? 1) / 3));
  const rondasTemerarias = Math.min(rondasRaw, maxRondasPosibles);

  const multiplicadores: Record<string, number> = {
    'facil': 1.0,
    'medio': 1.5,
    'dificil': 2.0,
  };
  const mult = multiplicadores[questData.dificultad] ?? 1.0;
  const puntosEnemigos = Math.floor(enemigosDerrotados * 100 * mult);
  const bonusRacha = rachaMaxima >= 7 ? 150 : (rachaMaxima >= 5 ? 50 : 0);
  const bonusVictoria = estado === 'ganada' ? Math.floor(150 * mult) : 0;
  const bonusTemerario = Math.floor(rondasTemerarias * 200 * mult);
  const scoreCalculado = puntosEnemigos + bonusRacha + bonusVictoria + bonusTemerario;
  const xpCalculada = scoreCalculado === 0 ? 0 : Math.max(5, Math.min(1000, Math.floor(scoreCalculado / 10)));

  console.log('[finalizar-partida] Recalculo server-side:', {
    userId,
    idQuest,
    dificultad: questData.dificultad,
    enemigosDerrotados,
    rachaMaxima,
    rondasTemerarias,
    puntosEnemigos,
    bonusRacha,
    bonusVictoria,
    bonusTemerario,
    scoreCalculado,
    xpCalculada,
  });

  // 9. Construir p_partida con valores CALCULADOS (no del cliente)
  const idPartida = typeof body.id_partida === 'string' && body.id_partida.trim().length > 0
    ? body.id_partida.trim()
    : crypto.randomUUID();

  const pPartida = {
    id_partida: idPartida,
    id_usuario: userId,
    id_quest: idQuest,
    estado: estado,
    encuentro_actual: typeof body.encuentro_actual === 'number' ? Math.floor(body.encuentro_actual) : 0,
    score: scoreCalculado,       // ← calculado por el servidor
    xp_obtenida: xpCalculada,    // ← calculado por el servidor
    tiempo_segundos: typeof body.tiempo_segundos === 'number' ? Math.floor(body.tiempo_segundos) : 0,
    vida_jugador_actual: typeof body.vida_jugador_actual === 'number'
      ? Math.floor(body.vida_jugador_actual)
      : (estado === 'ganada' ? 100 : 0),
    vida_enemigo_actual: typeof body.vida_enemigo_actual === 'number'
      ? Math.floor(body.vida_enemigo_actual)
      : null,
  };

  // 10. Llamar a la función RPC finalizar_partida
  const { error: rpcError } = await supabaseAdmin.rpc('finalizar_partida', {
    p_partida: pPartida,
  });

  if (rpcError) {
    console.error('Error al ejecutar RPC finalizar_partida:', {
      codigo: rpcError.code,
      mensaje: rpcError.message,
      detalles: rpcError.details,
      userId,
      idQuest,
    });
    return jsonResponse(
      {
        ok: false,
        codigo: 'ERROR_PERSISTENCIA',
      },
      500
    );
  }

  // 11. Éxito con resumen de la partida
  return jsonResponse({
    ok: true,
    resumen: {
      score_total: scoreCalculado,
      puntos_enemigos: puntosEnemigos,
      bonus_racha: bonusRacha,
      bonus_victoria: bonusVictoria,
      bonus_temerario: bonusTemerario,
      rondas_temerarias: rondasTemerarias,
      xp_obtenida: xpCalculada,
      enemigos_derrotados: enemigosDerrotados,
      racha_maxima: rachaMaxima,
      dificultad: questData.dificultad,
    },
  }, 200);
});
