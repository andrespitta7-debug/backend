import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';
import 'auth_usecases.dart';

class ActualizarPerfilUseCase {
  final AuthRepository _repo;

  ActualizarPerfilUseCase(this._repo);

  Future<Usuario> ejecutar({
    required Usuario usuarioActual,
    required String nombre,
    required String apellido,
    required String nombreUsuario,
  }) async {
    final nombreNormalizado = nombre.trim();
    final apellidoNormalizado = apellido.trim();
    final nombreUsuarioNormalizado = nombreUsuario.trim();

    if (nombreNormalizado.length < 2 || nombreNormalizado.length > 50) {
      throw RegistroInvalidoException(
        'El nombre es obligatorio y debe tener entre 2 y 50 caracteres.',
      );
    }
    if (apellidoNormalizado.length < 2 || apellidoNormalizado.length > 50) {
      throw RegistroInvalidoException(
        'El apellido es obligatorio y debe tener entre 2 y 50 caracteres.',
      );
    }
    if (nombreUsuarioNormalizado.length < 3 ||
        nombreUsuarioNormalizado.length > 20 ||
        !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(nombreUsuarioNormalizado)) {
      throw RegistroInvalidoException(
        'El nombre de usuario debe tener entre 3 y 20 caracteres y solo puede contener letras, números y guion bajo.',
      );
    }

    if (nombreUsuarioNormalizado != usuarioActual.nombreUsuario &&
        await _repo.existeNombreUsuarioExcepto(
          nombreUsuarioNormalizado,
          usuarioActual.idUsuario,
        )) {
      throw RegistroInvalidoException(
        'El nombre de usuario ya está registrado.',
      );
    }

    final usuarioActualizado = Usuario(
      idUsuario: usuarioActual.idUsuario,
      email: usuarioActual.email,
      nombreUsuario: nombreUsuarioNormalizado,
      nombre: nombreNormalizado,
      apellido: apellidoNormalizado,
    );
    await _repo.actualizar(usuarioActualizado);
    return usuarioActualizado;
  }
}
