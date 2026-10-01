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
  List<Encuentro> _preguntasExtra = [];
  int _indiceActual = 0;
  Encuentro? _preguntaActiva;
  Map<String, dynamic>? _poolNarrativo;
  late Partida _partida;

  int vidaJugador = 100;
  int vidaEnemigo = 30;
  String? mensajeUltimoTurno;
  String? mensajeNarrativoActual;
  ResultadoCombate? resultadoUltimoTurno;
  bool cargando = true;
  bool encuentroSuperado = false; // se venció al enemigo actual, pero faltan más
  bool combateTerminado = false; // se acabó TODA la quest (ganada, perdida o retirada)
  bool jugadorGano = false;
  bool guardandoResultado = false;
  bool turnoEnProceso = false;
  bool enPausa = false;

  @override
  void dispose() {
    _disposed = true;
    _timerPausaTurno?.cancel();
    if (_completerPausaTurno != null && !_completerPausaTurno!.isCompleted) {
      _completerPausaTurno!.complete();
    }
    super.dispose();
  }

  /// Retorna el encuentro actual combinando los metadatos del enemigo en turno
  /// con la pregunta activa (sea la original o una extra tras fallar).
  Encuentro? get encuentroActual {
    if (_encuentros.isEmpty || _indiceActual >= _encuentros.length) return null;
    final enemigo = _encuentros[_indiceActual];
    final pregunta = _preguntaActiva ?? enemigo;

    if (identical(enemigo, pregunta)) {
      return enemigo;
    }

    return Encuentro(
      idEncuentro: pregunta.idEncuentro,
      idQuest: enemigo.idQuest,
      numero: enemigo.numero,
      pregunta: pregunta.pregunta,
      dificultad: enemigo.dificultad,
      tipoEncuentro: enemigo.tipoEncuentro,
      vidaEnemigo: enemigo.vidaEnemigo,
      opciones: pregunta.opciones,
    );
  }

  /// Cantidad de preguntas extra restantes en cola.
  int get preguntasExtraRestantes => _preguntasExtra.length;

  /// Partida actual.
  Partida get partida => _partida;

  /// Consume y remueve el primer fragmento disponible de una categoría del pool narrativo.
  String? _consumirFragmentoNarrativo(String categoria) {
    if (_poolNarrativo == null) return null;
    final lista = _poolNarrativo![categoria];
    if (lista is List && lista.isNotEmpty) {
      final fragmento = lista.removeAt(0);
      return fragmento.toString();
    }
    return null;
  }

  Future<void> cargarQuest(
    String idQuest,
    String idUsuario, {
    Map<String, dynamic>? poolNarrativo,
    List<Encuentro>? preguntasExtra,
  }) async {
    cargando = true;
    combateTerminado = false;
    encuentroSuperado = false;
    enPausa = false;
    resultadoUltimoTurno = null;
    mensajeUltimoTurno = null;
    vidaJugador = 100;
    turnoEnProceso = false;
    _poolNarrativo = poolNarrativo != null ? Map<String, dynamic>.from(poolNarrativo) : null;
    _preguntasExtra = preguntasExtra != null ? List<Encuentro>.from(preguntasExtra) : [];
    notifyListeners();

    final encuentrosCargados = await _questRepository.obtenerEncuentros(idQuest);

    final todosNormales = encuentrosCargados.where((e) => !e.esJefe).toList();
    final jefes = encuentrosCargados.where((e) => e.esJefe).toList();

    List<Encuentro> normales;
    // Si la quest incluye preguntas extra (números > 3) en la misma lista y no se pasaron aparte
    if (_preguntasExtra.isEmpty && todosNormales.any((e) => e.numero > 3)) {
      normales = todosNormales.where((e) => e.numero <= 3).toList()..shuffle();
      _preguntasExtra = todosNormales.where((e) => e.numero > 3).toList();
    } else {
      normales = todosNormales..shuffle();
    }

    _encuentros = [...normales, ...jefes];
    _indiceActual = 0;

    if (_encuentros.isNotEmpty) {
      vidaEnemigo = _encuentros.first.vidaEnemigo;
      _preguntaActiva = _encuentros.first;
    }

    _partida = Partida(
      idPartida: _uuid.v4(),
      idUsuario: idUsuario,
      idQuest: idQuest,
    );

    mensajeNarrativoActual = _consumirFragmentoNarrativo('intro');
    cargando = false;
    notifyListeners();
  }

  Future<void> elegirOpcion(OpcionEncuentro opcion) async {
    if (combateTerminado || encuentroSuperado || turnoEnProceso || enPausa) return;

    turnoEnProceso = true;
    notifyListeners();

    final enemigoActual = _encuentros[_indiceActual];
    final resultado = _responderUseCase.ejecutar(
      opcion,
      esJefe: enemigoActual.esJefe,
    );
    resultadoUltimoTurno = resultado;
    vidaEnemigo = (vidaEnemigo - resultado.danoAlEnemigo).clamp(0, 999);
    vidaJugador = (vidaJugador - resultado.danoAlJugador).clamp(0, 999);

    switch (resultado.resultado) {
      case ResultadoTurno.critico:
        mensajeUltimoTurno = '¡Golpe crítico! -${resultado.danoAlEnemigo} HP al enemigo';
        break;
      case ResultadoTurno.acierto:
        mensajeUltimoTurno = 'Correcto. -${resultado.danoAlEnemigo} HP al enemigo';
        break;
      case ResultadoTurno.fallo:
        mensajeUltimoTurno = 'Incorrecto. El enemigo contraataca: -${resultado.danoAlJugador} HP';
        // Si el jugador falla y el enemigo ataca, el siguiente turno carga una nueva pregunta
        if (_preguntasExtra.isNotEmpty) {
          _preguntaActiva = _preguntasExtra.removeAt(0);
        }
        break;
    }

    if (vidaJugador <= 0) {
      combateTerminado = true;
      jugadorGano = false;
      mensajeNarrativoActual = _consumirFragmentoNarrativo('muerte');
      _finalizarPartida(gano: false);
    } else if (vidaEnemigo <= 0) {
      final hayMasEncuentros = _indiceActual + 1 < _encuentros.length;
      if (hayMasEncuentros) {
        encuentroSuperado = true;
        _avanzarSiguienteEnemigo();
      } else {
        combateTerminado = true;
        jugadorGano = true;
        mensajeNarrativoActual = _consumirFragmentoNarrativo('ronda_completada');
        _finalizarPartida(gano: true);
      }
    }

    notifyListeners();

    // Pausa dramática para que el jugador vea el resultado del turno
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

  /// Avanza automáticamente al siguiente enemigo en cola y consume narrativa de transición.
  void _avanzarSiguienteEnemigo() {
    if (_indiceActual + 1 >= _encuentros.length) return;
    _indiceActual++;
    final nuevoEnemigo = _encuentros[_indiceActual];
    vidaEnemigo = nuevoEnemigo.vidaEnemigo;
    _preguntaActiva = nuevoEnemigo;
    mensajeUltimoTurno = null;

    final proximoEsJefe = nuevoEnemigo.esJefe;
    mensajeNarrativoActual = proximoEsJefe
        ? (_consumirFragmentoNarrativo('jefe_avistado') ??
            _consumirFragmentoNarrativo('entre_combates'))
        : _consumirFragmentoNarrativo('entre_combates');
  }

  /// Desbloquea la transición entre encuentros (o avanza al siguiente si se invoca manualmente).
  void continuarSiguienteEncuentro() {
    if (encuentroSuperado) {
      encuentroSuperado = false;
      mensajeUltimoTurno = null;
      notifyListeners();
      return;
    }
    if (_indiceActual + 1 < _encuentros.length) {
      _avanzarSiguienteEnemigo();
      notifyListeners();
    }
  }

  /// Pausa el combate actual.
  void pausarCombate() {
    if (combateTerminado || cargando) return;
    enPausa = true;
    notifyListeners();
  }

  /// Reanuda el combate tras una pausa.
  void continuarCombate() {
    enPausa = false;
    notifyListeners();
  }

  /// El jugador decide retirarse voluntariamente.
  /// Marca la partida como perdida/abandonada, otorga 10 XP de derrota y guarda progreso.
  Future<void> retirarse() async {
    if (combateTerminado || cargando) return;
    enPausa = false;
    combateTerminado = true;
    jugadorGano = false;
    mensajeNarrativoActual = _consumirFragmentoNarrativo('retirada') ?? 'Te has retirado del combate.';
    await _finalizarPartida(gano: false);
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
