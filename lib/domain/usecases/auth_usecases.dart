import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';
import 'password_hasher.dart';

class RegistroInvalidoException implements Exception {
  final String mensaje;
  RegistroInvalidoException(this.mensaje);
}

class CredencialesInvalidasException implements Exception {}

class RegistrarUsuarioUseCase {
  final AuthRepository _repo;
  RegistrarUsuarioUseCase(this._repo);

  Future<Usuario> ejecutar({
    required String email,
    required String nombreUsuario,
    required String nombre,
    required String apellido,
    required String passwordPlano,
  }) async {
    if (email.isEmpty || !email.contains('@')) {
      throw RegistroInvalidoException('Correo inválido.');
    }
    if (passwordPlano.length < 6) {
      throw RegistroInvalidoException('La contraseña debe tener al menos 6 caracteres.');
    }
    final yaExiste = await _repo.existeEmailORusuario(email, nombreUsuario);
    if (yaExiste) {
      throw RegistroInvalidoException('Ese correo o nombre de usuario ya está registrado.');
    }

    return _repo.registrar(
      email: email,
      nombreUsuario: nombreUsuario,
      nombre: nombre,
      apellido: apellido,
      passwordHash: PasswordHasher.hash(passwordPlano),
    );
  }
}

class IniciarSesionUseCase {
  final AuthRepository _repo;
  IniciarSesionUseCase(this._repo);

  Future<Usuario> ejecutar(String email, String passwordPlano) async {
    final usuario = await _repo.autenticar(email, PasswordHasher.hash(passwordPlano));
    if (usuario == null) throw CredencialesInvalidasException();
    return usuario;
  }
}
