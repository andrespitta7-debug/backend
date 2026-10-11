-- SysQuest — Inserción de quests semilla de prueba 2 y 3 (Matemáticas Básicas e Historia Universal)
-- Migración: 20261010000000_insertar_quests_semilla_2_y_3.sql
-- Propósito: Insertar quests semilla universales para que el cliente pueda ofrecer
-- "Jugar quest de respaldo" cuando la IA presente fallos (rate limit, timeout, etc.).
-- Idempotente: Si las quests con dichos UUIDs ya existen, no realiza inserciones duplicadas.

-- =====================================================================
-- QUEST SEMILLA 2: Matemáticas Básicas ('00000000-0000-0000-0000-000000000002')
-- =====================================================================
WITH nueva_quest_2 AS (
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
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Aventura Numérica',
    'Aritmética, fracciones y geometría básica',
    'libre'::categoria_quest,
    'facil'::dificultad_nivel,
    'Repasa conceptos matemáticos fundamentales.',
    'DOCENTE'::fuente_generacion,
    1,
    NULL,
    true
  WHERE NOT EXISTS (
    SELECT 1 FROM quest
    WHERE id = '00000000-0000-0000-0000-000000000002'::uuid
  )
  RETURNING id
),
nuevos_encuentros_2 AS (
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
    nueva_quest_2.id,
    datos.numero,
    datos.pregunta,
    datos.dificultad::dificultad_nivel,
    datos.tipo_encuentro::tipo_encuentro,
    datos.vida_enemigo,
    datos.enemigo,
    datos.codigo
  FROM nueva_quest_2,
  (VALUES
    (
      '00000000-0000-0000-0000-000000000201'::uuid,
      1,
      '¿Cuánto es 7 × 8?',
      'facil',
      'normal',
      45,
      'Duende de las Tablas',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000202'::uuid,
      2,
      '¿Qué fracción equivale a 0.5?',
      'facil',
      'normal',
      50,
      'Espectro Fraccionario',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000203'::uuid,
      3,
      '¿Cuál es el área de un cuadrado de lado 5?',
      'facil',
      'jefe',
      100,
      'Dragón Geométrico',
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
  calidad,
  explicacion
)
SELECT
  gen_random_uuid(),
  e.id,
  o.letra,
  o.texto,
  o.calidad,
  o.explicacion
FROM nuevos_encuentros_2 e
JOIN (VALUES
  -- Encuentro 1
  (1, 'A', '56', 2::smallint, 'Correcto: 7 × 8 = 56.'),
  (1, 'B', '54', 0::smallint, 'Incorrecto: 54 es el producto de 6 × 9.'),
  (1, 'C', '48', 0::smallint, 'Incorrecto: 48 es el producto de 6 × 8.'),
  (1, 'D', '64', 1::smallint, 'Cercano pero incorrecto: 64 es 8 × 8.'),
  -- Encuentro 2
  (2, 'A', '1/2', 2::smallint, 'Correcto: 1 dividido entre 2 es exactamente 0.5.'),
  (2, 'B', '1/3', 1::smallint, 'Incorrecto: 1/3 equivale aproximadamente a 0.333.'),
  (2, 'C', '2/3', 0::smallint, 'Incorrecto: 2/3 equivale aproximadamente a 0.666.'),
  (2, 'D', '1/4', 0::smallint, 'Incorrecto: 1/4 equivale a 0.25.'),
  -- Encuentro 3 (Jefe)
  (3, 'A', '25', 2::smallint, 'Correcto: el área del cuadrado es lado al cuadrado (5 × 5 = 25).'),
  (3, 'B', '20', 0::smallint, 'Incorrecto: 20 corresponde al perímetro (4 × 5), no al área.'),
  (3, 'C', '10', 0::smallint, 'Incorrecto: 10 es el doble del lado (5 + 5).'),
  (3, 'D', '30', 1::smallint, 'Incorrecto: cálculo fuera de la fórmula geométrica.')
) AS o(numero_encuentro, letra, texto, calidad, explicacion)
  ON e.numero = o.numero_encuentro;

-- =====================================================================
-- QUEST SEMILLA 3: Historia Universal ('00000000-0000-0000-0000-000000000003')
-- =====================================================================
WITH nueva_quest_3 AS (
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
    '00000000-0000-0000-0000-000000000003'::uuid,
    'Crónicas del Tiempo',
    'Eventos históricos universales',
    'libre'::categoria_quest,
    'facil'::dificultad_nivel,
    'Viaja por los grandes momentos de la historia.',
    'DOCENTE'::fuente_generacion,
    1,
    NULL,
    true
  WHERE NOT EXISTS (
    SELECT 1 FROM quest
    WHERE id = '00000000-0000-0000-0000-000000000003'::uuid
  )
  RETURNING id
),
nuevos_encuentros_3 AS (
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
    nueva_quest_3.id,
    datos.numero,
    datos.pregunta,
    datos.dificultad::dificultad_nivel,
    datos.tipo_encuentro::tipo_encuentro,
    datos.vida_enemigo,
    datos.enemigo,
    datos.codigo
  FROM nueva_quest_3,
  (VALUES
    (
      '00000000-0000-0000-0000-000000000301'::uuid,
      1,
      '¿En qué año llegó el hombre a la Luna?',
      'facil',
      'normal',
      45,
      'Eco del Apolo',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000302'::uuid,
      2,
      '¿Qué civilización construyó las pirámides de Giza?',
      'facil',
      'normal',
      50,
      'Guardián del Nilo',
      NULL::text
    ),
    (
      '00000000-0000-0000-0000-000000000303'::uuid,
      3,
      '¿Quién escribió la Declaración de Independencia de EE.UU.?',
      'facil',
      'jefe',
      100,
      'Titán de la Libertad',
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
  calidad,
  explicacion
)
SELECT
  gen_random_uuid(),
  e.id,
  o.letra,
  o.texto,
  o.calidad,
  o.explicacion
FROM nuevos_encuentros_3 e
JOIN (VALUES
  -- Encuentro 1
  (1, 'A', '1969', 2::smallint, 'Correcto: la misión Apolo 11 alunizó el 20 de julio de 1969.'),
  (1, 'B', '1959', 1::smallint, 'Incorrecto: en 1959 la sonda soviética Luna 2 impactó la Luna, pero sin tripulación.'),
  (1, 'C', '1979', 0::smallint, 'Incorrecto: las misiones Apolo tripuladas concluyeron en 1972.'),
  (1, 'D', '1949', 0::smallint, 'Incorrecto: la carrera espacial comenzó formalmente en la década de 1950.'),
  -- Encuentro 2
  (2, 'A', 'Los egipcios', 2::smallint, 'Correcto: fueron erigidas durante el Imperio Antiguo de Egipto.'),
  (2, 'B', 'Los romanos', 0::smallint, 'Incorrecto: la civilización romana floreció siglos después.'),
  (2, 'C', 'Los griegos', 0::smallint, 'Incorrecto: los griegos construyeron monumentos como el Partenón.'),
  (2, 'D', 'Los mayas', 1::smallint, 'Incorrecto: los mayas construyeron pirámides en Mesoamérica, no en Giza.'),
  -- Encuentro 3 (Jefe)
  (3, 'A', 'Thomas Jefferson', 2::smallint, 'Correcto: Jefferson fue el autor principal del borrador en 1776.'),
  (3, 'B', 'George Washington', 1::smallint, 'Incorrecto: Washington fue el comandante militar y primer presidente.'),
  (3, 'C', 'Benjamin Franklin', 0::smallint, 'Incorrecto: Franklin formó parte del comité revisor, pero no fue el redactor principal.'),
  (3, 'D', 'Abraham Lincoln', 0::smallint, 'Incorrecto: Lincoln fue presidente durante la Guerra Civil en el siglo XIX.')
) AS o(numero_encuentro, letra, texto, calidad, explicacion)
  ON e.numero = o.numero_encuentro;
