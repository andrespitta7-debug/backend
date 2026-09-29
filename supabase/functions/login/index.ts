// Supabase Edge Function: login
// Endpoint: POST /functions/v1/login
// Propósito: Autenticar usuarios existentes y retornar JWT + datos de perfil y progreso.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, errorResponse, jsonResponse } from '../_shared/response.ts';

Deno.serve(async (req: Request) => {
  // 1. Manejo de preflight CORS (OPTIONS)
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  // 1. Validación de método HTTP: solo POST permitido
  if (req.method !== 'POST') {
    return errorResponse('Método no permitido.', 405);
  }

  // 2. Parseo seguro del cuerpo JSON
  let body: Record<string, unknown>;
  try {
    body = await req.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return errorResponse('Cuerpo inválido.', 400);
    }
  } catch (_err) {
    return errorResponse('Cuerpo inválido.', 400);
  }

  // 3. Validar que email y password no estén vacíos
  const emailRaw = body.email;
  const passwordRaw = body.password;

  if (
    typeof emailRaw !== 'string' ||
    typeof passwordRaw !== 'string' ||
    emailRaw.trim() === '' ||
    passwordRaw === ''
  ) {
    return errorResponse('El correo y la contraseña son obligatorios.', 400);
  }

  // 4. Normalizar email (trim + lowercase)
  const email = emailRaw.trim().toLowerCase();
  const password = passwordRaw;

  // 5. Crear cliente anon de Supabase (NO service_role para login)
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('Faltan variables de entorno SUPABASE_URL o SUPABASE_ANON_KEY.');
    return errorResponse('No se pudo completar la solicitud, intenta de nuevo.', 500);
  }

  const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // 6. Iniciar sesión mediante supabaseAnon
  const { data: authData, error: authError } = await supabaseAnon.auth.signInWithPassword({
    email,
    password,
  });

  // 7. Si falla la autenticación, devolver 401 genérico (sin revelar si el email existe o no)
  if (authError || !authData.session || !authData.user) {
    return errorResponse('Correo o contraseña incorrectos.', 401);
  }

  const { user: authUser, session } = authData;

  // 8. Usar cliente admin (service_role) para consultar perfil y progreso
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseServiceRoleKey) {
    console.error('Falta variable de entorno SUPABASE_SERVICE_ROLE_KEY.');
    return errorResponse('No se pudo completar la solicitud, intenta de nuevo.', 500);
  }

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // Consultar tabla `usuario` por id = authUser.id
  const { data: usuario, error: errorUsuario } = await supabaseAdmin
    .from('usuario')
    .select('id, nombre_usuario, nombre, apellido')
    .eq('id', authUser.id)
    .single();

  if (errorUsuario || !usuario) {
    console.error('Error al consultar perfil en tabla usuario:', errorUsuario?.message);
    return errorResponse('No se pudo completar la solicitud, intenta de nuevo.', 500);
  }

  // Consultar tabla `progreso_usuario` por id_usuario = authUser.id
  const { data: progreso, error: errorProgreso } = await supabaseAdmin
    .from('progreso_usuario')
    .select('nivel, xp_total, quests_completadas, victorias, derrotas, partidas_jugadas')
    .eq('id_usuario', authUser.id)
    .single();

  if (errorProgreso || !progreso) {
    console.error('Error al consultar progreso en tabla progreso_usuario:', errorProgreso?.message);
    return errorResponse('No se pudo completar la solicitud, intenta de nuevo.', 500);
  }

  // 9. Devolver respuesta 200 OK con tokens, usuario y progreso
  const { access_token, refresh_token, expires_in } = session;

  return jsonResponse(
    {
      ok: true,
      access_token,
      refresh_token,
      expires_in,
      usuario: {
        id: usuario.id,
        email: authUser.email ?? email,
        nombre_usuario: usuario.nombre_usuario,
        nombre: usuario.nombre,
        apellido: usuario.apellido,
      },
      progreso: {
        nivel: progreso.nivel,
        xp_total: progreso.xp_total,
        quests_completadas: progreso.quests_completadas,
        victorias: progreso.victorias,
        derrotas: progreso.derrotas,
        partidas_jugadas: progreso.partidas_jugadas,
      },
    },
    200
  );
});

/*
=== GUÍA DE DEPLOY Y PRUEBAS ===

1. Deploy:
   supabase functions deploy login

2. curl de prueba:
   curl -i --location --request POST \
     'https://jctulgfdweeurqbmugot.supabase.co/functions/v1/login' \
     --header 'Content-Type: application/json' \
     --header 'Authorization: Bearer <ANON_KEY>' \
     --data '{"email":"test1@example.com","password":"Test1234"}'
*/
