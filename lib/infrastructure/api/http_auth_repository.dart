import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import 'api_exception.dart';
import 'auth_api_client.dart';

/// Implementación del puerto [AuthRepository] que se comunica con
/// el backend de Supabase mediante [AuthApiClient].
class HttpAuthRepository implements AuthRepository {
  final AuthApiClient _client;

  HttpAuthRepository(this._client);

  static const _mensajeNoImplementado =
      'Este método aún no está implementado en el backend. '
      'Se completará cuando exista el Edge Function correspondiente.';

  @override
  Future<Usuario> registrar({
    required String email,
    required String nombreUsuario,
    required String nombre,
    required String apellido,
    required String passwordPlano,
  }) async {
    final result = await _client.registrar(
      email: email,
      password: passwordPlano,
      nombre: nombre,
      apellido: apellido,
      nombreUsuario: nombreUsuario,
    );
    return result.usuario;
  }

  @override
  Future<Usuario?> autenticar(String email, String passwordHash) async {
    try {
      final result = await _client.login(
        email: email,
        password: passwordHash,
      );
      return result.usuario;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Usuario?> obtenerPorId(String idUsuario) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<bool> existeEmail(String email) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<bool> existeNombreUsuario(String nombreUsuario) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<bool> existeNombreUsuarioExcepto(
    String nombreUsuario,
    String idUsuario,
  ) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<void> actualizar(Usuario usuario) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<void> cambiarPassword(String idUsuario, String nuevoHash) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }

  @override
  Future<void> eliminarCuenta(String idUsuario) async {
    throw UnimplementedError(_mensajeNoImplementado);
  }
}
