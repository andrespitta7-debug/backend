import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/usecases/responder_encuentro_usecase.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/finalizar_partida_usecase.dart';
import 'domain/usecases/obtener_progreso_usecase.dart';
import 'infrastructure/persistence/sqlite/database_helper.dart';
import 'infrastructure/persistence/sqlite/sqlite_quest_repository.dart';
import 'infrastructure/persistence/sqlite/sqlite_auth_repository.dart';
import 'infrastructure/persistence/sqlite/sqlite_partida_repository.dart';
import 'presentation/screens/combate/combate_controller.dart';
import 'presentation/screens/auth/auth_controller.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/progreso/progreso_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Composición de dependencias (único lugar que elige SQLite) ---
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.insertarDatosDePrueba();

  final questRepository = SqliteQuestRepository(dbHelper);
  final authRepository = SqliteAuthRepository(dbHelper);
  final partidaRepository = SqlitePartidaRepository(dbHelper);

  final responderUseCase = ResponderEncuentroUseCase();
  final registrarUseCase = RegistrarUsuarioUseCase(authRepository);
  final iniciarSesionUseCase = IniciarSesionUseCase(authRepository);
  final finalizarPartidaUseCase = FinalizarPartidaUseCase(partidaRepository);
  final obtenerProgresoUseCase = ObtenerProgresoUseCase(partidaRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CombateController(questRepository, responderUseCase, finalizarPartidaUseCase),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(registrarUseCase, iniciarSesionUseCase),
        ),
        ChangeNotifierProvider(
          create: (_) => ProgresoController(obtenerProgresoUseCase),
        ),
      ],
      child: const SysQuestApp(),
    ),
  );
}

class SysQuestApp extends StatelessWidget {
  const SysQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
