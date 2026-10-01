import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../domain/entities/encuentro.dart';
import '../../domain/entities/opcion_encuentro.dart';
import '../../domain/entities/quest.dart';
import '../../domain/entities/quest_completa.dart';
import '../../domain/repositories/quest_generator_repository.dart';
import '../../domain/repositories/token_repository.dart';
import 'api_exception.dart';

/// Implementación HTTP de [QuestGeneratorRepository] que se comunica
/// con la Edge Function `generar-quest` de Supabase.
class HttpQuestGeneratorRepository implements QuestGeneratorRepository {
  final String baseUrl;
  final String anonKey;
  final TokenRepository _tokenRepository;
  final http.Client _client;
  final Uuid _uuid;

  HttpQuestGeneratorRepository({
    required this.baseUrl,
    required this.anonKey,
    required TokenRepository tokenRepository,
    http.Client? httpClient,
    Uuid? uuid,
  })  : _tokenRepository = tokenRepository,
        _client = httpClient ?? http.Client(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<QuestCompleta> generarQuest(String tema) async {
    final accessToken = await _tokenRepository.obtenerAccessToken();
    if (accessToken == null) {
      throw const ApiException(
        'Tu sesión expiró, vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }

    final urlLimpia = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$urlLimpia/functions/v1/generar-quest');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'apikey': anonKey,
    };

    final body = {
      'tema': tema,
      'categoria': 'libre',
      'dificultad': 'facil',
    };

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar al servidor, revisa tu conexión.',
      );
    }

    final statusCode = response.statusCode;

    // 1. Éxito: 200 OK o 201 Created
    if (statusCode == 200 || statusCode == 201) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> questMap =
            data['quest'] as Map<String, dynamic>;

        final questId = questMap['id'] as String;
        final quest = Quest(
          idQuest: questId,
          titulo: questMap['titulo'] as String,
          tema: questMap['tema'] as String,
          categoria: questMap['categoria'] as String,
          dificultad: questMap['dificultad'] as String,
          descripcion: questMap['descripcion'] as String,
          fuenteGeneracion: 'ia', // El dominio espera 'ia' en minúscula
        );

        final List<dynamic> encuentrosJson =
            questMap['encuentros'] as List<dynamic>;
        final encuentros = <Encuentro>[];

        for (final item in encuentrosJson) {
          final encMap = item as Map<String, dynamic>;
          final encuentroId = encMap['id'] as String;

          final List<dynamic> opcionesJson =
              encMap['opciones'] as List<dynamic>;
          final opciones = <OpcionEncuentro>[];

          for (final opItem in opcionesJson) {
            final opMap = opItem as Map<String, dynamic>;
            final idOpcion = (opMap['id'] as String?)?.isNotEmpty == true
                ? opMap['id'] as String
                : _uuid.v4();

            opciones.add(
              OpcionEncuentro(
                idOpcion: idOpcion,
                idEncuentro: encuentroId,
                letra: opMap['letra'] as String,
                texto: opMap['texto'] as String,
                calidad: (opMap['calidad'] as num).toInt(),
              ),
            );
          }

          encuentros.add(
            Encuentro(
              idEncuentro: encuentroId,
              idQuest: questId,
              numero: (encMap['numero'] as num).toInt(),
              pregunta: encMap['pregunta'] as String,
              dificultad: encMap['dificultad'] as String,
              tipoEncuentro: encMap['tipo_encuentro'] as String,
              vidaEnemigo: (encMap['vida_enemigo'] as num).toInt(),
              opciones: opciones,
            ),
          );
        }

        return QuestCompleta(quest: quest, encuentros: encuentros);
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(
          'Error al procesar la respuesta del servidor.',
          statusCode: statusCode,
        );
      }
    }

    // 2. Sesión expirada: 401
    if (statusCode == 401) {
      throw const ApiException(
        'Tu sesión expiró, vuelve a iniciar sesión.',
        statusCode: 401,
      );
    }

    // 3. Error en datos de entrada: 400
    if (statusCode == 400) {
      String mensaje = 'Datos de solicitud inválidos.';
      try {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (data['detalle'] is String) {
          mensaje = data['detalle'] as String;
        } else if (data['error'] is String) {
          mensaje = data['error'] as String;
        }
      } catch (_) {}
      throw ApiException(mensaje, statusCode: 400);
    }

    // 4. Errores de IA / Gateway: 502 o 504
    if (statusCode == 502 || statusCode == 504) {
      String mensaje = 'No se pudo generar la quest.';
      try {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final codigo = data['codigo'] as String?;
        switch (codigo) {
          case 'IA_TIMEOUT':
            mensaje = 'La generación tardó demasiado, intenta de nuevo.';
            break;
          case 'IA_NO_DISPONIBLE':
            mensaje =
                'El servicio de generación no está disponible, intenta más tarde.';
            break;
          case 'IA_JSON_INVALIDO':
            mensaje = 'La IA devolvió un formato inválido, intenta de nuevo.';
            break;
          default:
            mensaje = 'No se pudo generar la quest.';
            break;
        }
      } catch (_) {}
      throw ApiException(mensaje, statusCode: statusCode);
    }

    // 5. Error interno del servidor: 500
    if (statusCode == 500) {
      throw const ApiException(
        'Error del servidor, intenta de nuevo.',
        statusCode: 500,
      );
    }

    // 6. Otros códigos no esperados
    throw ApiException(
      'Error inesperado del servidor.',
      statusCode: statusCode,
    );
  }
}
