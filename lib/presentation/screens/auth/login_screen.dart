import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/dialogo_alerta.dart';
import '../menu/menu_principal_screen.dart';
import 'auth_controller.dart';
import 'registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _mostrarPassword = false;
  bool _mantenerSesion = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = context.read<AuthController>();
    final ok = await auth.iniciarSesion(
      _emailController.text,
      _passwordController.text,
      mantenerSesion: _mantenerSesion,
    );
    if (!mounted) return;

    if (!ok && auth.error != null) {
      await DialogoAlertaSysQuest.mostrar(
        context,
        titulo: 'FALLO DE ACCESO',
        mensaje: auth.error!,
        icono: Icons.lock_clock_outlined,
        colorPrimario: AppTheme.rojoDanio,
      );
      return;
    }

    if (ok) {
      final usuario = auth.usuarioActual;
      if (usuario == null) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MenuPrincipalScreen(usuario: usuario),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _SysQuestLogo(),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar sesión',
                            style: textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Continúa tu aventura técnica.',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _emailController,
                            enabled: !auth.cargando,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Correo o Usuario',
                              hintText: 'ej. usuario@correo.com o tu_usuario',
                              prefixIcon: Icon(Icons.person_pin_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            enabled: !auth.cargando,
                            obscureText: !_mostrarPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: auth.cargando
                                ? null
                                : (_) => _iniciarSesion(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _mostrarPassword
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                onPressed: auth.cargando
                                    ? null
                                    : () => setState(
                                        () => _mostrarPassword =
                                            !_mostrarPassword,
                                      ),
                                icon: Icon(
                                  _mostrarPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            value: _mantenerSesion,
                            onChanged: auth.cargando
                                ? null
                                : (value) => setState(
                                    () => _mantenerSesion = value ?? false,
                                  ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Mantener sesión iniciada'),
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 8),
                            _ErrorBanner(mensaje: auth.error!),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.cargando ? null : _iniciarSesion,
                              child: auth.cargando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: const [
                              Expanded(child: Divider(color: Colors.white24)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'O continúa con',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white24)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _BotonOAuth(
                                icono: Icons.g_mobiledata,
                                label: 'Google',
                                color: const Color(0xFFEA4335),
                                onTap: () => DialogoAlertaSysQuest.mostrar(
                                  context,
                                  titulo: 'AUTENTICACIÓN GOOGLE',
                                  mensaje:
                                      'Redireccionando al portal seguro de Google OAuth. Configura tu Client ID en el panel docente para acceso instantáneo.',
                                  icono: Icons.mail_outline,
                                  colorPrimario: const Color(0xFFEA4335),
                                ),
                              ),
                              _BotonOAuth(
                                icono: Icons.window,
                                label: 'Outlook',
                                color: const Color(0xFF0078D4),
                                onTap: () => DialogoAlertaSysQuest.mostrar(
                                  context,
                                  titulo: 'AUTENTICACIÓN OUTLOOK',
                                  mensaje:
                                      'Conexión con cuenta institucional Microsoft / Outlook lista para enlazar con Supabase Auth.',
                                  icono: Icons.business,
                                  colorPrimario: const Color(0xFF0078D4),
                                ),
                              ),
                              _BotonOAuth(
                                icono: Icons.facebook,
                                label: 'Facebook',
                                color: const Color(0xFF1877F2),
                                onTap: () => DialogoAlertaSysQuest.mostrar(
                                  context,
                                  titulo: 'AUTENTICACIÓN FACEBOOK',
                                  mensaje:
                                      'Módulo de inicio de sesión con Meta / Facebook disponible para vincular a tu perfil de aventurero.',
                                  icono: Icons.facebook,
                                  colorPrimario: const Color(0xFF1877F2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: auth.cargando
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegistroScreen(),
                            ),
                          ),
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SysQuestLogo extends StatelessWidget {
  const _SysQuestLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppTheme.superficieElevada,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.doradoCritico, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.doradoCritico.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: AppTheme.doradoCritico,
            size: 42,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'SYSQUEST',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(letterSpacing: 2),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String mensaje;
  const _ErrorBanner({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.rojoDanio.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.rojoDanio.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.rojoDanio),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: AppTheme.azulTexto),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonOAuth extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BotonOAuth({
    required this.icono,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

