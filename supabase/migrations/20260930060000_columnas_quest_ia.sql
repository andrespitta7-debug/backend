-- SysQuest — Columnas adicionales para el contrato de quests generadas por IA
-- Migración: 20260930060000_columnas_quest_ia.sql
-- Propósito: agregar las columnas que el contrato JSON de la generación
-- de quests con IA requiere y que no existían en el esquema inicial:
--   - encuentro.enemigo       (nombre del enemigo, para mostrar en combate)
--   - encuentro.codigo        (snippet de código opcional, para categorías técnicas)
--   - opcion_encuentro.explicacion (feedback al usuario sobre por qué esa calidad)
-- Todas nullable: no rompen datos existentes ni el flujo actual.

-- =========================================================
-- 1. encuentro: agregar enemigo y codigo
-- =========================================================
alter table encuentro
  add column if not exists enemigo text;

alter table encuentro
  add column if not exists codigo text;

comment on column encuentro.enemigo is 'Nombre del enemigo en este encuentro, generado por la IA. Se muestra en la pantalla de combate.';

comment on column encuentro.codigo is 'Snippet de código opcional para el enunciado (categorías técnicas como debug/algorithm). Null si no aplica.';

-- =========================================================
-- 2. opcion_encuentro: agregar explicacion
-- =========================================================
alter table opcion_encuentro
  add column if not exists explicacion text;

comment on column opcion_encuentro.explicacion is 'Explicación breve (feedback al usuario) de por qué la opción tiene esa calidad. Generada por la IA.';