import 'package:uuid/uuid.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'database_helper.dart';

class SqliteAuthRepository implements AuthRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();
  SqliteAuthRepository(this._dbHelper);

  @override
  Future<Usuario?> obtenerPorId(String idUsuario) async {
    final db = await _dbHelper.database;
    final filas = await db.query(
      'usuario',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
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

  @override
  Future<bool> existeEmail(String email) async {
    final db = await _dbHelper.database;
    final filas = await db.query(
      'usuario',
      where: 'lower(email) = ?',
      whereArgs: [email.toLowerCase()],
    );
    return filas.isNotEmpty;
  }

  @override
  Future<bool> existeNombreUsuario(String nombreUsuario) async {
    final db = await _dbHelper.database;
    final filas = await db.query(
      'usuario',
      where: 'nombre_usuario = ?',
      whereArgs: [nombreUsuario],
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

    await db.transaction((txn) async {
      await txn.insert('usuario', {
        'id_usuario': id,
        'email': email,
        'nombre_usuario': nombreUsuario,
        'password_hash': passwordHash,
        'nombre': nombre,
        'apellido': apellido,
      });

      await txn.insert('progreso_usuario', {
        'id_progreso': _uuid.v4(),
        'id_usuario': id,
      });
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
      where: 'lower(email) = ? AND password_hash = ?',
      whereArgs: [email.toLowerCase(), passwordHash],
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
