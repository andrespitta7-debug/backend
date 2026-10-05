-- SysQuest — Función RPC para insertar encuentros extra en una quest existente
-- Migración: 20261006000000_funcion_insertar_encuentros_extra.sql
-- Retorna el número de encuentros insertados y la lista completa enriquecida con IDs generados.

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
      enemigo, pregunta, codigo
    ) VALUES (
      p_id_quest,
      (v_encuentro->>'numero')::int,
      (v_encuentro->>'tipo_encuentro')::tipo_encuentro,
      (v_encuentro->>'dificultad')::dificultad_nivel,
      COALESCE((v_encuentro->>'vida_enemigo')::int, 50),
      v_encuentro->>'enemigo',
      v_encuentro->>'pregunta',
      v_encuentro->>'codigo'
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

COMMENT ON FUNCTION insertar_encuentros_extra(uuid, jsonb) IS
'Inserta encuentros extra en una quest existente. Devuelve el número de encuentros insertados y la lista con sus IDs.';
