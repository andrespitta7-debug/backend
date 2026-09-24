import 'package:flutter_test/flutter_test.dart';
import 'package:sysquest_app/domain/entities/encuentro.dart';
import 'package:sysquest_app/domain/entities/opcion_encuentro.dart';
import 'package:sysquest_app/domain/entities/quest.dart';
import 'package:sysquest_app/domain/entities/quest_completa.dart';
import 'package:sysquest_app/domain/repositories/quest_generator_repository.dart';
import 'package:sysquest_app/domain/repositories/quest_repository.dart';
import 'package:sysquest_app/domain/usecases/generar_quest_usecase.dart';

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

QuestCompleta crearQuestCompleta({
  List<int> calidades = const [2, 1, 0, 0],
  List<String> letras = const ['A', 'B', 'C', 'D'],
  String titulo = 'Quest de prueba',
  String? idQuestEncuentro,
  int cantidadOpciones = 4,
  bool primerEncuentroEsJefe = false,
}) {
  final quest = Quest(
    idQuest: 'quest-generada',
    titulo: titulo,
    tema: 'estructuras de datos',
    categoria: 'debug',
    dificultad: 'facil',
    descripcion: 'Quest generada para pruebas',
    fuenteGeneracion: 'ia',
  );

  final encuentros = List.generate(3, (indiceEncuentro) {
    final numero = indiceEncuentro + 1;
    final opciones = List.generate(4, (indiceOpcion) {
      return OpcionEncuentro(
        idOpcion: 'op-$numero-${indiceOpcion + 1}',
        idEncuentro: 'enc-$numero',
        letra: letras[indiceOpcion],
        texto: 'Respuesta ${indiceOpcion + 1}',
        calidad: calidades[indiceOpcion],
      );
    }).take(cantidadOpciones).toList();

    return Encuentro(
      idEncuentro: 'enc-$numero',
      idQuest: idQuestEncuentro ?? quest.idQuest,
      numero: numero,
      pregunta: 'Pregunta $numero',
      dificultad: 'facil',
      tipoEncuentro: primerEncuentroEsJefe && numero == 1 || numero == 3
          ? 'jefe'
          : 'normal',
      vidaEnemigo: 30,
      opciones: opciones,
    );
  });

  return QuestCompleta(quest: quest, encuentros: encuentros);
}

void main() {
  group('GenerarQuestUseCase', () {
    test('una quest válida pasa y se guarda', () async {
      final quest = crearQuestCompleta();
      final repo = FakeQuestRepository();
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(quest),
        repo,
      );

      final resultado = await useCase.ejecutar(' estructuras de datos ');

      expect(resultado, same(quest));
      expect(repo.questGuardada, same(quest));
    });

    test('falla cuando no hay una opción con calidad 2', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(
          crearQuestCompleta(calidades: [1, 1, 0, 0]),
        ),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando hay dos opciones con calidad 2', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(
          crearQuestCompleta(calidades: [2, 2, 0, 0]),
        ),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando hay letras repetidas', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(
          crearQuestCompleta(letras: ['A', 'A', 'C', 'D']),
        ),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando un jefe no es el último encuentro', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(
          crearQuestCompleta(primerEncuentroEsJefe: true),
        ),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando un encuentro tiene 3 opciones', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(crearQuestCompleta(cantidadOpciones: 3)),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando un encuentro tiene un idQuest inconsistente', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(
          crearQuestCompleta(idQuestEncuentro: 'quest-diferente'),
        ),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });

    test('falla cuando el título está vacío', () async {
      final useCase = GenerarQuestUseCase(
        FakeQuestGeneratorRepository(crearQuestCompleta(titulo: '   ')),
        FakeQuestRepository(),
      );

      await expectLater(
        useCase.ejecutar('estructuras de datos'),
        throwsA(isA<QuestInvalidaException>()),
      );
    });
  });
}
