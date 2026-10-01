import 'package:flutter_test/flutter_test.dart';

import 'package:sysquest_app/domain/entities/personaje_partida.dart';
import 'package:sysquest_app/domain/repositories/partida_repository.dart';
import 'package:sysquest_app/domain/usecases/finalizar_partida_usecase.dart';

class FakePartidaRepository implements PartidaRepository {
  int llamadasGuardarPartida = 0;
  int llamadasObtenerProgreso = 0;
  int llamadasActualizarProgreso = 0;

  ProgresoUsuario? progreso;
  Partida? ultimaPartidaGuardada;

  FakePartidaRepository({this.progreso});

  @override
  Future<void> guardarPartida(Partida partida) async {
    llamadasGuardarPartida++;
    ultimaPartidaGuardada = partida;
  }

  @override
  Future<ProgresoUsuario?> obtenerProgreso(String idUsuario) async {
    llamadasObtenerProgreso++;
    return progreso ?? ProgresoUsuario(idUsuario: idUsuario);
  }

  @override
  Future<void> actualizarProgreso(ProgresoUsuario nuevoProgreso) async {
    llamadasActualizarProgreso++;
    progreso = nuevoProgreso;
  }
}

void main() {
  group('FinalizarPartidaUseCase', () {
    test('con guardarLocalmente: true (default), llama a guardarPartida y actualizarProgreso', () async {
      final repo = FakePartidaRepository();
      final useCase = FinalizarPartidaUseCase(repo);

      final partida = Partida(
        idPartida: 'partida-1',
        idUsuario: 'usuario-1',
        idQuest: 'quest-001',
      );

      await useCase.ejecutar(partida: partida, gano: true);

      expect(repo.llamadasGuardarPartida, equals(1));
      expect(repo.llamadasObtenerProgreso, equals(1));
      expect(repo.llamadasActualizarProgreso, equals(1));
      expect(partida.estado, equals('ganada'));
      expect(partida.xpObtenida, equals(FinalizarPartidaUseCase.xpPorVictoria));
      expect(repo.progreso, isNotNull);
      expect(repo.progreso!.victorias, equals(1));
      expect(repo.progreso!.questsCompletadas, equals(1));
      expect(repo.progreso!.partidasJugadas, equals(1));
    });

    test('con guardarLocalmente: false, NO llama al repositorio pero actualiza estado y xp de la partida', () async {
      final repo = FakePartidaRepository();
      final useCase = FinalizarPartidaUseCase(repo, guardarLocalmente: false);

      final partida = Partida(
        idPartida: 'partida-2',
        idUsuario: 'usuario-2',
        idQuest: 'quest-001',
      );

      await useCase.ejecutar(partida: partida, gano: false);

      expect(repo.llamadasGuardarPartida, equals(0));
      expect(repo.llamadasObtenerProgreso, equals(0));
      expect(repo.llamadasActualizarProgreso, equals(0));
      expect(repo.progreso, isNull);
      expect(partida.estado, equals('perdida'));
      expect(partida.xpObtenida, equals(FinalizarPartidaUseCase.xpPorDerrota));
    });

    test('calcula correctamente el nivel en modo local (1 + xpTotal ~/ 100)', () async {
      final progresoInicial = ProgresoUsuario(
        idUsuario: 'usuario-3',
        nivel: 1,
        xpTotal: 80,
      );
      final repo = FakePartidaRepository(progreso: progresoInicial);
      final useCase = FinalizarPartidaUseCase(repo, guardarLocalmente: true);

      final partida = Partida(
        idPartida: 'partida-3',
        idUsuario: 'usuario-3',
        idQuest: 'quest-001',
      );

      // Ganar suma 50 XP -> 80 + 50 = 130 XP -> nivel 1 + (130 ~/ 100) = 2
      await useCase.ejecutar(partida: partida, gano: true);

      expect(repo.progreso!.xpTotal, equals(130));
      expect(repo.progreso!.nivel, equals(2));
    });
  });
}
