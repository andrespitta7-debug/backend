import '../entities/quest_completa.dart';

/// Puerto para generar una quest completa a partir de un tema.
abstract class QuestGeneratorRepository {
  Future<QuestCompleta> generarQuest(String tema);
}
