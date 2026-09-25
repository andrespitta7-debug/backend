import '../entities/usuario.dart';

/// Puerto: el dominio solo sabe que puede registrar y buscar usuarios.
/// No sabe si detrás hay SQLite, Supabase, o cualquier otra cosa.
abstract class AuthRepository {
  Future<Usuario?> obtenerPorId(String idUsuario);

  Future<bool> existeEmail(String email);

  Future<bool> existeNombreUsuario(String nombreUsuario);

  Future<void> actualizar(Usuario usuario);

  Future<bool> existeNombreUsuarioExcepto(
    String nombreUsuario,
    String idUsuario,
  );

  Future<Usuario> registrar({
    required String email,
    required String nombreUsuario,
    required String nombre,
    required String apellido,
    required String passwordHash,
  });

  /// Devuelve el Usuario si el email y el hash coinciden; null si no.
  Future<Usuario?> autenticar(String email, String passwordHash);
}
