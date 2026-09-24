import 'package:uuid/uuid.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'database_helper.dart';

class SqliteAuthRepository implements AuthRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();
  SqliteAuthRepository(this._dbHelper);

  @override
  Future<bool> existeEmailORusuario(String email, String nombreUsuario) async {
    final db = await _dbHelper.database;
    final filas = await db.query(
      'usuario',
      where: 'email = ? OR nombre_usuario = ?',
      whereArgs: [email, nombreUsuario],
    );
    return filas.isNotEmpty;
  }

  @override
  Future<Usuario> registrar({
    required String email,
    required String nombreUsuario,
    required String nombre,
    required String apellido,
    required String passwordHash,
  }) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();

    await db.insert('usuario', {
      'id_usuario': id,
      'email': email,
      'nombre_usuario': nombreUsuario,
      'password_hash': passwordHash,
      'nombre': nombre,
      'apellido': apellido,
    });

    // El registro de progreso nace junto con el usuario.
    await db.insert('progreso_usuario', {
      'id_progreso': _uuid.v4(),
      'id_usuario': id,
    });

    return Usuario(
      idUsuario: id,
      email: email,
      nombreUsuario: nombreUsuario,
      nombre: nombre,
      apellido: apellido,
    );
  }

  @override
  Future<Usuario?> autenticar(String email, String passwordHash) async {
    final db = await _dbHelper.database;
    final filas = await db.query(
      'usuario',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, passwordHash],
    );
    if (filas.isEmpty) return null;
    final r = filas.first;
    return Usuario(
      idUsuario: r['id_usuario'] as String,
      email: r['email'] as String,
      nombreUsuario: r['nombre_usuario'] as String,
      nombre: r['nombre'] as String? ?? '',
      apellido: r['apellido'] as String? ?? '',
    );
  }
}
