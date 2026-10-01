-- SysQuest — Función RPC para crear run completa (quest + pool narrativo + preguntas extra + partida inicial)
-- Migración: 20261001130000_funcion_crear_run_completa.sql
-- Propósito: Inserción atómica en una sola transacción de la quest, sus 3 encuentros iniciales,
-- las 9 preguntas extra como encuentros adicionales, y la creación de la partida inicial para el usuario.

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
  -- 1. Validar id_usuario
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_id_usuario) THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_id_usuario;
  END IF;

  -- 2. Insertar la quest
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

  -- 3. Insertar los 3 encuentros iniciales
  FOR v_encuentro IN SELECT jsonb_array_elements(p_quest->'encuentros') LOOP
    v_numero := (v_encuentro->>'numero')::int;
    INSERT INTO encuentro (
      id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
      enemigo, pregunta, codigo
    ) VALUES (
      v_quest_id, v_numero,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'vida_enemigo')::int,
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo'
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

  -- 4. Insertar las 9 preguntas extra
  FOR v_encuentro IN SELECT jsonb_array_elements(p_preguntas_extra) LOOP
    v_numero := (v_encuentro->>'numero')::int;
    INSERT INTO encuentro (
      id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
      enemigo, pregunta, codigo
    ) VALUES (
      v_quest_id, v_numero,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      (v_encuentro->>'vida_enemigo')::int,
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo'
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

  -- 5. Crear la partida
  INSERT INTO partida (
    id_usuario, id_quest, estado, encuentro_actual,
    vida_jugador_actual, vida_enemigo_actual, score, xp_obtenida,
    semilla, pool_narrativo, preguntas_extra, ronda, enemigos_derrotados
  ) VALUES (
    p_id_usuario, v_quest_id, 'en_curso', 0,
    100, (p_quest->'encuentros'->0->>'vida_enemigo')::int, 0, 0,
    p_semilla, p_pool_narrativo, p_preguntas_extra, 1, 0
  ) RETURNING id INTO v_partida_id;

  -- 6. Devolver ids
  RETURN jsonb_build_object(
    'id_quest', v_quest_id,
    'id_partida', v_partida_id
  );
END;
$$;

REVOKE ALL ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) TO service_role;

comment on function crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) is 'Crea una quest + pool narrativo + preguntas extra + partida inicial en una sola transacción.';
