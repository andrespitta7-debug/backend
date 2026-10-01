// Supabase Edge Function: obtener-quest-completa
// Endpoint: POST /functions/v1/obtener-quest-completa
// Propósito: Consultar una quest completa con sus encuentros y opciones llamando a la RPC obtener_quest_completa.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, jsonResponse } from '../_shared/response.ts';

Deno.serve(async (req: Request) => {
  // 1. Manejo de preflight CORS
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
    return jsonResponse({ ok: false, codigo: 'ERROR_INTERNO' }, 500);
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

  // 5. Validar id_quest
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

  // 6. Llamar a la función RPC obtener_quest_completa
  const { data: questData, error: rpcError } = await supabaseAdmin.rpc(
    'obtener_quest_completa',
    {
      p_id_quest: idQuest,
    }
  );

  // 7. Manejo de errores de la RPC
  if (rpcError) {
    const errorMsg = rpcError.message ?? '';
    const errorDetails = rpcError.details ?? '';
    const esNoEncontrada =
      errorMsg.includes('Quest no encontrada') ||
      errorDetails.includes('Quest no encontrada');

    if (esNoEncontrada) {
      return jsonResponse(
        {
          ok: false,
          codigo: 'QUEST_NO_ENCONTRADA',
        },
        404
      );
    }

    console.error('Error al ejecutar RPC obtener_quest_completa:', {
      codigo: rpcError.code,
      mensaje: rpcError.message,
      detalles: rpcError.details,
      userId,
      idQuest,
    });

    return jsonResponse(
      {
        ok: false,
        codigo: 'ERROR_INTERNO',
      },
      500
    );
  }

  // Si questData es null por alguna razón inesperada
  if (!questData) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'QUEST_NO_ENCONTRADA',
      },
      404
    );
  }

  // 8. Éxito: devolver quest completa
  return jsonResponse(
    {
      ok: true,
      quest: questData,
    },
    200
  );
});

// === GUÍA DE DEPLOY Y PRUEBAS ===
//
// Deploy:
//   supabase functions deploy obtener-quest-completa
//
// curl de prueba:
//   curl -i --location --request POST \
//     'https://jctulgfdweeurqbmugot.supabase.co/functions/v1/obtener-quest-completa' \
//     --header 'Content-Type: application/json' \
//     --header 'Authorization: Bearer <JWT>' \
//     --header 'apikey: <ANON_KEY>' \
//     --data '{"id_quest": "00000000-0000-0000-0000-000000000001"}'
