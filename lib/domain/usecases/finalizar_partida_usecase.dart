import '../entities/personaje_partida.dart';
import '../repositories/partida_repository.dart';

/// Regla de negocio: qué pasa con el progreso del usuario al terminar un combate.
/// No sabe nada de SQLite ni de la pantalla.
class FinalizarPartidaUseCase {
  final PartidaRepository _repo;
  FinalizarPartidaUseCase(this._repo);

  static const int xpPorVictoria = 50;
  static const int xpPorDerrota = 10;
  static const int xpParaSubirNivel = 100;

  Future<void> ejecutar({required Partida partida, required bool gano}) async {
    partida.estado = gano ? 'ganada' : 'perdida';
    partida.xpObtenida = gano ? xpPorVictoria : xpPorDerrota;
    await _repo.guardarPartida(partida);

    final progreso =
        await _repo.obtenerProgreso(partida.idUsuario) ??
        ProgresoUsuario(idUsuario: partida.idUsuario);

    progreso.xpTotal += partida.xpObtenida;
    if (gano) {
      progreso.victorias += 1;
      progreso.questsCompletadas += 1;
    } else {
      progreso.derrotas += 1;
    }

    progreso.partidasJugadas = progreso.victorias + progreso.derrotas;
    progreso.nivel = 1 + (progreso.xpTotal ~/ xpParaSubirNivel);

    await _repo.actualizarProgreso(progreso);
  }
}
