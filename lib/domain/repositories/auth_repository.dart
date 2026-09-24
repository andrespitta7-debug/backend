import '../entities/usuario.dart';

/// Puerto: el dominio solo sabe que puede registrar y buscar usuarios.
/// No sabe si detrás hay SQLite, Supabase, o cualquier otra cosa.
abstract class AuthRepository {
  Future<bool> existeEmailORusuario(String email, String nombreUsuario);
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
