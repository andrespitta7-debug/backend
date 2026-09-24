import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import '../combate/combate_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 8),
            TextField(controller: _apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
            const SizedBox(height: 8),
            TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Nombre de usuario')),
            const SizedBox(height: 8),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña (mín. 6 caracteres)'),
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
                      final ok = await context.read<AuthController>().registrar(
                            email: _emailCtrl.text.trim(),
                            nombreUsuario: _userCtrl.text.trim(),
                            nombre: _nombreCtrl.text.trim(),
                            apellido: _apellidoCtrl.text.trim(),
                            password: _passCtrl.text,
                          );
                      if (ok && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CombateScreen(idQuest: 'quest-001', idUsuario: context.read<AuthController>().usuarioActual!.idUsuario),
                          ),
                        );
                      }
                    },
              child: auth.cargando ? const CircularProgressIndicator() : const Text('Registrarme'),
            ),
          ],
        ),
      ),
    );
  }
}
