import 'package:flutter/foundation.dart';

import '../../../domain/entities/quest_completa.dart';
import '../../../domain/usecases/generar_quest_usecase.dart';
import '../../../infrastructure/api/api_exception.dart';

enum GenerarQuestEstado { inicial, generando, exito, error }

class GenerarQuestController extends ChangeNotifier {
  final GenerarQuestUseCase _useCase;

  GenerarQuestController(this._useCase);

  GenerarQuestEstado estado = GenerarQuestEstado.inicial;
  QuestCompleta? questGenerada;
  String? mensajeError;
  String? codigoError;

  bool get esErrorReintentable =>
      codigoError == 'IA_TIMEOUT' ||
      codigoError == 'IA_NO_DISPONIBLE' ||
      codigoError == 'ERROR_PERSISTENCIA';

  Future<void> generar(String tema) async {
    estado = GenerarQuestEstado.generando;
    questGenerada = null;
    mensajeError = null;
    codigoError = null;
    notifyListeners();

    try {
      questGenerada = await _useCase.ejecutar(tema);
      estado = GenerarQuestEstado.exito;
    } on QuestInvalidaException catch (error) {
      mensajeError = error.mensaje;
      codigoError = null;
      estado = GenerarQuestEstado.error;
    } on ApiException catch (error) {
      if (kDebugMode) {
        debugPrint('[GenerarQuest] Error: ${error.codigo} - ${error.mensaje}');
      }
      mensajeError = error.mensaje;
      codigoError = error.codigo;
      estado = GenerarQuestEstado.error;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GenerarQuest] Error inesperado: $e');
      }
      mensajeError =
          'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.';
      codigoError = null;
      estado = GenerarQuestEstado.error;
    }

    notifyListeners();
  }
}
