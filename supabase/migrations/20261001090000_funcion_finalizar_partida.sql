-- SysQuest — Función RPC para registrar fin de partida y actualizar progreso
-- Migración: 20261001090000_funcion_finalizar_partida.sql
-- Propósito: Insertar atómicamente el resultado de una partida en `partida` y
-- actualizar el progreso acumulado en `progreso_usuario` (XP, nivel, victorias,
-- derrotas, quests completadas, partidas jugadas).
-- Todo dentro de una única transacción: si algo falla, Postgres realiza ROLLBACK total.

create or replace function finalizar_partida(p_partida jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_partida uuid;
  v_id_usuario uuid;
  v_id_quest uuid;
  v_estado text;
  v_xp integer;
  v_encuentro_actual integer;
  v_score integer;
  v_tiempo_segundos integer;
  v_vida_jugador integer;
  v_vida_enemigo integer;
begin
  -- 1. Validar que p_partida no sea nulo y contenga todos los campos obligatorios
  if p_partida is null then
    raise exception 'El parámetro p_partida no puede ser nulo';
  end if;

  if not (
    p_partida ? 'id_partida' and
    p_partida ? 'id_usuario' and
    p_partida ? 'id_quest' and
    p_partida ? 'estado' and
    p_partida ? 'xp_obtenida'
  ) then
    raise exception 'Faltan campos obligatorios en p_partida (se requiere: id_partida, id_usuario, id_quest, estado, xp_obtenida)';
  end if;

  if (p_partida->>'id_partida') is null or
     (p_partida->>'id_usuario') is null or
     (p_partida->>'id_quest') is null or
     (p_partida->>'estado') is null or
     (p_partida->>'xp_obtenida') is null then
    raise exception 'Los campos obligatorios de p_partida no pueden tener valor nulo';
  end if;

  -- 2. Validar que estado sea 'ganada' o 'perdida'
  if p_partida->>'estado' not in ('ganada', 'perdida') then
    raise exception 'El estado de la partida debe ser "ganada" o "perdida"';
  end if;

  v_id_partida := (p_partida->>'id_partida')::uuid;
  v_id_usuario := (p_partida->>'id_usuario')::uuid;
  v_id_quest   := (p_partida->>'id_quest')::uuid;
  v_estado     := p_partida->>'estado';
  v_xp         := (p_partida->>'xp_obtenida')::integer;

  -- 3. Validar que el usuario exista
  if not exists (select 1 from usuario where id = v_id_usuario) then
    raise exception 'Usuario no encontrado';
  end if;

  -- 4. Validar que la quest exista
  if not exists (select 1 from quest where id = v_id_quest) then
    raise exception 'Quest no encontrada';
  end if;

  -- Extraer campos con valores por defecto
  v_encuentro_actual := coalesce((p_partida->>'encuentro_actual')::integer, 0);
  v_score            := coalesce((p_partida->>'score')::integer, 0);
  v_tiempo_segundos  := coalesce((p_partida->>'tiempo_segundos')::integer, 0);

  v_vida_jugador := case
    when p_partida ? 'vida_jugador_actual' and (p_partida->>'vida_jugador_actual') is not null
    then (p_partida->>'vida_jugador_actual')::integer
    when v_estado = 'perdida' then 0
    else 100
  end;

  v_vida_enemigo := case
    when p_partida ? 'vida_enemigo_actual' and (p_partida->>'vida_enemigo_actual') is not null
    then (p_partida->>'vida_enemigo_actual')::integer
    else null
  end;

  -- 5. Insertar la fila de la partida
  insert into partida (
    id,
    id_usuario,
    id_quest,
    estado,
    encuentro_actual,
    score,
    xp_obtenida,
    tiempo_segundos,
    vida_jugador_actual,
    vida_enemigo_actual,
    resultado,
    started_at,
    finished_at,
    updated_at
  ) values (
    v_id_partida,
    v_id_usuario,
    v_id_quest,
    v_estado::estado_partida,
    v_encuentro_actual,
    v_score,
    v_xp,
    v_tiempo_segundos,
    v_vida_jugador,
    v_vida_enemigo,
    v_estado::estado_partida,
    coalesce((p_partida->>'started_at')::timestamptz, now()),
    now(),
    now()
  );

  -- 6. Actualizar las estadísticas de progreso_usuario en una sola sentencia
  update progreso_usuario
  set
    xp_total           = xp_total + v_xp,
    victorias          = victorias + (case when v_estado = 'ganada' then 1 else 0 end),
    derrotas           = derrotas + (case when v_estado = 'perdida' then 1 else 0 end),
    quests_completadas = quests_completadas + (case when v_estado = 'ganada' then 1 else 0 end),
    partidas_jugadas   = partidas_jugadas + 1,
    nivel              = 1 + floor((xp_total + v_xp) / 100),
    updated_at         = now()
  where id_usuario = v_id_usuario;

end;
$$;

comment on function finalizar_partida(jsonb) is 'Guarda una partida finalizada y actualiza el progreso acumulado del usuario de forma atómica.';

-- Seguridad: Revocar ejecución pública y otorgar solo a service_role
revoke all on function finalizar_partida(jsonb) from public;
grant execute on function finalizar_partida(jsonb) to service_role;
