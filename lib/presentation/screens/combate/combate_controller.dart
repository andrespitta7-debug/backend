import 'dart:async';

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
  final Duration duracionPausaTurno;
  final _uuid = const Uuid();
  bool _disposed = false;
  Timer? _timerPausaTurno;
  Completer<void>? _completerPausaTurno;

  CombateController(
    this._questRepository,
    this._responderUseCase,
    this._finalizarUseCase, {
    this.duracionPausaTurno = const Duration(milliseconds: 700),
  });

  List<Encuentro> _encuentros = [];
  int _indiceActual = 0;
  late Partida _partida;

  int vidaJugador = 100;
  int vidaEnemigo = 30;
  String? mensajeUltimoTurno;
  ResultadoCombate? resultadoUltimoTurno;
  bool cargando = true;
  bool encuentroSuperado =
      false; // se venció al enemigo actual, pero faltan más
  bool combateTerminado = false; // se acabó TODA la quest (ganada o perdida)
  bool jugadorGano = false;
  bool guardandoResultado = false;
  bool turnoEnProceso = false;

  @override
  void dispose() {
    _disposed = true;
    _timerPausaTurno?.cancel();
    if (_completerPausaTurno != null && !_completerPausaTurno!.isCompleted) {
      _completerPausaTurno!.complete();
    }
    super.dispose();
  }

  Encuentro? get encuentroActual =>
      _encuentros.isEmpty ? null : _encuentros[_indiceActual];

  Future<void> cargarQuest(String idQuest, String idUsuario) async {
    cargando = true;
    combateTerminado = false;
    encuentroSuperado = false;
    resultadoUltimoTurno = null;
    vidaJugador = 100;
    turnoEnProceso = false;
    notifyListeners();

    final encuentrosCargados =
        await _questRepository.obtenerEncuentros(idQuest);

    // Barajar solo los encuentros "normales" (no jefe). El jefe siempre
    // queda al final para respetar la progresión de dificultad.
    final normales = encuentrosCargados
        .where((e) => !e.esJefe)
        .toList()
      ..shuffle();
    final jefes = encuentrosCargados.where((e) => e.esJefe).toList();
    _encuentros = [...normales, ...jefes];

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

  Future<void> elegirOpcion(OpcionEncuentro opcion) async {
    if (combateTerminado || encuentroSuperado || turnoEnProceso) return;

    turnoEnProceso = true;
    notifyListeners();

    final resultado = _responderUseCase.ejecutar(
      opcion,
      esJefe: _encuentros[_indiceActual].esJefe,
    );
    resultadoUltimoTurno = resultado;
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

    // Pausa dramática para que el jugador vea el resultado del turno
    // antes de poder elegir la siguiente opción.
    if (duracionPausaTurno > Duration.zero) {
      final completer = Completer<void>();
      _completerPausaTurno = completer;
      _timerPausaTurno = Timer(duracionPausaTurno, () {
        if (!_disposed) {
          turnoEnProceso = false;
          notifyListeners();
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
    } else {
      if (!_disposed) {
        turnoEnProceso = false;
        notifyListeners();
      }
    }
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
