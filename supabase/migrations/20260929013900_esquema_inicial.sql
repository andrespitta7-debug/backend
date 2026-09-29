-- SysQuest — Esquema inicial de Postgres (Supabase)
-- Incorpora las 6 decisiones cerradas el 28-sep-2026 (revisión HU/CU
-- con el docente y Andrés). Ver docs/ESTADO_ACTUAL.md.
--
-- Diferencias clave frente al prototipo SQLite local:
-- - IDs uuid (gen_random_uuid()), no TEXT generado en Dart.
-- - Autenticación vía Supabase Auth (auth.users); esta tabla `usuario`
--   es el perfil de dominio, enlazado 1 a 1 por id. NO se guarda
--   password_hash aqui.
-- - Enums reales de Postgres en vez de TEXT sin CHECK.
-- - RLS activado desde el inicio en cada tabla.

-- =========================================================
-- EXTENSIONES
-- =========================================================
create extension if not exists "pgcrypto";

-- =========================================================
-- ENUMS
-- =========================================================

-- Decision 4: fuente_generacion unico en toda la pila (BD, API, Flutter, HU/CU)
create type fuente_generacion as enum ('AI', 'FALLBACK', 'DOCENTE');

create type categoria_quest as enum (
  'debug', 'database', 'algorithm', 'network', 'architecture', 'cyber', 'libre'
);

create type dificultad_nivel as enum ('facil', 'medio', 'dificil');

create type tipo_encuentro as enum ('normal', 'jefe');

create type estado_partida as enum ('en_curso', 'ganada', 'perdida');

-- =========================================================
-- 1. usuario
-- Perfil de dominio. La autenticacion (password, email) vive en
-- auth.users (Supabase Auth). id = auth.users.id (1 a 1).
-- =========================================================
create table usuario (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre_usuario text not null unique,
  nombre text,
  apellido text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table usuario is 'Perfil de dominio del jugador. El email y la contraseña los maneja Supabase Auth (auth.users).';

-- =========================================================
-- 2. personaje
-- Avatar del jugador. Un personaje por usuario.
-- =========================================================
create table personaje (
  id uuid primary key default gen_random_uuid(),
  id_usuario uuid not null unique references usuario(id) on delete cascade,
  nombre text,
  genero text check (genero in ('masculino', 'femenino')),
  skin text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 3. progreso_usuario
-- Estadisticas acumuladas. Se crea junto con el usuario.
-- =========================================================
create table progreso_usuario (
  id uuid primary key default gen_random_uuid(),
  id_usuario uuid not null unique references usuario(id) on delete cascade,
  nivel integer not null default 1,
  xp_total integer not null default 0,
  quests_completadas integer not null default 0,
  victorias integer not null default 0,
  derrotas integer not null default 0,
  partidas_jugadas integer not null default 0,
  updated_at timestamptz not null default now()
);

-- Decision 1: nivel = 1 + floor(xp_total / 100). Se aplica en la capa de
-- backend (Edge Function / caso de uso), no como trigger, para mantener
-- la regla de negocio explicita y testeable en codigo, no oculta en SQL.

-- =========================================================
-- 4. quest
-- Aventura tematica compuesta por encuentros ordenados.
-- Decision 6: versionado. Una quest editada crea una fila nueva con
-- version incrementada; las partidas en curso siguen referenciando la
-- version con la que empezaron (via encuentro.id_quest -> quest.id).
-- =========================================================
create table quest (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  tema text,
  categoria categoria_quest not null default 'libre',
  dificultad dificultad_nivel not null default 'facil',
  descripcion text,
  fuente_generacion fuente_generacion not null default 'DOCENTE',
  version integer not null default 1,
  id_quest_original uuid references quest(id),
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

comment on column quest.id_quest_original is 'Si esta quest es una edicion de otra, apunta a la version 1 original. Permite agrupar todas las versiones de una misma quest.';
comment on column quest.activa is 'false cuando esta quest fue reemplazada por una version mas nueva. Las partidas viejas la siguen usando igual.';

-- =========================================================
-- 5. encuentro
-- Un enemigo con una pregunta dentro de una quest.
-- =========================================================
create table encuentro (
  id uuid primary key default gen_random_uuid(),
  id_quest uuid not null references quest(id) on delete cascade,
  numero integer not null,
  pregunta text not null,
  dificultad dificultad_nivel not null default 'facil',
  tipo_encuentro tipo_encuentro not null default 'normal',
  vida_enemigo integer not null default 50 check (vida_enemigo > 0),
  created_at timestamptz not null default now(),
  unique (id_quest, numero)
);

-- =========================================================
-- 6. opcion_encuentro
-- Las cuatro respuestas posibles de un encuentro.
-- =========================================================
create table opcion_encuentro (
  id uuid primary key default gen_random_uuid(),
  id_encuentro uuid not null references encuentro(id) on delete cascade,
  letra text not null check (letra in ('A', 'B', 'C', 'D')),
  texto text not null,
  calidad smallint not null check (calidad in (0, 1, 2)),
  unique (id_encuentro, letra)
);

comment on column opcion_encuentro.calidad is '2 = correcta y completa (critico); 1 = correcta pero debil (dano normal); 0 = incorrecta (contraataque)';

-- =========================================================
-- 7. partida
-- Registro de un combate jugado sobre una quest.
-- Decision 5 (la de mayor impacto): persistir el estado real para
-- poder reanudar sin perder progreso y auditar resultados.
-- =========================================================
create table partida (
  id uuid primary key default gen_random_uuid(),
  id_usuario uuid not null references usuario(id) on delete cascade,
  id_quest uuid not null references quest(id),
  estado estado_partida not null default 'en_curso',
  encuentro_actual integer not null default 0,
  vida_jugador_actual integer not null default 100 check (vida_jugador_actual >= 0),
  vida_enemigo_actual integer,
  score integer not null default 0,
  xp_obtenida integer not null default 0,
  tiempo_segundos integer not null default 0,
  resultado estado_partida,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  updated_at timestamptz not null default now()
);

comment on column partida.vida_jugador_actual is 'Se conserva durante toda la quest (decision 5). No se reinicia entre encuentros.';
comment on column partida.vida_enemigo_actual is 'Se reinicia al pasar al siguiente encuentro (decision 5). Null si la partida aun no empezo el combate.';

create index idx_partida_usuario_en_curso
  on partida (id_usuario)
  where estado = 'en_curso';

comment on index idx_partida_usuario_en_curso is 'Acelera "ver mi partida sin terminar" (Paso 7 del roadmap Flutter).';

-- =========================================================
-- TRIGGERS: updated_at automatico
-- =========================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_usuario_updated_at before update on usuario
  for each row execute function set_updated_at();

create trigger trg_personaje_updated_at before update on personaje
  for each row execute function set_updated_at();

create trigger trg_progreso_updated_at before update on progreso_usuario
  for each row execute function set_updated_at();

create trigger trg_partida_updated_at before update on partida
  for each row execute function set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY
-- Activado desde el inicio (correccion explicita del docente:
-- el front nunca debe hablar directo con la base de datos, y si
-- alguna vez lo hiciera por error, RLS es la ultima linea de defensa).
-- =========================================================

alter table usuario enable row level security;
alter table personaje enable row level security;
alter table progreso_usuario enable row level security;
alter table partida enable row level security;
alter table quest enable row level security;
alter table encuentro enable row level security;
alter table opcion_encuentro enable row level security;

-- Un usuario solo ve y edita su propio perfil, personaje, progreso y partidas.
create policy usuario_propio on usuario
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy personaje_propio on personaje
  for all using (auth.uid() = id_usuario) with check (auth.uid() = id_usuario);

create policy progreso_propio on progreso_usuario
  for all using (auth.uid() = id_usuario) with check (auth.uid() = id_usuario);

create policy partida_propia on partida
  for all using (auth.uid() = id_usuario) with check (auth.uid() = id_usuario);

-- Quest, encuentro y opcion_encuentro son contenido compartido: todo
-- usuario autenticado puede leerlos. Escribirlos queda reservado al
-- service_role (usado solo desde el backend/Edge Functions), por eso
-- no hay policy de INSERT/UPDATE para usuarios normales.
create policy quest_lectura on quest
  for select using (auth.role() = 'authenticated');

create policy encuentro_lectura on encuentro
  for select using (auth.role() = 'authenticated');

create policy opcion_encuentro_lectura on opcion_encuentro
  for select using (auth.role() = 'authenticated');
