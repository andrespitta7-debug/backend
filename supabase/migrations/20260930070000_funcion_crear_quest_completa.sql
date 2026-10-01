-- SysQuest — Función RPC para inserción atómica de quest generada por IA
-- Migración: 20260930070000_funcion_crear_quest_completa.sql
-- Propósito: Insertar de forma atómica una quest junto a sus 3 encuentros
-- y sus 12 opciones (4 por encuentro) a partir del payload JSON validado.
-- Si ocurre cualquier error, Postgres realiza un ROLLBACK automático completo.

create or replace function crear_quest_completa(p_quest jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quest_id uuid;
  v_encuentro_id uuid;
  v_encuentro jsonb;
  v_opcion jsonb;
begin
  -- 1. Validar que p_quest no sea nulo y contenga todos los campos requeridos
  if p_quest is null then
    raise exception 'El parámetro p_quest no puede ser nulo';
  end if;

  if not (
    p_quest ? 'titulo' and
    p_quest ? 'tema' and
    p_quest ? 'categoria' and
    p_quest ? 'dificultad' and
    p_quest ? 'descripcion' and
    p_quest ? 'fuente_generacion' and
    p_quest ? 'encuentros'
  ) then
    raise exception 'Faltan campos obligatorios en p_quest (se requiere: titulo, tema, categoria, dificultad, descripcion, fuente_generacion, encuentros)';
  end if;

  if (p_quest->>'titulo') is null or
     (p_quest->>'tema') is null or
     (p_quest->>'categoria') is null or
     (p_quest->>'dificultad') is null or
     (p_quest->>'descripcion') is null or
     (p_quest->>'fuente_generacion') is null or
     (p_quest->'encuentros') is null then
    raise exception 'Los campos obligatorios de p_quest no pueden tener valor nulo';
  end if;

  -- 2. Validar que encuentros sea un array de exactamente 3 elementos
  if jsonb_typeof(p_quest->'encuentros') <> 'array' or jsonb_array_length(p_quest->'encuentros') <> 3 then
    raise exception 'El campo encuentros debe ser un array con exactamente 3 elementos';
  end if;

  -- 3. Validar que cada encuentro tenga exactamente 4 opciones
  for v_encuentro in select * from jsonb_array_elements(p_quest->'encuentros')
  loop
    if v_encuentro->'opciones' is null or
       jsonb_typeof(v_encuentro->'opciones') <> 'array' or
       jsonb_array_length(v_encuentro->'opciones') <> 4 then
      raise exception 'Cada encuentro debe contener exactamente 4 opciones';
    end if;
  end loop;

  -- 4. Insertar en quest
  insert into quest (
    titulo,
    tema,
    categoria,
    dificultad,
    descripcion,
    fuente_generacion,
    version,
    id_quest_original,
    activa
  ) values (
    p_quest->>'titulo',
    p_quest->>'tema',
    (p_quest->>'categoria')::categoria_quest,
    (p_quest->>'dificultad')::dificultad_nivel,
    p_quest->>'descripcion',
    (p_quest->>'fuente_generacion')::fuente_generacion,
    1,
    null,
    true
  ) returning id into v_quest_id;

  -- 5. Insertar encuentros y opciones
  for v_encuentro in select * from jsonb_array_elements(p_quest->'encuentros')
  loop
    insert into encuentro (
      id_quest,
      numero,
      pregunta,
      dificultad,
      tipo_encuentro,
      vida_enemigo,
      enemigo,
      codigo
    ) values (
      v_quest_id,
      (v_encuentro->>'numero')::integer,
      v_encuentro->>'pregunta',
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'vida_enemigo')::integer,
      v_encuentro->>'enemigo',
      v_encuentro->>'codigo'
    ) returning id into v_encuentro_id;

    for v_opcion in select * from jsonb_array_elements(v_encuentro->'opciones')
    loop
      insert into opcion_encuentro (
        id_encuentro,
        letra,
        texto,
        calidad,
        explicacion
      ) values (
        v_encuentro_id,
        v_opcion->>'letra',
        v_opcion->>'texto',
        (v_opcion->>'calidad')::smallint,
        v_opcion->>'explicacion'
      );
    end loop;
  end loop;

  -- 6. Devolver el id de la quest creada
  return v_quest_id;
end;
$$;

comment on function crear_quest_completa(jsonb) is 'Inserta atómicamente una quest completa con sus 3 encuentros y 12 opciones a partir de un JSON validado.';

-- Seguridad: Revocar ejecución pública y otorgar solo a service_role
revoke all on function crear_quest_completa(jsonb) from public;
grant execute on function crear_quest_completa(jsonb) to service_role;
