# SysQuest — Estado actual (archivo vivo)

*Se actualiza al final de CADA sesión de trabajo (2 minutos). Va junto al Contexto Maestro al abrir un chat nuevo. Mantenerlo corto: si crece, mover lo antiguo a la bitácora.*

**Última actualización:** 29-sep-2026
**Último commit conocido:** `33d9877` — feat: eliminar cuenta en perfil (paso 4c)

---

## Hecho

- MVP funcionando: auth, quest/encuentros, combate por turnos, Mi Progreso (ver Maestro §3).
- Diccionario de datos v2 corregido (`V2SysQuest_Diccionario_de_Datos.md`).
- Auditoría de dominio e infraestructura realizada (hallazgos en Maestro §3b) — **4 arreglos aplicados**: `calidad` corregidos, `orderBy: 'letra ASC'`, `vida_enemigo` unificado, `PRAGMA foreign_keys = ON`.
- GitHub Student verificado (Jhony); Copilot Student activo en VS Code (créditos cerca del límite, usar con cuidado).
- Antigravity instalado y configurado como alternativa a Copilot cuando se agoten los créditos.
- `AGENTS.md` unificado en la raíz del repo (app Flutter + backend futuro) — es la fuente que leen Copilot y Antigravity. Referenciado desde `.agents/rules/sysquest-context.md` y desde `.github/copilot-instructions.md`.
- **Paso 1:** bug del número de daño flotante corregido.
- **Paso 2:** autenticación completa (registro/login validados) + sesión persistente (`shared_preferences`) + `AuthGate`.
- **Paso 3:** menú principal tras el login (quest del sistema / nueva quest IA / progreso / cerrar sesión).
- **Paso 4a:** perfil — ver y editar (nombre, apellido, usuario). Commit `ddc4810`.
- **Paso 4b:** cambiar contraseña, con las 5 validaciones (actual correcta, reglas de la nueva, distinta a la actual, confirmación coincide, guardado). Commit `7ebeace`.
- **Paso 4c:** eliminar cuenta, borrado transaccional (partida → progreso_usuario → personaje → usuario) + cierre de sesión + vuelta al login. Commit `33d9877`.
- Generación de quests con IA — base de dominio (A1: puerto + caso de uso + guardado transaccional; A2: `StubQuestGenerator` falso registrado en `main.dart`; A3: pantalla de tema libre conectada al combate).
- Revisión conjunta con el docente y Andrés de HU/CU, arquitectura y proceso Git (28-sep): ver "Decisiones cerradas" abajo.
- NotebookLM con fuentes cargadas (pendiente de refrescar con lo último, ver "Siguiente").

## En curso

- Proyecto Supabase `sysquest` en creación (29-sep): organización creada, proyecto en aprovisionamiento.
- Revisar un cambio sin commitear en `lib/presentation/theme/app_theme.dart` (ajuste de colores de fondo, hecho por Jhony; falta confirmar el diff completo y commitear).
- Reparto de repos `frontend`/`backend`: **resuelto verbalmente por el docente (29-sep)** — todo va al repo `backend` por ahora; se reorganiza antes de la expo, mientras se integra la interfaz.

## Decisiones cerradas (28-sep-2026, revisión HU/CU con el docente y Andrés)

1. **Nivel:** `nivel = 1 + floor(xp_total / 100)`. XP inicial 0, victoria +50, derrota +10. Coincide con el prototipo actual; se formaliza en HU-09/CU-09.
2. **Timeout de IA:** la Edge Function tiene un límite total de 10s; si el proveedor no responde correctamente, se activa fallback automático. Sin reintentos hacia el estudiante. El fallo se registra en logs.
3. **Origen del fallback:** banco curado y versionado de quests en Postgres/Supabase (por categoría, tema y dificultad). El `StubQuestGenerator` local queda solo para pruebas offline del prototipo, no es la fuente oficial del fallback.
4. **Enum `fuente_generacion`:** tres valores únicos en toda la pila (BD, API, Flutter, HU/CU): `AI`, `FALLBACK`, `DOCENTE`. Reemplaza a `manual`/`ia` que usa hoy el prototipo local.
5. **Vida del jugador y reanudación:** `partida` persiste `vida_jugador_actual`, `vida_enemigo_actual`, `encuentro_actual`, `updated_at`. La vida del jugador se conserva toda la quest; la del enemigo se reinicia por encuentro. **Es la decisión con más impacto**: sin esto no hay reanudación real ni resultados auditables.
6. **Edición de quests con partidas activas:** no se edita en caliente. Editar crea una nueva versión; las partidas en curso siguen en la versión anterior, las nuevas parten de la versión publicada.

**Deuda declarada del prototipo local (SQLite):** hoy `calidad`/`fuente_generacion` no siguen este enum y la vida del jugador vive solo en memoria del controlador de combate. Se declara honestamente como deuda del prototipo offline (no se oculta) y se corrige cuando se construya el backend real, no antes.

## Siguiente

1. Confirmar y commitear (o revertir) el cambio pendiente en `app_theme.dart`.
2. **Backend real (prioridad de la semana, reemplaza la meta original de "solo esquema"):**
   - Terminar de crear el proyecto Supabase (nombre correcto, región, contraseña guardada fuera del repo).
   - Copiar `Project URL`, `anon key`, `service_role key` (Project Settings → Data API / API Keys) y guardarlas fuera del repo.
   - `supabase init` en el repo `backend`, carpeta `supabase/`.
   - Esquema Postgres con las 6 decisiones cerradas incorporadas.
   - Primer endpoint (Edge Function) de login/registro con JWT de Supabase Auth, con `.env`/`.env.example`, probado en Postman — Flutter nunca llama a Supabase directo, siempre pasa por este backend. Esto es lo que pide la Guía de Primera Review Técnica (demo end-to-end, capas separadas, Postman, sin frontend conectado directo a la BD).
3. Paso 5: generar APK instalable (después del backend mínimo).
4. Refrescar NotebookLM: subir `AGENTS.md`, reemplazar el código exportado y eliminar fuentes obsoletas (maestro original, maestro v2).
5. Roadmap ampliado del prototipo Flutter (no urgente, después del backend):
   - Paso 6: 6 quests preset (Debug, Database, Algorithm, Network, Architecture, Cyber) con contenido pre-cargado — resuelve la diferencia entre el informe V1.13 ("6 minijuegos") y el motor único ya construido.
   - Paso 7: continuar partida guardada (depende de la decisión 5).
   - Paso 8: menú de pausa en el combate.
   - Paso 9: mostrar puntuación al final de la partida.
   - Paso 10: botón/pantalla de tutorial o ayuda para jugadores nuevos.
   - Paso 11 (backend): moderación de temas para la generación con IA — la Edge Function antepone un system prompt fijo (no editable desde Flutter) que reformula o rechaza temas con groserías, fuera de alcance académico o demasiado ambiguos, antes de llamar al proveedor de IA.

## Decisiones pendientes

- Formato JSON exacto que debe devolver la IA (encuentros, opciones, calidad) — para cuando se reemplace el `StubQuestGenerator` por el adaptador real.
- Proveedor de IA (Gemini vs Groq) — decisión del backend.
- Qué hacer con la suscripción de Gemini revendida (verificar / reemplazar por la promoción estudiantil).
- Confirmar que Andrés verificó su cuenta de GitHub Student.
- OmniRoute: **resuelto** — se desinstaló, no estaba en el repo, no hay key comprometida en el historial.
- Corregir encabezados/códigos inconsistentes en HU-04, CU-04, CU-08, CU-09 (pendiente según la revisión del 28-sep).
- Normalizar ramas Git: `feature/SYSQ-XX-descripcion` → `dev` → `preprod` → `main`, con PRs de reconciliación transparentes (main está 17 commits por delante de dev/preprod; no se debe simular historial falso).

## Notas para el próximo chat

- No rediseñar la arquitectura hexagonal; ya funciona.
- Pegar texto, no PDFs ni capturas.
- Si se quiere revisar código: pegar el `git diff` o el `codigo_domain_infra.txt`.
- El backend debe seguir 12 factores clave: config en variables de entorno (nunca hardcodeada), backing services intercambiables por config, logs como flujo de eventos.
- Flutter NUNCA llama a Supabase/Postgres directo: siempre pasa por el backend (Edge Functions). Esto fue una corrección explícita del docente.

---

## Bitácora de decisiones y sesiones

| Fecha | Qué se decidió / hizo | Motivo |
|---|---|---|
| 24-sep-2026 | Se crea el protocolo de continuidad (Maestro v3 + este archivo + script de exportación) | Un chat anterior se cortó por límite de imágenes y no hubo forma de migrar el contexto |
| 24-sep-2026 | Copilot Student se usa solo en modo Auto; el razonamiento largo se hace en el chat de Claude | Sin selector manual de modelos desde jun-2026 |
| 24-sep-2026 | La suscripción Gemini revendida se trata como "sin verificar" y sin copias únicas de archivos | Señales de riesgo en el anuncio |
| 24-sep-2026 | Meta de la semana: base de datos Supabase desplegada (esquema + datos de prueba + RLS) para mostrar al docente | El docente pidió avance en base de datos externa |
| 25/26-sep-2026 | Pasos 1, 2, 3, 4a completados (bug de daño, auth + sesión persistente, menú principal, perfil ver/editar) | Avance de roadmap, trabajado con Copilot |
| 27/28-sep-2026 | Se crea `AGENTS.md` unificado (app Flutter + backend futuro) como fuente que leen los agentes; se configura Antigravity como alternativa a Copilot | Copilot llegó al 90% de créditos; se necesitaba continuidad entre herramientas |
| 27/28-sep-2026 | Pasos 4b (cambiar contraseña) y 4c (eliminar cuenta) completados con Antigravity, siguiendo el mismo patrón (puerto → caso de uso → infraestructura → UI → tests) | Cierre del CRUD de perfil |
| 27/28-sep-2026 | Se detecta y resuelve el riesgo de OmniRoute (gateway local corriendo sin autenticación); se desinstala | Ya estaba marcado como abandonado en el Maestro; no debía seguir instalado |
| 27/28-sep-2026 | Se decide resolver la diferencia entre el informe V1.13 ("6 minijuegos") y el motor único ya construido con 6 "quests preset" (una por categoría) en vez de reescribir el informe | No retrasa el código, mantiene el informe entregado como válido, es defendible ante el docente |
| 28-sep-2026 | Revisión conjunta HU/CU con el docente y Andrés: se cierran 6 decisiones (nivel, timeout IA, origen fallback, enum fuente_generacion, persistencia de vida/reanudación, versionado de quests editadas) | Alinear HU/CU, Jira y arquitectura en el mismo lenguaje antes de seguir |
| 29-sep-2026 | Se confirma que 4b y 4c quedaron pusheados (`33d9877`); queda un cambio sin commitear en `app_theme.dart` por revisar | Verificación de continuidad tras trabajar con varias IAs en paralelo |
| 29-sep-2026 | Se replantea la prioridad de la semana: de "solo esquema Supabase" a "backend mínimo end-to-end con JWT y Postman", según la Guía de Primera Review Técnica | La guía exige demo funcional front+backend+BD, capas separadas y Postman, no solo una base de datos desplegada |
| 29-sep-2026 | El docente confirma verbalmente: todo al repo `backend` por ahora, reorganización frontend/backend antes de la expo | Evitar bloquear el trabajo mientras se define el reparto final |
| 29-sep-2026 | Se crea el proyecto Supabase `sysquest` (organización + proyecto en aprovisionamiento) | Primer paso del backend real |
| _(fecha)_ | _(siguiente entrada)_ | |