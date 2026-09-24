import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/encuentro.dart';
import '../../../domain/entities/opcion_encuentro.dart';
import '../../../domain/entities/personaje_partida.dart';
import '../../../domain/repositories/quest_repository.dart';
import '../../../domain/usecases/finalizar_partida_usecase.dart';
import '../../../domain/usecases/responder_encuentro_usecase.dart';

class CombateController extends ChangeNotifier {
  final QuestRepository _questRepository;
  final ResponderEncuentroUseCase _responderUseCase;
  final FinalizarPartidaUseCase _finalizarUseCase;
  final _uuid = const Uuid();

  CombateController(
    this._questRepository,
    this._responderUseCase,
    this._finalizarUseCase,
  );

  List<Encuentro> _encuentros = [];
  int _indiceActual = 0;
  late Partida _partida;

  int vidaJugador = 100;
  int vidaEnemigo = 30;
  String? mensajeUltimoTurno;
  bool cargando = true;
  bool encuentroSuperado =
      false; // se venció al enemigo actual, pero faltan más
  bool combateTerminado = false; // se acabó TODA la quest (ganada o perdida)
  bool jugadorGano = false;
  bool guardandoResultado = false;

  Encuentro? get encuentroActual =>
      _encuentros.isEmpty ? null : _encuentros[_indiceActual];

  Future<void> cargarQuest(String idQuest, String idUsuario) async {
    cargando = true;
    combateTerminado = false;
    encuentroSuperado = false;
    vidaJugador = 100;
    notifyListeners();

    _encuentros = await _questRepository.obtenerEncuentros(idQuest);
    _indiceActual = 0;
    if (_encuentros.isNotEmpty) {
      vidaEnemigo = _encuentros.first.vidaEnemigo;
    }
    _partida = Partida(
      idPartida: _uuid.v4(),
      idUsuario: idUsuario,
      idQuest: idQuest,
    );

    cargando = false;
    notifyListeners();
  }

  void elegirOpcion(OpcionEncuentro opcion) {
    if (combateTerminado || encuentroSuperado) return;

    final resultado = _responderUseCase.ejecutar(
      opcion,
      esJefe: _encuentros[_indiceActual].esJefe,
    );
    vidaEnemigo = (vidaEnemigo - resultado.danoAlEnemigo).clamp(0, 999);
    vidaJugador = (vidaJugador - resultado.danoAlJugador).clamp(0, 999);

    switch (resultado.resultado) {
      case ResultadoTurno.critico:
        mensajeUltimoTurno =
            '¡Golpe crítico! -${resultado.danoAlEnemigo} HP al enemigo';
        break;
      case ResultadoTurno.acierto:
        mensajeUltimoTurno =
            'Correcto. -${resultado.danoAlEnemigo} HP al enemigo';
        break;
      case ResultadoTurno.fallo:
        mensajeUltimoTurno =
            'Incorrecto. El enemigo contraataca: -${resultado.danoAlJugador} HP';
        break;
    }

    if (vidaJugador <= 0) {
      combateTerminado = true;
      jugadorGano = false;
      _finalizarPartida(gano: false);
    } else if (vidaEnemigo <= 0) {
      final hayMasEncuentros = _indiceActual + 1 < _encuentros.length;
      if (hayMasEncuentros) {
        encuentroSuperado =
            true; // muestra botón "Continuar" en vez de terminar ya
      } else {
        combateTerminado = true;
        jugadorGano = true;
        _finalizarPartida(gano: true);
      }
    }

    notifyListeners();
  }

  void continuarSiguienteEncuentro() {
    if (_indiceActual + 1 >= _encuentros.length) return;
    _indiceActual++;
    vidaEnemigo = _encuentros[_indiceActual].vidaEnemigo;
    mensajeUltimoTurno = null;
    encuentroSuperado = false;
    notifyListeners();
  }

  Future<void> _finalizarPartida({required bool gano}) async {
    guardandoResultado = true;
    notifyListeners();
    _partida.encuentroActual = _indiceActual;
    _partida.score = gano ? 100 : 0;
    await _finalizarUseCase.ejecutar(partida: _partida, gano: gano);
    guardandoResultado = false;
    notifyListeners();
  }
}
