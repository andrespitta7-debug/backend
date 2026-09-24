# SysQuest — Estado actual (archivo vivo)

*Se actualiza al final de CADA sesión de trabajo (2 minutos). Va junto al Contexto Maestro al abrir un chat nuevo. Mantenerlo corto: si crece, mover lo antiguo a la bitácora.*

**Última actualización:** 24-sep-2026
**Último commit conocido:** _(pega aquí el hash y mensaje: `git log -1 --oneline`)_

---

## Hecho

- MVP funcionando: auth, quest/encuentros, combate por turnos, Mi Progreso (ver Maestro §3).
- Diccionario de datos v2 corregido (`V2SysQuest_Diccionario_de_Datos.md`).
- Auditoría de dominio e infraestructura realizada (hallazgos en Maestro §3b).
- GitHub Student verificado (Jhony) y Copilot Student activo en VS Code.
- `.github/copilot-instructions.md` creado.
- NotebookLM con 5 fuentes cargadas.

## En curso

- Aplicando con Copilot los arreglos de la auditoría (Maestro §3b). **Marcar cuáles ya están hechos y verificados:**
  - [ ] `calidad` corregidos en datos de prueba
  - [ ] `orderBy: 'letra ASC'` en opciones
  - [ ] `vida_enemigo` unificado
  - [ ] `PRAGMA foreign_keys = ON`

## Siguiente

1. Revisar en el chat el `git diff` de los arreglos.
2. Diseñar `QuestGeneratorRepository` + `GenerarQuestUseCase` (Maestro §4).
3. Adaptador falso de generación para probar el flujo sin backend.

## Decisiones pendientes

- Formato JSON exacto que debe devolver la IA (encuentros, opciones, calidad).
- Proveedor de IA y backend intermedio (Gemini vs Groq; dónde se aloja la clave).
- Qué hacer con la suscripción de Gemini revendida (verificar / reemplazar por la promoción estudiantil).
- Confirmar que Andrés verificó su cuenta de GitHub Student.

## Notas para el próximo chat

- No rediseñar la arquitectura hexagonal; ya funciona.
- Pegar texto, no PDFs ni capturas.
- Si se quiere revisar código: pegar el `git diff` o el `codigo_domain_infra.txt`.

---

## Bitácora de decisiones y sesiones

| Fecha | Qué se decidió / hizo | Motivo |
|---|---|---|
| 24-sep-2026 | Se crea el protocolo de continuidad (Maestro v3 + este archivo + script de exportación) | Un chat anterior se cortó por límite de imágenes y no hubo forma de migrar el contexto |
| 24-sep-2026 | Copilot Student se usa solo en modo Auto; el razonamiento largo se hace en el chat de Claude | Sin selector manual de modelos desde jun-2026 |
| 24-sep-2026 | La suscripción Gemini revendida se trata como "sin verificar" y sin copias únicas de archivos | Señales de riesgo en el anuncio |
| _(fecha)_ | _(siguiente entrada)_ | |
