-- SysQuest — Función RPC para obtener quest completa con encuentros y opciones
-- Migración: 20261001100000_funcion_obtener_quest_completa.sql
-- Propósito: Consultar una quest por su UUID y devolver toda su estructura jerárquica
-- (quest, encuentros ordenados por número y opciones ordenadas por letra) en un único JSONB.

create or replace function obtener_quest_completa(p_id_quest uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  -- 1. Validar que p_id_quest no sea nulo
  if p_id_quest is null then
    raise exception 'El parámetro p_id_quest no puede ser nulo';
  end if;

  -- 2. Validar que la quest exista
  if not exists (select 1 from quest where id = p_id_quest) then
    raise exception 'Quest no encontrada';
  end if;

  -- 3. Construir el JSONB jerárquico anidado
  select jsonb_build_object(
    'id', q.id,
    'titulo', q.titulo,
    'tema', q.tema,
    'categoria', q.categoria,
    'dificultad', q.dificultad,
    'descripcion', q.descripcion,
    'fuente_generacion', q.fuente_generacion,
    'version', q.version,
    'encuentros', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'numero', e.numero,
          'tipo_encuentro', e.tipo_encuentro,
          'dificultad', e.dificultad,
          'vida_enemigo', e.vida_enemigo,
          'enemigo', e.enemigo,
          'pregunta', e.pregunta,
          'codigo', e.codigo,
          'opciones', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', o.id,
                'letra', o.letra,
                'texto', o.texto,
                'calidad', o.calidad,
                'explicacion', o.explicacion
              ) order by o.letra asc
            )
            from opcion_encuentro o
            where o.id_encuentro = e.id
          ), '[]'::jsonb)
        ) order by e.numero asc
      )
      from encuentro e
      where e.id_quest = q.id
    ), '[]'::jsonb)
  )
  into v_result
  from quest q
  where q.id = p_id_quest;

  if v_result is null then
    raise exception 'Quest no encontrada';
  end if;

  return v_result;
end;
$$;

comment on function obtener_quest_completa(uuid) is 'Devuelve una quest completa con todos sus encuentros y opciones estructurados como un solo objeto jsonb.';

-- Seguridad: Revocar ejecución pública y otorgar solo a service_role
revoke all on function obtener_quest_completa(uuid) from public;
grant execute on function obtener_quest_completa(uuid) to service_role;
