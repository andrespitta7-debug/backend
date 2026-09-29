-- SysQuest — Datos de prueba iniciales (Quest DOCENTE categoría 'debug')
-- Migración: 20260929020000_datos_prueba_debug.sql
-- Propósito: Insertar una quest semilla tipo DOCENTE con 3 encuentros y sus
-- opciones para validación en Postman y Supabase Table Editor.
-- Idempotente: Si la quest ya existe, no realiza inserciones duplicadas.

WITH nueva_quest AS (
  INSERT INTO quest (
    id,
    titulo,
    tema,
    categoria,
    dificultad,
    descripcion,
    fuente_generacion,
    version,
    id_quest_original,
    activa
  )
  SELECT
    gen_random_uuid(),
    'Quest de Depuración — Conceptos básicos',
    'Errores comunes y debugging',
    'debug'::categoria_quest,
    'facil'::dificultad_nivel,
    'Aventura introductoria sobre técnicas básicas de depuración en programación.',
    'DOCENTE'::fuente_generacion,
    1,
    NULL,
    true
  WHERE NOT EXISTS (
    SELECT 1 FROM quest
    WHERE titulo = 'Quest de Depuración — Conceptos básicos'
      AND version = 1
  )
  RETURNING id
),
nuevos_encuentros AS (
  INSERT INTO encuentro (
    id,
    id_quest,
    numero,
    pregunta,
    dificultad,
    tipo_encuentro,
    vida_enemigo
  )
  SELECT
    gen_random_uuid(),
    nueva_quest.id,
    datos.numero,
    datos.pregunta,
    datos.dificultad::dificultad_nivel,
    datos.tipo_encuentro::tipo_encuentro,
    datos.vida_enemigo
  FROM nueva_quest,
  (VALUES
    (1, '¿Para qué sirve un breakpoint en un depurador?', 'facil', 'normal', 30),
    (2, '¿Qué es un stack trace?', 'medio', 'normal', 40),
    (3, '¿Cuál es la mejor práctica al depurar un bug?', 'dificil', 'jefe', 70)
  ) AS datos(numero, pregunta, dificultad, tipo_encuentro, vida_enemigo)
  RETURNING id, numero
)
INSERT INTO opcion_encuentro (
  id,
  id_encuentro,
  letra,
  texto,
  calidad
)
SELECT
  gen_random_uuid(),
  e.id,
  o.letra,
  o.texto,
  o.calidad
FROM nuevos_encuentros e
JOIN (VALUES
  -- Opciones Encuentro 1
  (1, 'A', 'Para detener la ejecución en un punto y examinar el estado', 2::smallint),
  (1, 'B', 'Para forzar un error controlado', 1::smallint),
  (1, 'C', 'Para cerrar el programa', 0::smallint),
  (1, 'D', 'Para compilar más rápido', 0::smallint),
  -- Opciones Encuentro 2
  (2, 'A', 'Un registro de las llamadas activas al momento del error', 2::smallint),
  (2, 'B', 'Una lista de variables globales', 1::smallint),
  (2, 'C', 'Un mensaje del sistema operativo', 0::smallint),
  (2, 'D', 'Una técnica de compilación', 0::smallint),
  -- Opciones Encuentro 3
  (3, 'A', 'Reproducir el bug de forma consistente antes de intentar arreglarlo', 2::smallint),
  (3, 'B', 'Cambiar varias cosas a la vez para que el bug desaparezca', 0::smallint),
  (3, 'C', 'Añadir prints por todo el código sin plan', 1::smallint),
  (3, 'D', 'Ignorar el bug si no vuelve a pasar', 0::smallint)
) AS o(numero_encuentro, letra, texto, calidad)
  ON e.numero = o.numero_encuentro;
