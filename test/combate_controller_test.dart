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
  });
}

