-- SysQuest — Columnas de run extendida en partida
-- Migración: 20261001120000_columnas_partida_run_extendida.sql
-- Propósito: Agregar soporte para runs extendidas / roguelike procedimental
-- (semilla, pool narrativo, preguntas extra, ronda, enemigos derrotados, id_run_publica)
-- y agregar el estado 'retirado' a estado_partida.

-- Agregar el valor 'retirado' al enum estado_partida si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'retirado'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'estado_partida')
  ) THEN
    ALTER TYPE public.estado_partida ADD VALUE 'retirado';
  END IF;
END $$;

-- Agregar columnas nuevas a partida
alter table public.partida
  add column if not exists semilla bigint not null default 0;

alter table public.partida
  add column if not exists pool_narrativo jsonb;

alter table public.partida
  add column if not exists preguntas_extra jsonb;

alter table public.partida
  add column if not exists ronda integer not null default 1
    check (ronda > 0);

alter table public.partida
  add column if not exists enemigos_derrotados integer not null default 0
    check (enemigos_derrotados >= 0);

alter table public.partida
  add column if not exists id_run_publica uuid;

comment on column public.partida.semilla is 'Semilla aleatoria que controla la reproducibilidad de la run (barajado de encuentros, selección de variantes narrativas).';
comment on column public.partida.pool_narrativo is 'Pool actual de variantes narrativas del jugador. Estructura: { intro: [...], entre_combates: [...], ..., usadas: {...}, eventos_desde_regeneracion: int }.';
comment on column public.partida.preguntas_extra is 'Preguntas adicionales generadas por IA para enemigos con más HP que el pool inicial.';
comment on column public.partida.ronda is 'Número de ronda actual de la run. Empieza en 1.';
comment on column public.partida.enemigos_derrotados is 'Total de enemigos derrotados en toda la run.';
comment on column public.partida.id_run_publica is 'Si la run fue adoptada de una run pública, referencia a esa run. Null si es una run original.';
