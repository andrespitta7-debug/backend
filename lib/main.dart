import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/entities/usuario.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/finalizar_partida_usecase.dart';
import 'domain/usecases/generar_quest_usecase.dart';
import 'domain/usecases/obtener_progreso_usecase.dart';
import 'domain/usecases/responder_encuentro_usecase.dart';
import 'infrastructure/generation/stub_quest_generator.dart';
import 'infrastructure/persistence/shared_preferences_sesion_repository.dart';
import 'infrastructure/persistence/sqlite/database_helper.dart';
import 'infrastructure/persistence/sqlite/sqlite_auth_repository.dart';
import 'infrastructure/persistence/sqlite/sqlite_partida_repository.dart';
import 'infrastructure/persistence/sqlite/sqlite_quest_repository.dart';
import 'presentation/screens/auth/auth_controller.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/combate/combate_controller.dart';
import 'presentation/screens/generar_quest/generar_quest_controller.dart';
import 'presentation/screens/menu/menu_principal_screen.dart';
import 'presentation/screens/progreso/progreso_controller.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Composición de dependencias (único lugar que elige SQLite) ---
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.insertarDatosDePrueba();

  final questRepository = SqliteQuestRepository(dbHelper);
  final authRepository = SqliteAuthRepository(dbHelper);
  final partidaRepository = SqlitePartidaRepository(dbHelper);
  final preferences = await SharedPreferences.getInstance();
  final sesionRepository = SharedPreferencesSesionRepository(preferences);

  final responderUseCase = ResponderEncuentroUseCase();
  final registrarUseCase = RegistrarUsuarioUseCase(
    authRepository,
    sesionRepository,
  );
  final iniciarSesionUseCase = IniciarSesionUseCase(
    authRepository,
    sesionRepository,
  );
  final restaurarSesionUseCase = RestaurarSesionUseCase(
    sesionRepository,
    authRepository,
  );
  final cerrarSesionUseCase = CerrarSesionUseCase(sesionRepository);
  final finalizarPartidaUseCase = FinalizarPartidaUseCase(partidaRepository);
  final obtenerProgresoUseCase = ObtenerProgresoUseCase(partidaRepository);
  // Aquí se cambia StubQuestGenerator por el adaptador real cuando exista.
  final generarQuestUseCase = GenerarQuestUseCase(
    StubQuestGenerator(),
    questRepository,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<GenerarQuestUseCase>(create: (_) => generarQuestUseCase),
        Provider<RestaurarSesionUseCase>(create: (_) => restaurarSesionUseCase),
        Provider<CerrarSesionUseCase>(create: (_) => cerrarSesionUseCase),
        ChangeNotifierProvider(
          create: (_) => GenerarQuestController(generarQuestUseCase),
        ),
        ChangeNotifierProvider(
          create: (_) => CombateController(
            questRepository,
            responderUseCase,
            finalizarPartidaUseCase,
          ),
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
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Usuario? _usuario;
  bool _restaurando = true;

  @override
  void initState() {
    super.initState();
    _restaurarSesion();
  }

  Future<void> _restaurarSesion() async {
    final usuario = await context.read<RestaurarSesionUseCase>().ejecutar();
    if (!mounted) return;
    setState(() {
      _usuario = usuario;
      _restaurando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restaurando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_usuario == null) return const LoginScreen();
    return MenuPrincipalScreen(usuario: _usuario!);
  }
}
