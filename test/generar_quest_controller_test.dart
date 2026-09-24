import 'package:flutter_test/flutter_test.dart';
import 'package:sysquest_app/domain/entities/encuentro.dart';
import 'package:sysquest_app/domain/entities/opcion_encuentro.dart';
import 'package:sysquest_app/domain/entities/quest.dart';
import 'package:sysquest_app/domain/entities/quest_completa.dart';
import 'package:sysquest_app/domain/repositories/quest_generator_repository.dart';
import 'package:sysquest_app/domain/repositories/quest_repository.dart';
import 'package:sysquest_app/domain/usecases/generar_quest_usecase.dart';
import 'package:sysquest_app/presentation/screens/generar_quest/generar_quest_controller.dart';

class FakeQuestGeneratorRepository implements QuestGeneratorRepository {
  FakeQuestGeneratorRepository(this.questCompleta);

  final QuestCompleta questCompleta;

  @override
  Future<QuestCompleta> generarQuest(String tema) async => questCompleta;
}

class FakeQuestRepository implements QuestRepository {
  QuestCompleta? questGuardada;

  @override
  Future<void> guardarQuestCompleta(QuestCompleta quest) async {
    questGuardada = quest;
  }

  @override
  Future<Quest?> obtenerQuestPorId(String idQuest) async => null;

  @override
  Future<List<Encuentro>> obtenerEncuentros(String idQuest) async => [];

  @override
  Future<void> guardarQuest(Quest quest) async {}
}

QuestCompleta crearQuest({required String titulo}) {
  const questId = 'quest-controller-test';
  final encuentros = List.generate(3, (indice) {
    final numero = indice + 1;
    final encuentroId = 'enc-controller-$numero';
    final opciones = [
      OpcionEncuentro(
        idOpcion: 'op-$numero-a',
        idEncuentro: encuentroId,
        letra: 'A',
        texto: 'Respuesta principal',
        calidad: 2,
      ),
      OpcionEncuentro(
        idOpcion: 'op-$numero-b',
        idEncuentro: encuentroId,
        letra: 'B',
        texto: 'Respuesta parcial',
        calidad: 1,
      ),
      OpcionEncuentro(
        idOpcion: 'op-$numero-c',
        idEncuentro: encuentroId,
        letra: 'C',
        texto: 'Respuesta incorrecta',
        calidad: 0,
      ),
      OpcionEncuentro(
        idOpcion: 'op-$numero-d',
        idEncuentro: encuentroId,
        letra: 'D',
        texto: 'Otra respuesta incorrecta',
        calidad: 0,
      ),
    ];

    return Encuentro(
      idEncuentro: encuentroId,
      idQuest: questId,
      numero: numero,
      pregunta: 'Pregunta de prueba $numero',
      dificultad: numero == 1
          ? 'facil'
          : numero == 2
          ? 'medio'
          : 'dificil',
      tipoEncuentro: numero == 3 ? 'jefe' : 'normal',
      vidaEnemigo: 30,
      opciones: opciones,
    );
  });

  return QuestCompleta(
    quest: Quest(
      idQuest: questId,
      titulo: titulo,
      tema: 'tema de prueba',
      categoria: 'libre',
      dificultad: 'facil',
      descripcion: 'Descripción de prueba',
      fuenteGeneracion: 'ia',
    ),
    encuentros: encuentros,
  );
}

void main() {
  group('GenerarQuestController', () {
    test('transiciona de generando a exito con un generador falso', () async {
      final repo = FakeQuestRepository();
      final quest = crearQuest(titulo: 'Quest válida');
      final controller = GenerarQuestController(
        GenerarQuestUseCase(FakeQuestGeneratorRepository(quest), repo),
      );
      final estados = <GenerarQuestEstado>[];
      controller.addListener(() => estados.add(controller.estado));

      await controller.generar('tema válido');

      expect(estados, [GenerarQuestEstado.generando, GenerarQuestEstado.exito]);
      expect(controller.questGenerada, same(quest));
      expect(repo.questGuardada, same(quest));
      expect(controller.mensajeError, isNull);
      controller.dispose();
    });

    test('transiciona de generando a error y conserva el mensaje', () async {
      final repo = FakeQuestRepository();
      final controller = GenerarQuestController(
        GenerarQuestUseCase(
          FakeQuestGeneratorRepository(crearQuest(titulo: '   ')),
          repo,
        ),
      );
      final estados = <GenerarQuestEstado>[];
      controller.addListener(() => estados.add(controller.estado));

      await controller.generar('tema válido');

      expect(estados, [GenerarQuestEstado.generando, GenerarQuestEstado.error]);
      expect(controller.questGenerada, isNull);
      expect(
        controller.mensajeError,
        'El título de la quest no puede estar vacío.',
      );
      expect(repo.questGuardada, isNull);
      controller.dispose();
    });
  });
}
