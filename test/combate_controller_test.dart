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
  });
}
