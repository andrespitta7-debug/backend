import 'encuentro.dart';
import 'quest.dart';

class QuestCompleta {
  final Quest quest;
  final List<Encuentro> encuentros;

  QuestCompleta({required this.quest, required List<Encuentro> encuentros})
    : encuentros = List<Encuentro>.unmodifiable(encuentros);
}
