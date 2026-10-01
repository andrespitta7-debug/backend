// Supabase Edge Function: obtener-progreso
// Endpoint: POST /functions/v1/obtener-progreso
// Propósito: Consultar el progreso acumulado del usuario autenticado llamando a la RPC obtener_progreso_usuario.

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

  // 4. Parsear body (opcional, no requiere parámetros específicos)
  try {
    const rawText = await req.text();
    if (rawText && rawText.trim().length > 0) {
      const parsed = JSON.parse(rawText);
      if (typeof parsed !== 'object' || Array.isArray(parsed) || parsed === null) {
        return jsonResponse(
          {
            ok: false,
            codigo: 'INPUT_INVALIDO',
            detalle: 'El cuerpo debe ser un objeto JSON válido.',
          },
          400
        );
      }
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

  // 5. Llamar a la función RPC obtener_progreso_usuario
  const { data: progresoData, error: rpcError } = await supabaseAdmin.rpc(
    'obtener_progreso_usuario',
    {
      p_id_usuario: userId,
    }
  );

  // 6. Manejo de errores de la RPC
  if (rpcError) {
    const errorMsg = rpcError.message ?? '';
    const errorDetails = rpcError.details ?? '';
    const esNoEncontrado =
      errorMsg.includes('Progreso no encontrado') ||
      errorDetails.includes('Progreso no encontrado');

    if (esNoEncontrado) {
      return jsonResponse(
        {
          ok: false,
          codigo: 'PROGRESO_NO_ENCONTRADO',
        },
        404
      );
    }

    console.error('Error al ejecutar RPC obtener_progreso_usuario:', {
      codigo: rpcError.code,
      mensaje: rpcError.message,
      detalles: rpcError.details,
      userId,
    });

    return jsonResponse(
      {
        ok: false,
        codigo: 'ERROR_INTERNO',
      },
      500
    );
  }

  // Si progresoData es null por alguna razón inesperada
  if (!progresoData) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'PROGRESO_NO_ENCONTRADO',
      },
      404
    );
  }

  // 7. Éxito: devolver progreso
  return jsonResponse(
    {
      ok: true,
      progreso: progresoData,
    },
    200
  );
});

// === GUÍA DE DEPLOY Y PRUEBAS ===
//
// Deploy:
//   supabase functions deploy obtener-progreso
//
// curl de prueba:
//   curl -i --location --request POST \
//     'https://jctulgfdweeurqbmugot.supabase.co/functions/v1/obtener-progreso' \
//     --header 'Content-Type: application/json' \
//     --header 'Authorization: Bearer <JWT>' \
//     --header 'apikey: <ANON_KEY>' \
//     --data '{}'
