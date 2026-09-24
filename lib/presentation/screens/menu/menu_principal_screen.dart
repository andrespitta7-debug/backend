import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../combate/combate_screen.dart';
import '../generar/generar_quest_screen.dart';
import '../progreso/progreso_screen.dart';

class MenuPrincipalScreen extends StatelessWidget {
  final Usuario usuario;

  const MenuPrincipalScreen({super.key, required this.usuario});

  Future<void> _cerrarSesion(BuildContext context) async {
    await context.read<CerrarSesionUseCase>().ejecutar();
    if (!context.mounted) return;
    context.read<AuthController>().cerrarSesion();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = usuario.nombre.trim().isEmpty
        ? usuario.nombreUsuario
        : usuario.nombre;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SysQuest'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hola, $nombre',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '¿Qué aventura quieres jugar hoy?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              _MenuCard(
                icon: Icons.shield_outlined,
                accent: AppTheme.doradoCritico,
                title: 'Quest del sistema',
                subtitle:
                    'Juega la quest de prueba y pon a prueba tus habilidades.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CombateScreen(
                      idQuest: 'quest-001',
                      idUsuario: usuario.idUsuario,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                icon: Icons.auto_awesome,
                accent: AppTheme.verdeVida,
                title: 'Nueva quest con IA',
                subtitle:
                    'Escribe un tema y genera una aventura personalizada.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GenerarQuestScreen(idUsuario: usuario.idUsuario),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MenuCard(
                icon: Icons.insights_outlined,
                accent: AppTheme.azulTexto,
                title: 'Mi progreso',
                subtitle: 'Consulta tus victorias, experiencia y nivel actual.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProgresoScreen(idUsuario: usuario.idUsuario),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => _cerrarSesion(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
