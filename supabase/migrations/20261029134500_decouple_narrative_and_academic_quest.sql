-- SysQuest — Desacoplamiento de narrativa y soporte para misiones académicas
-- Migración: 20261029134500_decouple_narrative_and_academic_quest.sql
-- Propósito: Hacer pool_narrativo nullable en partida, añadir quest_title y resolved_topic
-- en tablas quest y partida, y actualizar crear_run_completa para soportar ambos campos y retornar quest_title y resolved_topic.

-- 1. pool_narrativo nullable en partida
ALTER TABLE public.partida ALTER COLUMN pool_narrativo DROP NOT NULL;

-- 2. quest_title y resolved_topic en quest y partida
ALTER TABLE public.quest ADD COLUMN IF NOT EXISTS quest_title TEXT;
ALTER TABLE public.quest ADD COLUMN IF NOT EXISTS resolved_topic TEXT;
ALTER TABLE public.partida ADD COLUMN IF NOT EXISTS quest_title TEXT;
ALTER TABLE public.partida ADD COLUMN IF NOT EXISTS resolved_topic TEXT;

COMMENT ON COLUMN public.quest.quest_title IS 'Título épico de la misión (ej. La Cripta de la Alquimia Culinaria).';
COMMENT ON COLUMN public.quest.resolved_topic IS 'Tema normalizado y limpio (ej. Gastronomía: Pastas).';
COMMENT ON COLUMN public.partida.quest_title IS 'Título épico de la misión asociada a la partida.';
COMMENT ON COLUMN public.partida.resolved_topic IS 'Tema normalizado asociado a la partida.';

-- 3. Actualizar función RPC crear_run_completa
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
  v_titulo text;
  v_tema text;
  v_vida_inicial int;
BEGIN
  -- Validar id_usuario
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_id_usuario) THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_id_usuario;
  END IF;

  v_titulo := COALESCE(p_quest->>'quest_title', p_quest->>'titulo', 'Misión Sin Título');
  v_tema := COALESCE(p_quest->>'resolved_topic', p_quest->>'tema', 'General');

  -- Insertar la quest
  INSERT INTO quest (
    titulo, tema, quest_title, resolved_topic, categoria, dificultad, descripcion,
    fuente_generacion, version, activa
  ) VALUES (
    v_titulo,
    v_tema,
    v_titulo,
    v_tema,
    COALESCE((p_quest->>'categoria')::categoria_quest, 'libre'::categoria_quest),
    COALESCE((p_quest->>'dificultad')::dificultad_nivel, 'facil'::dificultad_nivel),
    COALESCE(p_quest->>'descripcion', 'Misión académica sobre ' || v_tema),
    'AI'::fuente_generacion,
    1,
    true
  ) RETURNING id INTO v_quest_id;

  -- Insertar los encuentros iniciales
  IF p_quest->'encuentros' IS NOT NULL AND jsonb_typeof(p_quest->'encuentros') = 'array' THEN
    FOR v_encuentro IN SELECT jsonb_array_elements(p_quest->'encuentros') LOOP
      v_numero := (v_encuentro->>'numero')::int;
      INSERT INTO encuentro (
        id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
        enemigo, pregunta, codigo, semantic_hint
      ) VALUES (
        v_quest_id, v_numero,
        COALESCE((v_encuentro->>'tipo_encuentro')::tipo_encuentro, 'normal'::tipo_encuentro),
        COALESCE((v_encuentro->>'dificultad')::dificultad_nivel, (p_quest->>'dificultad')::dificultad_nivel, 'facil'::dificultad_nivel),
        COALESCE((v_encuentro->>'vida_enemigo')::int, 50),
        COALESCE(v_encuentro->>'enemigo', 'Desafío ' || v_numero),
        v_encuentro->>'pregunta',
        v_encuentro->>'codigo',
        v_encuentro->>'semantic_hint'
      ) RETURNING id INTO v_encuentro_id;

      IF v_encuentro->'opciones' IS NOT NULL AND jsonb_typeof(v_encuentro->'opciones') = 'array' THEN
        FOR v_opcion IN SELECT jsonb_array_elements(v_encuentro->'opciones') LOOP
          INSERT INTO opcion_encuentro (id_encuentro, letra, texto, calidad, explicacion)
          VALUES (
            v_encuentro_id,
            v_opcion->>'letra',
            v_opcion->>'texto',
            COALESCE((v_opcion->>'calidad')::smallint, 1),
            COALESCE(v_opcion->>'explicacion', '')
          );
        END LOOP;
      END IF;
    END LOOP;
  END IF;

  -- Insertar las preguntas extra si existen
  IF p_preguntas_extra IS NOT NULL AND jsonb_typeof(p_preguntas_extra) = 'array' THEN
    FOR v_encuentro IN SELECT jsonb_array_elements(p_preguntas_extra) LOOP
      v_numero := (v_encuentro->>'numero')::int;
      INSERT INTO encuentro (
        id_quest, numero, tipo_encuentro, dificultad, vida_enemigo,
        enemigo, pregunta, codigo, semantic_hint
      ) VALUES (
        v_quest_id, v_numero,
        COALESCE((v_encuentro->>'tipo_encuentro')::tipo_encuentro, 'normal'::tipo_encuentro),
        COALESCE((v_encuentro->>'dificultad')::dificultad_nivel, (p_quest->>'dificultad')::dificultad_nivel, 'facil'::dificultad_nivel),
        COALESCE((v_encuentro->>'vida_enemigo')::int, 50),
        COALESCE(v_encuentro->>'enemigo', 'Desafío ' || v_numero),
        v_encuentro->>'pregunta',
        v_encuentro->>'codigo',
        v_encuentro->>'semantic_hint'
      ) RETURNING id INTO v_encuentro_id;

      IF v_encuentro->'opciones' IS NOT NULL AND jsonb_typeof(v_encuentro->'opciones') = 'array' THEN
        FOR v_opcion IN SELECT jsonb_array_elements(v_encuentro->'opciones') LOOP
          INSERT INTO opcion_encuentro (id_encuentro, letra, texto, calidad, explicacion)
          VALUES (
            v_encuentro_id,
            v_opcion->>'letra',
            v_opcion->>'texto',
            COALESCE((v_opcion->>'calidad')::smallint, 1),
            COALESCE(v_opcion->>'explicacion', '')
          );
        END LOOP;
      END IF;
    END LOOP;
  END IF;

  v_vida_inicial := COALESCE((p_quest->'encuentros'->0->>'vida_enemigo')::int, 50);

  -- Crear la partida
  INSERT INTO partida (
    id_usuario, id_quest, estado, encuentro_actual,
    vida_jugador_actual, vida_enemigo_actual, score, xp_obtenida,
    semilla, pool_narrativo, preguntas_extra, ronda, enemigos_derrotados,
    quest_title, resolved_topic
  ) VALUES (
    p_id_usuario, v_quest_id, 'en_curso', 0,
    100, v_vida_inicial, 0, 0,
    p_semilla, p_pool_narrativo, p_preguntas_extra, 1, 0,
    v_titulo, v_tema
  ) RETURNING id INTO v_partida_id;

  -- Devolver ids y campos académicos
  RETURN jsonb_build_object(
    'id_quest', v_quest_id,
    'id_partida', v_partida_id,
    'quest_title', v_titulo,
    'resolved_topic', v_tema
  );
END;
$$;

REVOKE ALL ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) TO service_role;
COMMENT ON FUNCTION crear_run_completa(jsonb, jsonb, jsonb, bigint, uuid) IS 'Crea quest, encuentros, opciones y partida inicial para SysQuest con soporte de quest_title, resolved_topic y pool_narrativo opcional.';

