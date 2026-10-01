import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sysquest_app/domain/entities/personaje_partida.dart';
import 'package:sysquest_app/domain/repositories/token_repository.dart';
import 'package:sysquest_app/infrastructure/api/api_exception.dart';
import 'package:sysquest_app/infrastructure/api/http_partida_repository.dart';

class FakeTokenRepository implements TokenRepository {
  String? token;

  FakeTokenRepository({this.token = 'test-jwt-token'});

  @override
  Future<String?> obtenerAccessToken() async => token;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {}

  @override
  Future<String?> obtenerRefreshToken() async => null;

  @override
  Future<bool> tokenExpirado() async => false;

  @override
  Future<void> limpiarTokens() async {}
}

void main() {
  const baseUrl = 'https://jctulgfdweeurqbmugot.supabase.co';
  const anonKey = 'test-anon-key';
  const accessToken = 'test-jwt-token';
  final fakeTokenRepo = FakeTokenRepository(token: accessToken);

  final partidaEjemplo = Partida(
    idPartida: 'partida-uuid-1',
    idUsuario: 'user-uuid-1',
    idQuest: '00000000-0000-0000-0000-000000000001',
    estado: 'ganada',
    encuentroActual: 2,
    score: 150,
    xpObtenida: 50,
    tiempoSegundos: 45,
    vidaJugador: 80,
  );

  group('HttpPartidaRepository', () {
    test('guardarPartida exitoso llama al endpoint con headers y body correctos', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('$baseUrl/functions/v1/finalizar-partida'),
        );
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(
          request.headers['Authorization'],
          equals('Bearer $accessToken'),
        );
        expect(request.headers['apikey'], equals(anonKey));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['id_partida'], equals('partida-uuid-1'));
        expect(body['id_quest'], equals('00000000-0000-0000-0000-000000000001'));
        expect(body['estado'], equals('ganada'));
        expect(body['encuentro_actual'], equals(2));
        expect(body['score'], equals(150));
        expect(body['xp_obtenida'], equals(50));
        expect(body['tiempo_segundos'], equals(45));
        expect(body['vida_jugador_actual'], equals(80));
        expect(body['vida_enemigo_actual'], isNull);

        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
        httpClient: mockClient,
      );

      await expectLater(
        repo.guardarPartida(partidaEjemplo),
        completes,
      );
    });

    test('guardarPartida sin token en TokenRepository lanza ApiException 401', () async {
      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: FakeTokenRepository(token: null),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => repo.guardarPartida(partidaEjemplo),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('Tu sesión expiró, vuelve a iniciar sesión.'),
              )
              .having((e) => e.statusCode, 'statusCode', equals(401)),
        ),
      );
    });

    test('guardarPartida con 401 lanza ApiException de sesión expirada', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'codigo': 'NO_AUTORIZADO'}),
          401,
        );
      });

      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
        httpClient: mockClient,
      );

      expect(
        () => repo.guardarPartida(partidaEjemplo),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('Tu sesión expiró, vuelve a iniciar sesión.'),
              )
              .having((e) => e.statusCode, 'statusCode', equals(401)),
        ),
      );
    });

    test('guardarPartida con 500 lanza ApiException de error de servidor', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': false, 'codigo': 'ERROR_PERSISTENCIA'}),
          500,
        );
      });

      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
        httpClient: mockClient,
      );

      expect(
        () => repo.guardarPartida(partidaEjemplo),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('Error del servidor, intenta de nuevo.'),
              )
              .having((e) => e.statusCode, 'statusCode', equals(500)),
        ),
      );
    });

    test('guardarPartida con 400 extrae el mensaje de error o detalle', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': false,
            'codigo': 'INPUT_INVALIDO',
            'detalle': 'El campo id_quest es obligatorio.',
          }),
          400,
        );
      });

      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
        httpClient: mockClient,
      );

      expect(
        () => repo.guardarPartida(partidaEjemplo),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('El campo id_quest es obligatorio.'),
              )
              .having((e) => e.statusCode, 'statusCode', equals(400)),
        ),
      );
    });

    test('guardarPartida con error de red lanza ApiException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Error de conexión');
      });

      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
        httpClient: mockClient,
      );

      expect(
        () => repo.guardarPartida(partidaEjemplo),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('No se pudo conectar al servidor, revisa tu conexión.'),
          ),
        ),
      );
    });

    test('obtenerProgreso y actualizarProgreso lanzan UnimplementedError', () {
      final repo = HttpPartidaRepository(
        baseUrl: baseUrl,
        anonKey: anonKey,
        tokenRepository: fakeTokenRepo,
      );

      expect(
        () => repo.obtenerProgreso('user-1'),
        throwsA(isA<UnimplementedError>()),
      );

      expect(
        () => repo.actualizarProgreso(ProgresoUsuario(idUsuario: 'user-1')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
