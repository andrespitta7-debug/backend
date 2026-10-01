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
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'El campo id_quest es obligatorio y debe ser una cadena válida.',
      },
      400
    );
  }
  const idQuest = idQuestRaw.trim();

  const estadoRaw = body.estado;
  if (estadoRaw !== 'ganada' && estadoRaw !== 'perdida') {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'El campo estado debe ser "ganada" o "perdida".',
      },
      400
    );
  }
  const estado = estadoRaw;

  const xpRaw = body.xp_obtenida;
  if (typeof xpRaw !== 'number' || !Number.isInteger(xpRaw) || xpRaw < 0) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'INPUT_INVALIDO',
        detalle: 'El campo xp_obtenida debe ser un entero mayor o igual a 0.',
      },
      400
    );
  }
  const xpObtenida = xpRaw;

  // 6. Construir objeto p_partida para la RPC
  const idPartida = typeof body.id_partida === 'string' && body.id_partida.trim().length > 0
    ? body.id_partida.trim()
    : crypto.randomUUID();

  const pPartida = {
    id_partida: idPartida,
    id_usuario: userId,
    id_quest: idQuest,
    estado: estado,
    encuentro_actual: typeof body.encuentro_actual === 'number' ? Math.floor(body.encuentro_actual) : 0,
    score: typeof body.score === 'number' ? Math.floor(body.score) : 0,
    xp_obtenida: xpObtenida,
    tiempo_segundos: typeof body.tiempo_segundos === 'number' ? Math.floor(body.tiempo_segundos) : 0,
    vida_jugador_actual: typeof body.vida_jugador_actual === 'number'
      ? Math.floor(body.vida_jugador_actual)
      : (estado === 'ganada' ? 100 : 0),
    vida_enemigo_actual: typeof body.vida_enemigo_actual === 'number'
      ? Math.floor(body.vida_enemigo_actual)
      : null,
  };

  // 7. Llamar a la función RPC finalizar_partida
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

  // 8. Éxito
  return jsonResponse({ ok: true }, 200);
});
