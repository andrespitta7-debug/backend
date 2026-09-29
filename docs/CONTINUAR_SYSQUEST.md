# SysQuest — Contexto para continuar en otro chat/IA

Pega este archivo completo como PRIMER mensaje. Es texto plano, no imágenes,
para no chocar con límites de adjuntos. Luego dime en qué quieres seguir.

## Qué es el proyecto
App educativa gamificada (RPG de combate por turnos) para Ingeniería de
Sistemas, UdeC Fusagasugá. Equipo: Jhony Alejandro Palacio Gómez y Andrés
Orley Pitta Pardo. Arquitectura hexagonal en Flutter (domain/infrastructure/
presentation), hoy con SQLite local como prototipo offline. Se está
construyendo el backend real en Supabase (Postgres + Auth + Edge Functions).

## Reglas de trabajo que NO se deben romper
- No rediseñar la arquitectura hexagonal de Flutter, ya funciona.
- El frontend (Flutter) NUNCA debe llamar a Supabase/Postgres directo.
  Todo pasa por el backend (Edge Functions). Fue una corrección EXPLÍCITA
  del docente tras ver ese antipatrón en revisiones anteriores.
- Config (URLs, claves) siempre en variables de entorno (.env), nunca
  hardcodeada. .env NUNCA se sube al repo.
- Commits pequeños, uno por paso, mensajes en español (feat:/fix:/chore:).
- Cada sesión de trabajo termina actualizando docs/ESTADO_ACTUAL.md.

## Estado técnico actual (29-sep-2026)

### Frontend Flutter (repo "backend" en GitHub, nombre heredado, temporal
según indicación verbal del docente — todo va ahí por ahora, se reorganiza
antes de la expo)
- MVP funcionando: auth local, quest/encuentros, combate por turnos, perfil
  CRUD completo (ver/editar, cambiar contraseña, eliminar cuenta), menú
  principal, sesión persistente. Pasos 1 a 4c del roadmap, TODOS
  completados y pusheados. Último commit del frontend: 33d9877.
- Generación de quests con IA: base de dominio lista (puerto
  QuestGeneratorRepository, caso de uso GenerarQuestUseCase con
  validaciones, StubQuestGenerator falso para pruebas, pantalla de tema
  libre conectada al combate).
- AGENTS.md unificado en la raíz del repo: es la fuente que leen los
  agentes de código (Copilot, Antigravity, etc.). Contiene arquitectura,
  reglas de negocio, roadmap, reglas de Git.
- Herramientas usadas en rotación según créditos disponibles: GitHub
  Copilot en VS Code, Antigravity (alternativa cuando Copilot se agota),
  este chat (Claude) para diseño/decisiones/revisión.

### Backend Supabase (EN CONSTRUCCIÓN, esto es lo nuevo de hoy)
- Proyecto Supabase creado: `sysquest`, project-ref `jctulgfdweeurqbmugot`.
- Supabase CLI instalado (vía Scoop), logueado y linkeado al proyecto
  desde la máquina de Jhony, dentro de la carpeta del repo
  (C:\Users\jhony\sysquest_app\supabase\).
- Claves guardadas fuera del repo (archivo .txt local, a mover a un
  gestor de contraseñas): Project URL, publishable key (anon), secret
  key (service_role).
- PRIMERA MIGRACIÓN YA APLICADA con éxito (supabase db push):
  supabase/migrations/20260929013900_esquema_inicial.sql
  Crea las 7 tablas (usuario, personaje, progreso_usuario, quest,
  encuentro, opcion_encuentro, partida) en Postgres, con:
  - usuario ligado 1 a 1 a auth.users (Supabase Auth maneja password/JWT,
    NO se guarda password_hash en la tabla usuario).
  - Enums reales: fuente_generacion (AI/FALLBACK/DOCENTE), categoria_quest,
    dificultad_nivel, tipo_encuentro, estado_partida.
  - quest tiene version + id_quest_original (versionado, decisión 6).
  - partida tiene vida_jugador_actual, vida_enemigo_actual,
    encuentro_actual, updated_at (decisión 5, la más importante: permite
    reanudar partidas y auditar resultados).
  - RLS ACTIVADO en las 7 tablas: cada usuario solo ve/edita sus propias
    filas (usuario, personaje, progreso_usuario, partida); quest/
    encuentro/opcion_encuentro son de lectura pública para autenticados,
    solo el backend con service_role puede escribirlas.
- Confirmado visualmente en el Table Editor de Supabase: las 7 tablas
  existen con sus columnas y RLS activo (candado visible).
- PENDIENTE de hacer commit del archivo de migración en el repo
  (git add supabase/migrations/ ... ) — verificar si ya se hizo.

## Las 6 decisiones cerradas el 28-sep (revisión HU/CU con el docente y Andrés)
Ya incorporadas en el esquema SQL de arriba. Resumen:
1. Nivel = 1 + floor(xp_total / 100). XP: victoria +50, derrota +10.
2. Timeout de IA: 10s en la Edge Function, sin reintentos al estudiante,
   fallback automático si falla, se loguea el fallo.
3. Fallback = banco curado y versionado de quests en Postgres (no el
   StubQuestGenerator local, que es solo para pruebas offline).
4. Enum fuente_generacion único en toda la pila: AI / FALLBACK / DOCENTE.
5. (LA MÁS IMPORTANTE) partida persiste vida_jugador_actual,
   vida_enemigo_actual, encuentro_actual, updated_at, para reanudar sin
   perder estado.
6. Editar una quest con partidas activas crea una nueva versión; las
   partidas en curso siguen en la versión vieja.

## Por qué se prioriza el backend esta semana (no solo Flutter)
El docente compartió una "Guía de Primera Review Técnica" que exige DEMO
end-to-end real: frontend + backend + base de datos, con Postman probando
POST/GET/PUT con códigos HTTP, capas separadas (Controller/UseCase/
Repository), .env correcto, validación en la BD real. Penaliza
explícitamente "todo en una sola capa" y "frontend sin conexión al backend
real". Por eso NO basta con tener Supabase desplegado: hace falta al menos
UN endpoint real (Edge Function) que Flutter consuma por HTTP, nunca
llamando a Supabase directo.

## Ideas nuevas del usuario, ya ubicadas en el roadmap (no urgentes, después
del backend mínimo)
- Paso 6: 6 quests preset (Debug, Database, Algorithm, Network,
  Architecture, Cyber) — resuelve que el informe académico V1.13 dice
  "6 minijuegos" y el código ya es un motor único (decisión ya tomada:
  no se reescribe el informe, se implementan las 6 categorías como quests
  preset dentro del motor único).
- Paso 7: continuar partida guardada (depende de la decisión 5, ya en el
  esquema).
- Paso 8: menú de pausa en combate.
- Paso 9: mostrar puntuación al final.
- Paso 10: tutorial/ayuda para jugadores nuevos.
- Paso 11: moderación de temas en la generación con IA — la Edge Function
  antepone un system prompt fijo (nunca editable desde Flutter) que
  reformula o rechaza temas con groserías o fuera de alcance académico,
  antes de llamar al proveedor de IA (Gemini/Groq, aún sin decidir cuál).

## Siguiente paso inmediato (justo donde se quedó)
1. Confirmar/hacer commit de supabase/migrations/20260929013900_esquema_inicial.sql
   si no se hizo ya.
2. Segunda migración: datos de prueba (una quest tipo DOCENTE con 3
   encuentros y sus opciones, respetando el esquema con uuid y enums, NO
   los ids legibles tipo "quest-001" que usaba el SQLite viejo).
3. Primer endpoint real: Edge Function de login/registro usando Supabase
   Auth, devolviendo JWT, probado en Postman, con .env/.env.example, para
   cumplir la Guía de Review 1.
4. Después: que Flutter llame a ese endpoint en vez de su auth local
   (esto es un cambio grande, se planea aparte, no se improvisa).

## Pendientes / decisiones sin cerrar
- Proveedor de IA real (Gemini vs Groq) para el backend.
- Formato JSON exacto que debe devolver la IA al generar una quest.
- Confirmar que Andrés verificó su GitHub Student.
- Reparto final frontend/backend entre los 2 repos de GitHub (el docente
  dijo verbalmente que por ahora todo va a "backend", se reorganiza antes
  de la expo).
- Corregir encabezados/códigos inconsistentes en HU-04, CU-04, CU-08,
  CU-09 (mencionado en la revisión del 28-sep, aún no hecho).
- Normalizar ramas Git: hoy todo se hace directo en main, 17 commits por
  delante de dev/preprod; se acordó normalizar con
  feature/SYSQ-XX-descripcion -> dev -> preprod -> main, sin fingir
  historial falso.

## Cómo seguir trabajando (protocolo)
1. Diseño/decisiones en un chat de IA (Claude u otra).
2. Implementación con Copilot o Antigravity en VS Code, con prompts
   concretos paso a paso (no bloques gigantes).
3. Revisar el git diff o la salida de comandos antes de dar por bueno un
   paso.
4. Commit pequeño y específico.
5. Actualizar docs/ESTADO_ACTUAL.md al cerrar cada sesión.

Documentos de referencia en el repo (carpeta docs/):
- SysQuest_Contexto_Maestro_v3.md (visión y arquitectura completa)
- ESTADO_ACTUAL.md (bitácora viva, más detallado que este resumen)
- V2SysQuest_Diccionario_de_Datos.md (esquema del SQLite local, distinto
  al de Supabase)
