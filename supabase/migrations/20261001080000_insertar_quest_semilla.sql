-- SysQuest — Inserción de quest semilla de prueba (Programación Básica)
-- Migración: 20261001080000_insertar_quest_semilla.sql
-- Propósito: Insertar la quest de programación básica en Postgres para que
-- exista como dato semilla del docente con un UUID fijo ('00000000-0000-0000-0000-000000000001'),
-- permitiendo que las partidas guardadas en backend hagan referencia a un id_quest válido.
-- Idempotente: Si la quest con dicho id ya existe, no realiza inserciones duplicadas.

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
    '00000000-0000-0000-0000-000000000001'::uuid,
    'Quest de Programación Básica',
    'Variables, condicionales y funciones',
    'debug'::categoria_quest,
    'facil'::dificultad_nivel,
    'Repasa conceptos básicos de programación con ejemplos simples.',
    'DOCENTE'::fuente_generacion,
    1,
    NULL,
    true
  WHERE NOT EXISTS (
    SELECT 1 FROM quest
    WHERE id = '00000000-0000-0000-0000-000000000001'::uuid
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
    vida_enemigo,
    enemigo,
    codigo
  )
  SELECT
    datos.id_encuentro,
    nueva_quest.id,
    datos.numero,
    datos.pregunta,
    datos.dificultad::dificultad_nivel,
    datos.tipo_encuentro::tipo_encuentro,
    datos.vida_enemigo,
    datos.enemigo,
    datos.codigo
  FROM nueva_quest,
  (VALUES
    (
      '00000000-0000-0000-0000-000000000101'::uuid,
      1,
      '¿Para qué sirve una variable en un programa?',
      'facil',
      'normal',
      30,
      'Bug del Alcance',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000102'::uuid,
      2,
      '¿Qué hace una condicional if en programación?',
      'medio',
      'normal',
      40,
      'Guardián del If',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000103'::uuid,
      3,
      '¿Qué es una función en programación?',
      'dificil',
      'jefe',
      70,
      'Dragón de la Recursión',
      NULL::text
    )
  ) AS datos(id_encuentro, numero, pregunta, dificultad, tipo_encuentro, vida_enemigo, enemigo, codigo)
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
  (1, 'A', 'Para guardar un valor para usarlo después', 2::smallint),
  (1, 'B', 'Para hacer que el programa se detenga', 0::smallint),
  (1, 'C', 'Para crear una imagen en pantalla', 0::smallint),
  (1, 'D', 'Para borrar información del programa', 1::smallint),
  -- Opciones Encuentro 2
  (2, 'A', 'Evalúa una condición y decide qué hacer según el resultado', 2::smallint),
  (2, 'B', 'Guarda un valor en memoria', 1::smallint),
  (2, 'C', 'Crea una nueva ventana del sistema', 0::smallint),
  (2, 'D', 'Borra el código del programa', 0::smallint),
  -- Opciones Encuentro 3
  (3, 'A', 'Un bloque de instrucciones reutilizable para realizar una tarea', 2::smallint),
  (3, 'B', 'Un tipo de dato que solo guarda números', 0::smallint),
  (3, 'C', 'Una base de datos pequeña', 0::smallint),
  (3, 'D', 'Una pantalla de inicio del programa', 1::smallint)
) AS o(numero_encuentro, letra, texto, calidad)
  ON e.numero = o.numero_encuentro;
