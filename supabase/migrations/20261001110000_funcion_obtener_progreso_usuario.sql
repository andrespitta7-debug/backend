-- SysQuest — Función RPC para obtener el progreso acumulado de un usuario
-- Migración: 20261001110000_funcion_obtener_progreso_usuario.sql
-- Propósito: Consultar las estadísticas y progreso del usuario (nivel, XP, victorias,
-- derrotas, quests completadas, partidas jugadas) a partir de su UUID y devolverlas en formato JSONB.

create or replace function obtener_progreso_usuario(p_id_usuario uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  -- 1. Validar que p_id_usuario no sea nulo
  if p_id_usuario is null then
    raise exception 'El parámetro p_id_usuario no puede ser nulo';
  end if;

  -- 2. Consultar el progreso del usuario y construir el JSONB
  select jsonb_build_object(
    'nivel', nivel,
    'xp_total', xp_total,
    'quests_completadas', quests_completadas,
    'victorias', victorias,
    'derrotas', derrotas,
    'partidas_jugadas', partidas_jugadas
  )
  into v_result
  from progreso_usuario
  where id_usuario = p_id_usuario;

  -- 3. Si no existe registro de progreso para este usuario
  if v_result is null then
    raise exception 'Progreso no encontrado';
  end if;

  -- 4. Devolver resultado
  return v_result;
end;
$$;

comment on function obtener_progreso_usuario(uuid) is 'Devuelve el progreso y estadísticas de juego acumuladas de un usuario en un objeto jsonb.';

-- Seguridad: Revocar ejecución pública y otorgar solo a service_role
revoke all on function obtener_progreso_usuario(uuid) from public;
grant execute on function obtener_progreso_usuario(uuid) to service_role;
