import 'package:flutter_test/flutter_test.dart';

import 'package:sysquest_app/domain/entities/encuentro.dart';
import 'package:sysquest_app/domain/entities/opcion_encuentro.dart';
import 'package:sysquest_app/domain/entities/personaje_partida.dart';
import 'package:sysquest_app/domain/entities/quest.dart';
import 'package:sysquest_app/domain/entities/quest_completa.dart';
import 'package:sysquest_app/domain/repositories/partida_repository.dart';
import 'package:sysquest_app/domain/repositories/quest_repository.dart';
import 'package:sysquest_app/domain/usecases/finalizar_partida_usecase.dart';
import 'package:sysquest_app/domain/usecases/responder_encuentro_usecase.dart';
import 'package:sysquest_app/domain/repositories/quest_generator_repository.dart';
import 'package:sysquest_app/domain/usecases/generar_encuentros_extra_usecase.dart';
import 'package:sysquest_app/domain/entities/wildcard.dart';
import 'package:sysquest_app/presentation/screens/combate/combate_controller.dart';

class FakeQuestRepository implements QuestRepository {
  final List<Encuentro> encuentros;
  FakeQuestRepository(this.encuentros);

  @override
  Future<List<Encuentro>> obtenerEncuentros(String idQuest) async => encuentros;

  @override
  Future<Quest?> obtenerQuestPorId(String idQuest) async => null;

  @override
  Future<void> guardarQuest(Quest quest) async {}

  @override
  Future<void> guardarQuestCompleta(QuestCompleta quest) async {}
}

class FakePartidaRepository implements PartidaRepository {
  @override
  Future<void> guardarPartida(Partida partida) async {}

  @override
  Future<ProgresoUsuario?> obtenerProgreso(String idUsuario) async => null;

  @override
  Future<void> actualizarProgreso(ProgresoUsuario progreso) async {}
}

class FakeQuestGeneratorRepository implements QuestGeneratorRepository {
  @override
  Future<QuestCompleta> generarQuest(String tema) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Encuentro>> generarEncuentrosExtra({
    required String idQuest,
    required String tema,
    required String categoria,
    required String dificultad,
    required int ultimoNumero,
  }) async {
    return [];
  }
}

void main() {
  final opcionCritica = OpcionEncuentro(
    idOpcion: 'op-1',
    idEncuentro: 'enc-1',
    letra: 'A',
    texto: 'Opcion optima',
    calidad: 2,
  );

  final encuentroNormal1 = Encuentro(
    idEncuentro: 'enc-1',
    idQuest: 'q-1',
    numero: 1,
    pregunta: 'Pregunta 1',
    dificultad: 'facil',
    tipoEncuentro: 'normal',
    vidaEnemigo: 50,
    opciones: [opcionCritica],
  );

  final encuentroJefe = Encuentro(
    idEncuentro: 'enc-jefe',
    idQuest: 'q-1',
    numero: 3,
    pregunta: 'Pregunta Jefe',
    dificultad: 'dificil',
    tipoEncuentro: 'jefe',
    vidaEnemigo: 80,
    opciones: [opcionCritica],
  );

  group('CombateController', () {
    test('elegirOpcion con turnoEnProceso=true no procesa el turno', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1, encuentroJefe]);
      final repoPartida = FakePartidaRepository();
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(repoPartida),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: const Duration(milliseconds: 10),
      );

      await controller.cargarQuest('q-1', 'u-1');
      expect(controller.vidaEnemigo, equals(50));

      // Simulamos turno en proceso activo
      controller.turnoEnProceso = true;

      await controller.elegirOpcion(opcionCritica);

      // No debe haberse procesado el turno ni reducido la vida del enemigo
      expect(controller.vidaEnemigo, equals(50));
      expect(controller.resultadoUltimoTurno, isNull);
    });

    test('elegirOpcion con turnoEnProceso=false procesa y vuelve a false tras el delay', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1, encuentroJefe]);
      final repoPartida = FakePartidaRepository();
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(repoPartida),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: const Duration(milliseconds: 30),
      );

      await controller.cargarQuest('q-1', 'u-1');
      expect(controller.turnoEnProceso, isFalse);

      final futureElegir = controller.elegirOpcion(opcionCritica);

      // Inmediatamente tras llamar, turnoEnProceso pasa a true
      expect(controller.turnoEnProceso, isTrue);

      await futureElegir;

      // Al completar el delay, vuelve a false
      expect(controller.turnoEnProceso, isFalse);
      expect(controller.resultadoUltimoTurno, isNotNull);
      expect(controller.vidaEnemigo, lessThan(50));
    });

    test('cargarQuest baraja solo los normales y deja el jefe al final', () async {
      final normalA = Encuentro(
        idEncuentro: 'norm-A',
        idQuest: 'q-1',
        numero: 1,
        pregunta: 'A',
        dificultad: 'facil',
        tipoEncuentro: 'normal',
        vidaEnemigo: 30,
        opciones: [opcionCritica],
      );
      final normalB = Encuentro(
        idEncuentro: 'norm-B',
        idQuest: 'q-1',
        numero: 2,
        pregunta: 'B',
        dificultad: 'facil',
        tipoEncuentro: 'normal',
        vidaEnemigo: 30,
        opciones: [opcionCritica],
      );
      final normalC = Encuentro(
        idEncuentro: 'norm-C',
        idQuest: 'q-1',
        numero: 3,
        pregunta: 'C',
        dificultad: 'facil',
        tipoEncuentro: 'normal',
        vidaEnemigo: 30,
        opciones: [opcionCritica],
      );

      final repoQuest = FakeQuestRepository([normalA, normalB, normalC, encuentroJefe]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
      );

      await controller.cargarQuest('q-1', 'u-1');

      // Avanzamos por todos los encuentros para verificar su orden
      final idsRecorridos = <String>[];
      final tiposRecorridos = <String>[];

      while (controller.encuentroActual != null) {
        idsRecorridos.add(controller.encuentroActual!.idEncuentro);
        tiposRecorridos.add(controller.encuentroActual!.tipoEncuentro);
        if (controller.encuentroActual!.esJefe) break;
        controller.continuarSiguienteEncuentro();
      }

      expect(idsRecorridos.length, equals(4));
      // El último debe ser siempre el jefe
      expect(tiposRecorridos.last, equals('jefe'));
      expect(idsRecorridos.last, equals('enc-jefe'));

      // Los primeros deben ser todos normales
      expect(tiposRecorridos.sublist(0, 3).every((tipo) => tipo == 'normal'), isTrue);
      expect(idsRecorridos.sublist(0, 3).toSet(), equals({'norm-A', 'norm-B', 'norm-C'}));
    });

    test('al fallar pregunta con calidad 0 carga pregunta extra para el mismo enemigo', () async {
      final opcionFalla = OpcionEncuentro(
        idOpcion: 'op-falla',
        idEncuentro: 'enc-1',
        letra: 'B',
        texto: 'Opcion incorrecta',
        calidad: 0,
      );
      final encuentroOriginal = Encuentro(
        idEncuentro: 'enc-1',
        idQuest: 'q-1',
        numero: 1,
        pregunta: 'Pregunta Inicial',
        dificultad: 'facil',
        tipoEncuentro: 'normal',
        vidaEnemigo: 50,
        opciones: [opcionFalla],
      );
      final preguntaExtra = Encuentro(
        idEncuentro: 'extra-1',
        idQuest: 'q-1',
        numero: 4,
        pregunta: 'Pregunta Extra 1',
        dificultad: 'facil',
        tipoEncuentro: 'normal',
        vidaEnemigo: 50,
        opciones: [opcionCritica],
      );

      final repoQuest = FakeQuestRepository([encuentroOriginal, encuentroJefe]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );

      await controller.cargarQuest(
        'q-1',
        'u-1',
        preguntasExtra: [preguntaExtra],
      );

      expect(controller.encuentroActual!.pregunta, equals('Pregunta Inicial'));
      final vidaJugadorInicial = controller.vidaJugador;

      // Jugador falla
      await controller.elegirOpcion(opcionFalla);

      // El enemigo contraatacó
      expect(controller.vidaJugador, lessThan(vidaJugadorInicial));
      // El mismo enemigo sigue vivo
      expect(controller.vidaEnemigo, equals(50));
      expect(controller.encuentroSuperado, isFalse);
      // La pregunta fue reemplazada por la pregunta extra
      expect(controller.encuentroActual!.pregunta, equals('Pregunta Extra 1'));
      expect(controller.encuentroActual!.numero, equals(1)); // Conserva número de enemigo
    });

    test('al derrotar a un enemigo avanza automaticamente al siguiente y consume narrativa', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1, encuentroJefe]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );

      final poolNarrativo = {
        'jefe_avistado': ['El jefe final aparece imponente en el horizonte.'],
      };

      await controller.cargarQuest(
        'q-1',
        'u-1',
        poolNarrativo: poolNarrativo,
      );

      expect(controller.encuentroActual!.tipoEncuentro, equals('normal'));
      expect(controller.vidaEnemigo, equals(50));

      // Asestamos dos golpes de 25 (calidad 2)
      await controller.elegirOpcion(opcionCritica);
      expect(controller.vidaEnemigo, equals(25));

      await controller.elegirOpcion(opcionCritica);

      // Enemigo derrotado -> transiciona al siguiente (el jefe)
      expect(controller.encuentroSuperado, isTrue);
      expect(controller.encuentroActual!.tipoEncuentro, equals('jefe'));
      expect(controller.vidaEnemigo, equals(80));
      expect(controller.mensajeNarrativoActual, equals('El jefe final aparece imponente en el horizonte.'));
      expect(controller.combateTerminado, isFalse);
    });

    test('pausarCombate, continuarCombate y retirarse funcionan correctamente', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1]);
      final repoPartida = FakePartidaRepository();
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(repoPartida),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );

      final poolNarrativo = {
        'retirada': ['Te retiras tácticamente para luchar otro día.'],
      };

      await controller.cargarQuest(
        'q-1',
        'u-1',
        poolNarrativo: poolNarrativo,
      );

      expect(controller.enPausa, isFalse);

      controller.pausarCombate();
      expect(controller.enPausa, isTrue);

      controller.continuarCombate();
      expect(controller.enPausa, isFalse);

      controller.pausarCombate();
      await controller.retirarse();

      expect(controller.enPausa, isFalse);
      expect(controller.combateTerminado, isTrue);
      expect(controller.jugadorGano, isFalse);
      expect(controller.mensajeNarrativoActual, equals('Te retiras tácticamente para luchar otro día.'));
    });
    test('usarWildcard reduce la cantidad en 1', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
      );
      await controller.cargarQuest('q-1', 'u-1');

      expect(controller.wildcards[TipoWildcard.roboDeVida], equals(1));
      await controller.usarWildcard(TipoWildcard.roboDeVida);
      expect(controller.wildcards[TipoWildcard.roboDeVida], equals(0));
      expect(controller.roboDeVidaActivo, isTrue);
    });

    test('usarWildcard con cantidad 0 no hace nada', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
      );
      await controller.cargarQuest('q-1', 'u-1');

      await controller.usarWildcard(TipoWildcard.roboDeVida);
      expect(controller.wildcards[TipoWildcard.roboDeVida], equals(0));
      // Try again
      await controller.usarWildcard(TipoWildcard.roboDeVida);
      expect(controller.wildcards[TipoWildcard.roboDeVida], equals(0)); // Still 0
    });

    test('50/50 oculta 2 opciones incorrectas', () async {
      final opcionMala1 = OpcionEncuentro(idOpcion: 'op-2', idEncuentro: 'enc-1', letra: 'B', texto: 'Mala 1', calidad: 0);
      final opcionMala2 = OpcionEncuentro(idOpcion: 'op-3', idEncuentro: 'enc-1', letra: 'C', texto: 'Mala 2', calidad: 0);
      final opcionMala3 = OpcionEncuentro(idOpcion: 'op-4', idEncuentro: 'enc-1', letra: 'D', texto: 'Mala 3', calidad: 1);
      final encuentro4Ops = Encuentro(
        idEncuentro: 'enc-1', idQuest: 'q-1', numero: 1, pregunta: 'P', dificultad: 'facil', tipoEncuentro: 'normal', vidaEnemigo: 50,
        opciones: [opcionCritica, opcionMala1, opcionMala2, opcionMala3],
      );

      final repoQuest = FakeQuestRepository([encuentro4Ops]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
      );
      await controller.cargarQuest('q-1', 'u-1');

      expect(controller.opcionesOcultas.isEmpty, isTrue);
      await controller.usarWildcard(TipoWildcard.cincuentaCincuenta);
      expect(controller.opcionesOcultas.length, equals(2));
      expect(controller.opcionesOcultas.contains(opcionCritica.texto), isFalse);
    });

    test('golpe doble hace daño x2 en el próximo acierto', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );
      await controller.cargarQuest('q-1', 'u-1');

      await controller.usarWildcard(TipoWildcard.golpeDoble);
      expect(controller.golpeDobleActivo, isTrue);

      await controller.elegirOpcion(opcionCritica);
      // Critico base es 25. x2 = 50. Enemigo inicial tiene 50. Debería quedar en 0.
      expect(controller.vidaEnemigo, equals(0));
      expect(controller.golpeDobleActivo, isFalse);
    });

    test('robo de vida cura 10 HP en el próximo acierto', () async {
      final repoQuest = FakeQuestRepository([encuentroNormal1]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );
      await controller.cargarQuest('q-1', 'u-1');

      controller.vidaJugador = 50; // Set to 50 directly for test

      await controller.usarWildcard(TipoWildcard.roboDeVida);
      expect(controller.roboDeVidaActivo, isTrue);

      await controller.elegirOpcion(opcionCritica);
      expect(controller.vidaJugador, equals(60)); // 50 + 10
      expect(controller.roboDeVidaActivo, isFalse);
    });

    test('cada 3 enemigos derrotados se otorga 1 wildcard', () async {
      final e2 = Encuentro(
        idEncuentro: 'enc-2', idQuest: 'q-1', numero: 2, pregunta: 'P', dificultad: 'facil', tipoEncuentro: 'normal', vidaEnemigo: 50,
        opciones: [opcionCritica],
      );
      final e3 = Encuentro(
        idEncuentro: 'enc-3', idQuest: 'q-1', numero: 3, pregunta: 'P', dificultad: 'facil', tipoEncuentro: 'normal', vidaEnemigo: 50,
        opciones: [opcionCritica],
      );
      final repoQuest = FakeQuestRepository([encuentroNormal1, e2, e3]);
      final controller = CombateController(
        repoQuest,
        ResponderEncuentroUseCase(),
        FinalizarPartidaUseCase(FakePartidaRepository()),
        GenerarEncuentrosExtraUseCase(FakeQuestGeneratorRepository()),
        duracionPausaTurno: Duration.zero,
      );
      await controller.cargarQuest('q-1', 'u-1');

      // Gastamos todos los wildcards para ver el incremento
      for (final tipo in TipoWildcard.values) {
        await controller.usarWildcard(tipo);
      }
      
      final totalAntes = TipoWildcard.values.map((t) => controller.wildcards[t]!).reduce((a, b) => a + b);
      expect(totalAntes, equals(0));

      // Derrotar 3 enemigos (cada uno tiene 50 HP, 2 criticos lo matan)
      for (int i = 0; i < 3; i++) {
        await controller.elegirOpcion(opcionCritica);
        await controller.elegirOpcion(opcionCritica);
        controller.continuarSiguienteEncuentro();
      }

      // Check wildcards
      final totalDespues = TipoWildcard.values.map((t) => controller.wildcards[t]!).reduce((a, b) => a + b);
      expect(totalDespues, equals(1)); // Se otorgó 1
    });
  });
}

