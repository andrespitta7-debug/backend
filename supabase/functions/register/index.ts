// Supabase Edge Function: register
// Endpoint: POST /functions/v1/register
// Propósito: Registrar un nuevo usuario en Supabase Auth, registrar su perfil
// en la tabla `usuario`, inicializar sus estadísticas en `progreso_usuario`
// y generar una sesión autenticada con JWT de retorno.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, errorResponse, jsonResponse } from '../_shared/response.ts';
import { validarRegistro } from '../_shared/validation.ts';

Deno.serve(async (req: Request) => {
  // Manejo de preflight CORS (OPTIONS)
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  // Validación de método HTTP: solo POST
  if (req.method !== 'POST') {
    return errorResponse('Método no permitido.', 405);
  }

  // Parseo seguro del cuerpo JSON
  let body: Record<string, unknown>;
  try {
    body = await req.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return errorResponse('Cuerpo inválido.', 400);
    }
  } catch (_err) {
    return errorResponse('Cuerpo inválido.', 400);
  }

  // Validación de datos con las mismas reglas de RegistrarUsuarioUseCase en Flutter
  const validacion = validarRegistro(body);
  if (!validacion.valido || !validacion.datos) {
    return errorResponse(validacion.error ?? 'Datos de registro inválidos.', 400);
  }

  const { email, password, nombre, apellido, nombre_usuario } = validacion.datos;

  // Variables de entorno inyectadas por el runtime de Supabase
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

  if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
    console.error('Faltan variables de entorno requeridas (URL, SERVICE_ROLE_KEY o ANON_KEY).');
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  // Cliente con permisos de administración (service_role) para Auth y omitir RLS
  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // 1. Verificar si el nombre_usuario ya existe en la tabla `usuario`
  const { data: usuarioExistente, error: errorBusqueda } = await supabaseAdmin
    .from('usuario')
    .select('id')
    .eq('nombre_usuario', nombre_usuario)
    .maybeSingle();

  if (errorBusqueda) {
    console.error('Error al consultar nombre_usuario en tabla usuario:', errorBusqueda);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  if (usuarioExistente) {
    return errorResponse('El nombre de usuario ya está registrado.', 409);
  }

  // 2. Crear usuario en auth.users con email confirmado automáticamente
  const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (authError) {
    const errorMsg = authError.message?.toLowerCase() ?? '';
    if (
      errorMsg.includes('already') ||
      errorMsg.includes('registered') ||
      authError.status === 422
    ) {
      return errorResponse('El correo ya está registrado.', 409);
    }
    console.error('Error al crear usuario en Supabase Auth:', authError.message);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  if (!authData.user) {
    console.error('Respuesta de auth.admin.createUser sin datos de usuario.');
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  const authUser = authData.user;

  // 3. Crear fila en la tabla `usuario`
  const { data: usuarioCreado, error: errorUsuario } = await supabaseAdmin
    .from('usuario')
    .insert({
      id: authUser.id,
      nombre_usuario,
      nombre,
      apellido,
    })
    .select('id, nombre_usuario, nombre, apellido')
    .single();

  if (errorUsuario) {
    // Rollback de compensación: eliminar usuario en Auth si falla la inserción en BD
    try {
      await supabaseAdmin.auth.admin.deleteUser(authUser.id);
    } catch (deleteError) {
      console.error('Error al limpiar usuario en Auth tras fallo en tabla usuario:', deleteError);
    }

    if (errorUsuario.code === '23505') {
      return errorResponse('El nombre de usuario ya está registrado.', 409);
    }

    console.error('Error al insertar en tabla usuario:', errorUsuario.message);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  // 4. Crear fila en `progreso_usuario` con valores por defecto
  const { data: progresoCreado, error: errorProgreso } = await supabaseAdmin
    .from('progreso_usuario')
    .insert({
      id_usuario: authUser.id,
      nivel: 1,
      xp_total: 0,
      quests_completadas: 0,
      victorias: 0,
      derrotas: 0,
      partidas_jugadas: 0,
    })
    .select('nivel, xp_total, quests_completadas, victorias, derrotas, partidas_jugadas')
    .single();

  if (errorProgreso) {
    // Rollback de compensación: cascada elimina también el registro de `usuario`
    try {
      await supabaseAdmin.auth.admin.deleteUser(authUser.id);
    } catch (deleteError) {
      console.error('Error al limpiar usuario en Auth tras fallo en progreso_usuario:', deleteError);
    }

    console.error('Error al insertar en progreso_usuario:', errorProgreso.message);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  // 4b. Crear fila en `personaje` con valores vacíos por defecto
  const { error: errorPersonaje } = await supabaseAdmin
    .from('personaje')
    .insert({
      id_usuario: authUser.id,
      nombre: null,
      genero: null,
      skin: null,
    });

  if (errorPersonaje) {
    // Rollback de compensación: cascada elimina también el registro de `usuario`
    try {
      await supabaseAdmin.auth.admin.deleteUser(authUser.id);
    } catch (deleteError) {
      console.error('Error al limpiar usuario en Auth tras fallo en personaje:', deleteError);
    }

    console.error('Error al insertar en personaje:', errorPersonaje.message);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  // 5. Iniciar sesión automáticamente con el cliente anon para generar el JWT
  const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: sessionData, error: sessionError } = await supabaseAnon.auth.signInWithPassword({
    email,
    password,
  });

  if (sessionError || !sessionData.session) {
    console.error('Error al autenticar para obtener JWT de sesión:', sessionError?.message);
    return errorResponse('No se pudo completar el registro, intenta de nuevo.', 500);
  }

  const { access_token, refresh_token, expires_in } = sessionData.session;

  // 6. Respuesta 201 Created con el contrato HTTP esperado
  return jsonResponse(
    {
      ok: true,
      access_token,
      refresh_token,
      expires_in,
      usuario: {
        id: usuarioCreado.id,
        email,
        nombre_usuario: usuarioCreado.nombre_usuario,
        nombre: usuarioCreado.nombre,
        apellido: usuarioCreado.apellido,
      },
      progreso: {
        nivel: progresoCreado.nivel,
        xp_total: progresoCreado.xp_total,
        quests_completadas: progresoCreado.quests_completadas,
        victorias: progresoCreado.victorias,
        derrotas: progresoCreado.derrotas,
        partidas_jugadas: progresoCreado.partidas_jugadas,
      },
    },
    201
  );
});

/*
=== GUÍA DE DESPLIEGUE Y PRUEBAS ===

1. Cómo desplegar:
   supabase functions deploy register

2. Cómo probar localmente:
   supabase functions serve register

3. Ejemplo de cURL para probar el endpoint:
   curl -i --location --request POST \
     'https://jctulgfdweeurqbmugot.supabase.co/functions/v1/register' \
     --header 'Content-Type: application/json' \
     --data '{"email":"test@example.com","password":"Test1234","nombre":"Test","apellido":"User","nombre_usuario":"test_user"}'
*/
