-- Función para insertar de forma atómica y eficiente encuentros adicionales generados por la IA en una run extendida
CREATE OR REPLACE FUNCTION public.insertar_encuentros_extra(p_id_quest uuid, p_encuentros jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    enc_record record;
    encuentro_id uuid;
    opcion jsonb;
    result_array jsonb := '[]'::jsonb;
    encuentro_con_uuid jsonb;
BEGIN
    FOR enc_record IN SELECT * FROM jsonb_array_elements(p_encuentros) LOOP
        -- 1. Insertar el encuentro
        INSERT INTO encuentro (id_quest, numero, pregunta, dificultad, tipo_encuentro, vida_enemigo)
        VALUES (
            p_id_quest,
            (enc_record.value->>'numero')::integer,
            enc_record.value->>'pregunta',
            (enc_record.value->>'dificultad')::dificultad_nivel,
            (enc_record.value->>'tipo_encuentro')::tipo_encuentro,
            COALESCE((enc_record.value->>'vida_enemigo')::integer, 50)
        )
        RETURNING id INTO encuentro_id;

        -- 2. Insertar las opciones
        FOR opcion IN SELECT * FROM jsonb_array_elements(enc_record.value->'opciones') LOOP
            INSERT INTO opcion_encuentro (id_encuentro, letra, texto, calidad)
            VALUES (
                encuentro_id,
                opcion->>'letra',
                opcion->>'texto',
                (opcion->>'calidad')::smallint
            );
        END LOOP;

        -- 3. Construir el objeto de retorno enriquecido con el UUID generado
        encuentro_con_uuid := enc_record.value || jsonb_build_object('id', encuentro_id);
        result_array := result_array || encuentro_con_uuid;
    END LOOP;

    RETURN result_array;
END;
$$;

-- Otorgar permisos solo al service_role (usado por la Edge Function)
REVOKE ALL ON FUNCTION public.insertar_encuentros_extra(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insertar_encuentros_extra(uuid, jsonb) TO service_role;
