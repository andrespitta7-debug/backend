import '../entities/personaje_partida.dart';
import '../repositories/partida_repository.dart';

/// Regla de negocio: qué pasa con el progreso del usuario al terminar un combate.
/// No sabe nada de SQLite ni de la pantalla.
class FinalizarPartidaUseCase {
  final PartidaRepository _repo;
  final bool _guardarLocalmente;

  FinalizarPartidaUseCase(
    this._repo, {
    bool guardarLocalmente = true,
  }) : _guardarLocalmente = guardarLocalmente;

  static const int xpPorVictoria = 50;
  static const int xpPorDerrota = 10;
  static const int xpParaSubirNivel = 100;

  Future<void> ejecutar({
    required Partida partida,
    required bool gano,
  }) async {
    partida.estado = gano ? 'ganada' : 'perdida';
    partida.xpObtenida = gano ? xpPorVictoria : xpPorDerrota;

    // SIEMPRE llamar al repo. En modo local guarda en SQLite. En modo
    // remoto llama al Edge Function finalizar-partida (que además
    // actualiza progreso_usuario en Postgres).
    await _repo.guardarPartida(partida);

    if (!_guardarLocalmente) {
      // Modo remoto: el backend ya actualizó el progreso.
      return;
    }

    // Modo local: actualizar progreso manualmente en SQLite.
    final progreso = await _repo.obtenerProgreso(partida.idUsuario) ??
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
