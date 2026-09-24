# SysQuest — Estado actual (archivo vivo)

*Se actualiza al final de CADA sesión de trabajo (2 minutos). Va junto al Contexto Maestro al abrir un chat nuevo. Mantenerlo corto: si crece, mover lo antiguo a la bitácora.*

**Última actualización:** 24-sep-2026
**Último commit conocido:** `4c3ec18` — fix: reescribir gitignore sin BOM

---

## Hecho

- MVP funcionando: auth, quest/encuentros, combate por turnos, Mi Progreso (ver Maestro §3).
- Diccionario de datos v2 corregido (`V2SysQuest_Diccionario_de_Datos.md`).
- Auditoría de dominio e infraestructura realizada (hallazgos en Maestro §3b).
- GitHub Student verificado (Jhony) y Copilot Student activo en VS Code.
- `.github/copilot-instructions.md` creado.
- NotebookLM con 5 fuentes cargadas.
- **Paso 1 — Bug del daño flotante corregido.** El número sale en la barra correcta. Test de widget en `test/combate_damage_widget_test.dart`. Commit `c8b74e7`.
- **Paso 2 — Auth completa + sesión persistente.** `AuthRepository` con `obtenerPorId`, `existeEmail`, `existeNombreUsuario`. Casos de uso nuevos: `RestaurarSesionUseCase`, `CerrarSesionUseCase`. `RegistrarUsuarioUseCase` con validaciones completas. `SharedPreferencesSesionRepository` implementado. `SqliteAuthRepository` con transacción en registro. Tests en `test/auth_usecases_test.dart`. Commit `3e2f1af`.
- **Paso 3 — Menú principal tras login.** `MenuPrincipalScreen` con saludo, tres tarjetas y botón de cerrar sesión. `AuthGate` redirige al menú. Theme en `lib/presentation/theme/app_theme.dart`. Commit `c463a7f`.
- Tests: 32/32 pasan. `dart analyze`: sin issues.

## En curso

- **Paso 4 (siguiente):** Perfil CRUD — ver, editar, cambiar contraseña, eliminar cuenta.
- Arreglos de la auditoría (Maestro §3b) que siguen pendientes:
  - [ ] `calidad` corregidos en datos de prueba (`enc-001` opción D, `enc-003` opción D)
  - [ ] `orderBy: 'letra ASC'` en opciones
  - [ ] `vida_enemigo` unificado (default SQL 50 vs respaldo 30)
  - [ ] `PRAGMA foreign_keys = ON` vía `onConfigure`

## Siguiente

1. Ejecutar el Paso 4 (perfil CRUD) con el prompt preparado en el chat.
2. Paso 5: generar APK instalable.
3. Decidir esquema de Supabase (miércoles).
4. Actualizar el Maestro con la nueva regla de contraseña (8+, no 6).
5. Resolver contradicción "6 vs 8 caracteres" entre Maestro §3 y el código.

## Decisiones pendientes

- Formato JSON exacto que debe devolver la IA (encuentros, opciones, calidad).
- Proveedor de IA y backend intermedio (Gemini vs Groq; dónde se aloja la clave).
- Qué hacer con la suscripción de Gemini revendida (verificar / reemplazar por la promoción estudiantil).
- Confirmar que Andrés verificó su cuenta de GitHub Student.
- **¿El repo remoto `backend` es intencional?** La app Flutter vive en `github.com/andrespitta7-debug/backend`. Confirmar si es monorepo app + backend o renombrar.

## Notas para el próximo chat

- No rediseñar la arquitectura hexagonal; ya funciona.
- Pegar texto, no PDFs ni capturas.
- Si se quiere revisar código: pegar el `git diff` o el `codigo_domain_infra.txt`.
- **Regla de contraseña:** mínimo 8 caracteres con letra y número, **solo aplica al registro**. El login acepta usuarios viejos con contraseña de 6.
- **`shared_preferences`** ya está en `pubspec.yaml` y aprobado para uso.

---

## Bitácora de decisiones y sesiones

| Fecha | Qué se decidió / hizo | Motivo |
|---|---|---|
| 24-sep-2026 | Se crea el protocolo de continuidad (Maestro v3 + este archivo + script de exportación) | Un chat anterior se cortó por límite de imágenes y no hubo forma de migrar el contexto |
| 24-sep-2026 | Copilot Student se usa solo en modo Auto; el razonamiento largo se hace en el chat de Claude | Sin selector manual de modelos desde jun-2026 |
| 24-sep-2026 | La suscripción Gemini revendida se trata como "sin verificar" y sin copias únicas de archivos | Señales de riesgo en el anuncio |
| 24-sep-2026 | Se completan los pasos 1, 2 y 3 (bug del daño, auth persistente, menú principal) y se suben a GitHub | Avance del roadmap; los prompts fueron diseñados en el chat y ejecutados con Copilot |
| 24-sep-2026 | **Contraseña mínima sube de 6 a 8 caracteres con letra y número, solo en registro** | Endurecer seguridad sin romper usuarios existentes. Contradice el Maestro §3; actualizarlo |
| 24-sep-2026 | `.gitignore` reescrito sin BOM tras detectar que PowerShell lo rompía | El archivo de macos seguía apareciendo como untracked |
| _(fecha)_ | _(siguiente entrada)_ | |