import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/perfil_usecases.dart';
import '../../theme/app_theme.dart';

class PerfilScreen extends StatefulWidget {
  final Usuario usuario;

  const PerfilScreen({super.key, required this.usuario});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late Usuario _usuario;
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _nombreUsuarioController;
  bool _editando = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _nombreController = TextEditingController(text: _usuario.nombre);
    _apellidoController = TextEditingController(text: _usuario.apellido);
    _nombreUsuarioController = TextEditingController(
      text: _usuario.nombreUsuario,
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _nombreUsuarioController.dispose();
    super.dispose();
  }

  String? _validarTexto(String? value, String etiqueta) {
    final texto = value?.trim() ?? '';
    if (texto.length < 2 || texto.length > 50) {
      return '$etiqueta es obligatorio y debe tener entre 2 y 50 caracteres.';
    }
    return null;
  }

  String? _validarNombreUsuario(String? value) {
    final nombreUsuario = value?.trim() ?? '';
    if (nombreUsuario.length < 3 ||
        nombreUsuario.length > 20 ||
        !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(nombreUsuario)) {
      return 'El nombre de usuario debe tener entre 3 y 20 caracteres y solo puede contener letras, números y guion bajo.';
    }
    return null;
  }

  void _activarEdicion() {
    setState(() {
      _error = null;
      _editando = true;
    });
  }

  void _cancelarEdicion() {
    _nombreController.text = _usuario.nombre;
    _apellidoController.text = _usuario.apellido;
    _nombreUsuarioController.text = _usuario.nombreUsuario;
    setState(() {
      _error = null;
      _editando = false;
    });
  }

  Future<void> _guardar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final usuarioActualizado = await context
          .read<ActualizarPerfilUseCase>()
          .ejecutar(
            usuarioActual: _usuario,
            nombre: _nombreController.text,
            apellido: _apellidoController.text,
            nombreUsuario: _nombreUsuarioController.text,
          );
      if (!mounted) return;
      setState(() {
        _usuario = usuarioActualizado;
        _editando = false;
        _guardando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error is RegistroInvalidoException
            ? error.mensaje
            : 'No se pudo actualizar el perfil, intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _editando ? _buildFormulario(context) : _buildLectura(context),
        ),
      ),
    );
  }

  Widget _buildLectura(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PerfilAvatar(),
        const SizedBox(height: 18),
        Text(
          '${_usuario.nombre} ${_usuario.apellido}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        _DatoPerfil(label: 'Nombre', valor: _usuario.nombre),
        _DatoPerfil(label: 'Apellido', valor: _usuario.apellido),
        _DatoPerfil(label: 'Nombre de usuario', valor: _usuario.nombreUsuario),
        _DatoPerfil(label: 'Correo', valor: _usuario.email),
        const SizedBox(height: 4),
        const Text(
          'El correo no se puede cambiar por ahora',
          style: TextStyle(color: AppTheme.azulTexto, fontSize: 12),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _activarEdicion,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar perfil'),
        ),
      ],
    );
  }

  Widget _buildFormulario(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar perfil',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreController,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => _validarTexto(value, 'El nombre'),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _apellidoController,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => _validarTexto(value, 'El apellido'),
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nombreUsuarioController,
                enabled: !_guardando,
                textInputAction: TextInputAction.done,
                validator: _validarNombreUsuario,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(mensaje: _error!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Guardar'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _guardando ? null : _cancelarEdicion,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerfilAvatar extends StatelessWidget {
  const _PerfilAvatar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppTheme.superficieElevada,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.azulTexto, width: 2),
        ),
        child: const Icon(
          Icons.person_outline,
          color: AppTheme.azulTexto,
          size: 42,
        ),
      ),
    );
  }
}

class _DatoPerfil extends StatelessWidget {
  final String label;
  final String valor;

  const _DatoPerfil({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(title: Text(label), subtitle: Text(valor)),
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
