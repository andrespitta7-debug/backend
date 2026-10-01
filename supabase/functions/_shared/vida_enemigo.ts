// SysQuest — Cálculo de vida de enemigos por dificultad y tipo
// docs/SysQuest_Contrato_Quest_IA.md sección 4

export function calcularVidaEnemigo(
  dificultad: string,
  tipoEncuentro: string
): number {
  const esJefe = tipoEncuentro === 'jefe';

  switch (dificultad) {
    case 'facil':
      return esJefe ? 70 : 25;
    case 'medio':
      return esJefe ? 90 : 35;
    case 'dificil':
      return esJefe ? 120 : 50;
    default:
      return esJefe ? 70 : 25;
  }
}
