// Supabase Edge Function: obtener-usuario-actual
// Endpoint: POST /functions/v1/obtener-usuario-actual
// Propósito: Consultar el perfil del usuario autenticado a partir de su JWT.

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

  // 5. Consultar la tabla usuario en Postgres
  const { data: usuario, error: errorUsuario } = await supabaseAdmin
    .from('usuario')
    .select('id, nombre_usuario, nombre, apellido')
    .eq('id', userId)
    .single();

  if (errorUsuario || !usuario) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'USUARIO_NO_ENCONTRADO',
      },
      404
    );
  }

  // 6. Éxito: devolver perfil del usuario
  return jsonResponse(
    {
      ok: true,
      usuario: {
        id: usuario.id,
        email: userData.user.email ?? '',
        nombre_usuario: usuario.nombre_usuario,
        nombre: usuario.nombre ?? '',
        apellido: usuario.apellido ?? '',
      },
    },
    200
  );
});
