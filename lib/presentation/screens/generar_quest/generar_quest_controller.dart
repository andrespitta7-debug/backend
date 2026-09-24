import 'package:flutter/foundation.dart';

import '../../../domain/entities/quest_completa.dart';
import '../../../domain/usecases/generar_quest_usecase.dart';

enum GenerarQuestEstado { inicial, generando, exito, error }

class GenerarQuestController extends ChangeNotifier {
  final GenerarQuestUseCase _useCase;

  GenerarQuestController(this._useCase);

  GenerarQuestEstado estado = GenerarQuestEstado.inicial;
  QuestCompleta? questGenerada;
  String? mensajeError;

  Future<void> generar(String tema) async {
    estado = GenerarQuestEstado.generando;
    questGenerada = null;
    mensajeError = null;
    notifyListeners();

    try {
      questGenerada = await _useCase.ejecutar(tema);
      estado = GenerarQuestEstado.exito;
    } on QuestInvalidaException catch (error) {
      mensajeError = error.mensaje;
      estado = GenerarQuestEstado.error;
    } catch (_) {
      mensajeError = 'No se pudo generar la quest, intenta de nuevo';
      estado = GenerarQuestEstado.error;
    }

    notifyListeners();
  }
}
