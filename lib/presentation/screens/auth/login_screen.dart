import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import 'registro_screen.dart';
import '../combate/combate_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('SysQuest — Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: auth.cargando
                  ? null
                  : () async {
                      final ok = await context
                          .read<AuthController>()
                          .iniciarSesion(_emailCtrl.text.trim(), _passCtrl.text);
                      if (ok && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CombateScreen(idQuest: 'quest-001', idUsuario: context.read<AuthController>().usuarioActual!.idUsuario),
                          ),
                        );
                      }
                    },
              child: auth.cargando
                  ? const CircularProgressIndicator()
                  : const Text('Entrar'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegistroScreen()),
              ),
              child: const Text('¿No tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    );
  }
}
