-- SysQuest — Agregar soporte para pista semántica (semantic_hint)
-- Migración: 20261029123000_add_semantic_hint.sql
-- Propósito: Agregar columna semantic_hint a la tabla encuentro y actualizar
-- las funciones RPC que insertan o consultan encuentros (crear_run_completa,
-- insertar_encuentros_extra, crear_quest_completa, obtener_quest_completa).

-- 1. Columna semantic_hint en tabla encuentro
ALTER TABLE encuentro ADD COLUMN IF NOT EXISTS semantic_hint TEXT;
COMMENT ON COLUMN encuentro.semantic_hint IS 'Pista conceptual generada por IA para resolver la pregunta sin revelar la respuesta.';

-- 2. Actualizar función RPC crear_run_completa
CREATE OR REPLACE FUNCTION crear_run_completa(
  p_quest jsonb,
  p_pool_narrativo jsonb,
  p_preguntas_extra jsonb,
  p_semilla bigint,
  p_id_usuario uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quest_id uuid;
  v_partida_id uuid;
  v_encuentro_id uuid;
  v_encuentro jsonb;
  v_opcion jsonb;
  v_numero int;
BEGIN
  -- Validar id_usuario
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_id_usuario) THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_id_usuario;
  END IF;

  -- Insertar la quest
  INSERT INTO quest (
    titulo, tema, categoria, dificultad, descripcion,
    fuente_generacion, version, activa
  ) VALUES (
    p_quest->>'titulo',
    p_quest->>'tema',
    (p_quest->>'categoria')::categoria_quest,
    (p_quest->>'dificultad')::dificultad_nivel,
    p_quest->>'descripcion',
    'AI'::fuente_generacion,
    1,
    true
  ) RETURNING id INTO v_quest_id;

  -- Insertar los 3 encuentros iniciales
  FOR v_encuentro IN SELECT jsonb_array_elements(p_quest->'encuentros') LOOP
    v_numero := (v_encuentro->>'numero')::int;
    INSERT INTO encuentro (
      id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
      enemigo, pregunta, codigo, semantic_hint
    ) VALUES (
      v_quest_id, v_numero,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'vida_enemigo')::int,
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo',
      v_encuentro->>'semantic_hint'
    ) RETURNING id INTO v_encuentro_id;

    FOR v_opcion IN SELECT jsonb_array_elements(v_encuentro->'opciones') LOOP
      INSERT INTO opcion_encuentro (id_encuentro, letra, texto, calidad, explicacion)
      VALUES (
        v_encuentro_id,
        v_opcion->>'letra',
        v_opcion->>'texto',
        (v_opcion->>'calidad')::smallint,
        v_opcion->>'explicacion'
      );
    END LOOP;
  END LOOP;

  -- Insertar las 9 preguntas extra
  FOR v_encuentro IN SELECT jsonb_array_elements(p_preguntas_extra) LOOP
    v_numero := (v_encuentro->>'numero')::int;
    INSERT INTO encuentro (
      id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
      enemigo, pregunta, codigo, semantic_hint
    ) VALUES (
      v_quest_id, v_numero,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'vida_enemigo')::int,
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo',
      v_encuentro->>'semantic_hint'
    ) RETURNING id INTO v_encuentro_id;

    FOR v_opcion IN SELECT jsonb_array_elements(v_encuentro->'opciones') LOOP
      INSERT INTO opcion_encuentro (id_encuentro, letra, texto, calidad, explicacion)
      VALUES (
        v_encuentro_id,
        v_opcion->>'letra',
        v_opcion->>'texto',
        (v_opcion->>'calidad')::smallint,
        v_opcion->>'explicacion'
      );
    END LOOP;
  END LOOP;

  -- Crear la partida
  INSERT INTO partida (
    id_usuario, id_quest, estado, encuentro_actual,
    vida_jugador_actual, vida_enemigo_actual, score, xp_obtenida,
    semilla, pool_narrativo, preguntas_extra, ronda, enemigos_derrotados
  ) VALUES (
    p_id_usuario, v_quest_id, 'en_curso', 0,
    100, (p_quest->'encuentros'->0->>'vida_enemigo')::int, 0, 0,
    p_semilla, p_pool_narrativo, p_preguntas_extra, 1, 0
  ) RETURNING id INTO v_partida_id;

  -- Devolver ids
  RETURN jsonb_build_object(
    'id_quest', v_quest_id,
    'id_partida', v_partida_id
  );
END;
$$;

REVOKE ALL ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) TO service_role;
COMMENT ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) IS 'Crea una quest + pool narrativo + preguntas extra + partida inicial en una sola transacción incluyendo semantic_hint.';

-- 3. Actualizar función RPC insertar_encuentros_extra
CREATE OR REPLACE FUNCTION insertar_encuentros_extra(
  p_id_quest uuid,
  p_encuentros jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_encuentro jsonb;
  v_encuentro_id uuid;
  v_opcion jsonb;
  v_opcion_id uuid;
  v_opciones_resultado jsonb;
  v_encuentros_resultado jsonb := '[]'::jsonb;
  v_insertados int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quest WHERE id = p_id_quest) THEN
    RAISE EXCEPTION 'Quest no encontrada: %', p_id_quest;
  END IF;

  IF jsonb_typeof(p_encuentros) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'p_encuentros debe ser un array';
  END IF;

  FOR v_encuentro IN SELECT jsonb_array_elements(p_encuentros) LOOP
    INSERT INTO encuentro (
      id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
      enemigo, pregunta, codigo, semantic_hint
    ) VALUES (
      p_id_quest,
      (v_encuentro->>'numero')::int,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      COALESCE((v_encuentro->>'vida_enemigo')::int, 50),
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo',
      v_encuentro->>'semantic_hint'
    )
    RETURNING id INTO v_encuentro_id;

    v_opciones_resultado := '[]'::jsonb;

    FOR v_opcion IN SELECT jsonb_array_elements(v_encuentro->'opciones') LOOP
      INSERT INTO opcion_encuentro (
        id_encuentro, letra, texto, calidad, explicacion
      ) VALUES (
        v_encuentro_id,
        v_opcion->>'letra',
        v_opcion->>'texto',
        (v_opcion->>'calidad')::smallint,
        v_opcion->>'explicacion'
      )
      RETURNING id INTO v_opcion_id;

      v_opciones_resultado := v_opciones_resultado || jsonb_build_array(
        v_opcion || jsonb_build_object('id', v_opcion_id)
      );
    END LOOP;

    v_encuentros_resultado := v_encuentros_resultado || jsonb_build_array(
      (v_encuentro - 'opciones') || jsonb_build_object(
        'id', v_encuentro_id,
        'opciones', v_opciones_resultado
      )
    );

    v_insertados := v_insertados + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'insertados', v_insertados,
    'encuentros', v_encuentros_resultado
  );
END;
$$;

REVOKE ALL ON FUNCTION insertar_encuentros_extra(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION insertar_encuentros_extra(uuid, jsonb) TO service_role;
COMMENT ON FUNCTION insertar_encuentros_extra(uuid, jsonb) IS 'Inserta encuentros extra con semantic_hint en una quest existente. Devuelve el número de encuentros insertados y la lista con sus IDs.';

-- 4. Actualizar función RPC crear_quest_completa
CREATE OR REPLACE FUNCTION crear_quest_completa(p_quest jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quest_id uuid;
  v_encuentro_id uuid;
  v_encuentro jsonb;
  v_opcion jsonb;
BEGIN
  IF p_quest IS NULL THEN
    RAISE EXCEPTION 'El parámetro p_quest no puede ser nulo';
  END IF;

  IF NOT (
    p_quest ? 'titulo' AND
    p_quest ? 'tema' AND
    p_quest ? 'categoria' AND
    p_quest ? 'dificultad' AND
    p_quest ? 'descripcion' AND
    p_quest ? 'fuente_generacion' AND
    p_quest ? 'encuentros'
  ) THEN
    RAISE EXCEPTION 'Faltan campos obligatorios en p_quest (se requiere: titulo, tema, categoria, dificultad, descripcion, fuente_generacion, encuentros)';
  END IF;

  IF (p_quest->>'titulo') IS NULL OR
     (p_quest->>'tema') IS NULL OR
     (p_quest->>'categoria') IS NULL OR
     (p_quest->>'dificultad') IS NULL OR
     (p_quest->>'descripcion') IS NULL OR
     (p_quest->>'fuente_generacion') IS NULL OR
     (p_quest->'encuentros') IS NULL THEN
    RAISE EXCEPTION 'Los campos obligatorios de p_quest no pueden tener valor nulo';
  END IF;

  IF jsonb_typeof(p_quest->'encuentros') <> 'array' OR jsonb_array_length(p_quest->'encuentros') <> 3 THEN
    RAISE EXCEPTION 'El campo encuentros debe ser un array con exactamente 3 elementos';
  END IF;

  FOR v_encuentro IN SELECT * FROM jsonb_array_elements(p_quest->'encuentros')
  LOOP
    IF v_encuentro->'opciones' IS NULL OR
       jsonb_typeof(v_encuentro->'opciones') <> 'array' OR
       jsonb_array_length(v_encuentro->'opciones') <> 4 THEN
      RAISE EXCEPTION 'Cada encuentro debe contener exactamente 4 opciones';
    END IF;
  END LOOP;

  INSERT INTO quest (
    titulo,
    tema,
    categoria,
    dificultad,
    descripcion,
    fuente_generacion,
    version,
    id_quest_original,
    activa
  ) VALUES (
    p_quest->>'titulo',
    p_quest->>'tema',
    (p_quest->>'categoria')::categoria_quest,
    (p_quest->>'dificultad')::dificultad_nivel,
    p_quest->>'descripcion',
    (p_quest->>'fuente_generacion')::fuente_generacion,
    1,
    null,
    true
  ) RETURNING id INTO v_quest_id;

  FOR v_encuentro IN SELECT * FROM jsonb_array_elements(p_quest->'encuentros')
  LOOP
    INSERT INTO encuentro (
      id_quest,
      numero,
      pregunta,
      dificultad,
      tipo_encuentro,
      vida_enemigo,
      enemigo,
      codigo,
      semantic_hint
    ) VALUES (
      v_quest_id,
      (v_encuentro->>'numero')::integer,
      v_encuentro->>'pregunta',
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'vida_enemigo')::integer,
      v_encuentro->>'enemigo',
      v_encuentro->>'codigo',
      v_encuentro->>'semantic_hint'
    ) RETURNING id INTO v_encuentro_id;

    FOR v_opcion IN SELECT * FROM jsonb_array_elements(v_encuentro->'opciones')
    LOOP
      INSERT INTO opcion_encuentro (
        id_encuentro,
        letra,
        texto,
        calidad,
        explicacion
      ) VALUES (
        v_encuentro_id,
        v_opcion->>'letra',
        v_opcion->>'texto',
        (v_opcion->>'calidad')::smallint,
        v_opcion->>'explicacion'
      );
    END LOOP;
  END LOOP;

  RETURN v_quest_id;
END;
$$;

COMMENT ON FUNCTION crear_quest_completa(jsonb) IS 'Inserta atómicamente una quest completa con sus 3 encuentros, semantic_hint y 12 opciones a partir de un JSON validado.';
REVOKE ALL ON FUNCTION crear_quest_completa(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION crear_quest_completa(jsonb) TO service_role;

-- 5. Actualizar función RPC obtener_quest_completa
CREATE OR REPLACE FUNCTION obtener_quest_completa(p_id_quest uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF p_id_quest IS NULL THEN
    RAISE EXCEPTION 'El parámetro p_id_quest no puede ser nulo';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM quest WHERE id = p_id_quest) THEN
    RAISE EXCEPTION 'Quest no encontrada';
  END IF;

  SELECT jsonb_build_object(
    'id', q.id,
    'titulo', q.titulo,
    'tema', q.tema,
    'categoria', q.categoria,
    'dificultad', q.dificultad,
    'descripcion', q.descripcion,
    'fuente_generacion', q.fuente_generacion,
    'version', q.version,
    'encuentros', coalesce((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'numero', e.numero,
          'tipo_encuentro', e.tipo_encuentro,
          'dificultad', e.dificultad,
          'vida_enemigo', e.vida_enemigo,
          'enemigo', e.enemigo,
          'pregunta', e.pregunta,
          'codigo', e.codigo,
          'semantic_hint', e.semantic_hint,
          'opciones', coalesce((
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', o.id,
                'letra', o.letra,
                'texto', o.texto,
                'calidad', o.calidad,
                'explicacion', o.explicacion
              ) ORDER BY o.letra ASC
            )
            FROM opcion_encuentro o
            WHERE o.id_encuentro = e.id
          ), '[]'::jsonb)
        ) ORDER BY e.numero ASC
      )
      FROM encuentro e
      WHERE e.id_quest = q.id
    ), '[]'::jsonb)
  )
  INTO v_result
  FROM quest q
  WHERE q.id = p_id_quest;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Quest no encontrada';
  END IF;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION obtener_quest_completa(uuid) IS 'Devuelve una quest completa con todos sus encuentros (incluyendo semantic_hint) y opciones estructurados como un solo objeto jsonb.';
REVOKE ALL ON FUNCTION obtener_quest_completa(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION obtener_quest_completa(uuid) TO service_role;

