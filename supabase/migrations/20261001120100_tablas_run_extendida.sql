-- SysQuest — Tablas de runs públicas y caché narrativa
-- Migración: 20261001120100_tablas_run_extendida.sql
-- Propósito: Crear tablas para caché de pools narrativos y runs públicas compartibles,
-- agregar la clave foránea en partida, habilitar RLS y definir políticas de seguridad.

-- =========================================================
-- 1. Tabla de caché de pools narrativos por tema+categoría+dificultad
-- =========================================================
create table if not exists public.pool_narrativo_cache (
  id uuid primary key default gen_random_uuid(),
  tema text not null,
  categoria public.categoria_quest not null,
  dificultad public.dificultad_nivel not null,
  pool jsonb not null,
  usos integer not null default 0 check (usos >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tema, categoria, dificultad)
);

comment on table public.pool_narrativo_cache is 'Caché de pools narrativos por (tema, categoría, dificultad). Permite reutilizar pools entre usuarios y reducir llamadas a la IA.';

drop trigger if exists trg_pool_narrativo_cache_updated_at on public.pool_narrativo_cache;
create trigger trg_pool_narrativo_cache_updated_at
  before update on public.pool_narrativo_cache
  for each row execute function public.set_updated_at();

create index if not exists idx_pool_narrativo_cache_busqueda
  on public.pool_narrativo_cache (tema, categoria, dificultad);

-- =========================================================
-- 2. Tabla de runs públicas compartibles
-- =========================================================
create table if not exists public.run_publica (
  id uuid primary key default gen_random_uuid(),
  id_quest_original uuid not null references public.quest(id) on delete cascade,
  id_usuario_original uuid references public.usuario(id) on delete set null,
  tema text not null,
  categoria public.categoria_quest not null,
  dificultad public.dificultad_nivel not null,
  semilla bigint not null,
  pool_narrativo_inicial jsonb not null,
  usos integer not null default 0 check (usos >= 0),
  score_maximo integer not null default 0 check (score_maximo >= 0),
  enemigos_derrotados_max integer not null default 0 check (enemigos_derrotados_max >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.run_publica is 'Runs compartibles entre usuarios. Cada run pública es una quest + pool narrativo + semilla que otros jugadores pueden adoptar.';

drop trigger if exists trg_run_publica_updated_at on public.run_publica;
create trigger trg_run_publica_updated_at
  before update on public.run_publica
  for each row execute function public.set_updated_at();

create index if not exists idx_run_publica_usos
  on public.run_publica (usos desc, updated_at desc);

create index if not exists idx_run_publica_tema
  on public.run_publica (tema);

-- =========================================================
-- 3. FK de partida a run_publica
-- =========================================================
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'partida_id_run_publica_fkey'
  ) then
    alter table public.partida
      add constraint partida_id_run_publica_fkey
      foreign key (id_run_publica) references public.run_publica(id)
      on delete set null;
  end if;
end $$;

-- =========================================================
-- 4. SEGURIDAD / ROW LEVEL SECURITY (RLS)
-- =========================================================
alter table public.pool_narrativo_cache enable row level security;
alter table public.run_publica enable row level security;

-- Policies para pool_narrativo_cache:
-- Solo service_role puede escribir/leer (es un caché interno)
drop policy if exists "pool_narrativo_cache_service_only" on public.pool_narrativo_cache;
create policy "pool_narrativo_cache_service_only"
  on public.pool_narrativo_cache
  for all
  to service_role
  using (true)
  with check (true);

-- Policies para run_publica:
-- Cualquier usuario autenticado puede leer las runs públicas
drop policy if exists "run_publica_lectura_publica" on public.run_publica;
create policy "run_publica_lectura_publica"
  on public.run_publica
  for select
  to authenticated
  using (true);

-- Solo el dueño original puede actualizar los metadatos
drop policy if exists "run_publica_update_owner" on public.run_publica;
create policy "run_publica_update_owner"
  on public.run_publica
  for update
  to authenticated
  using (id_usuario_original = auth.uid())
  with check (id_usuario_original = auth.uid());

-- Insert: cualquier usuario autenticado puede publicar una run
drop policy if exists "run_publica_insert_authenticated" on public.run_publica;
create policy "run_publica_insert_authenticated"
  on public.run_publica
  for insert
  to authenticated
  with check (true);
