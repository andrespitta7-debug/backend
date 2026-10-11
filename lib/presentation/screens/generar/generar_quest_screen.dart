import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../combate/combate_screen.dart';
import '../generar_quest/generar_quest_controller.dart';

class GenerarQuestScreen extends StatefulWidget {
  final String idUsuario;

  const GenerarQuestScreen({super.key, required this.idUsuario});

  @override
  State<GenerarQuestScreen> createState() => _GenerarQuestScreenState();
}

class _GenerarQuestScreenState extends State<GenerarQuestScreen> {
  final _temaController = TextEditingController();
  String? _errorTema;

  @override
  void dispose() {
    _temaController.dispose();
    super.dispose();
  }

  Future<void> _generarQuest() async {
    final tema = _temaController.text.trim();
    if (tema.length < 3 || tema.length > 100) {
      setState(() {
        _errorTema = 'El tema debe tener entre 3 y 100 caracteres.';
      });
      return;
    }

    setState(() {
      _errorTema = null;
    });
    await context.read<GenerarQuestController>().generar(tema);

    if (!mounted) return;
    final controller = context.read<GenerarQuestController>();
    final quest = controller.questGenerada;
    if (controller.estado == GenerarQuestEstado.exito && quest != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CombateScreen(
            idQuest: quest.quest.idQuest,
            idUsuario: widget.idUsuario,
            categoriaQuest: quest.quest.categoria,
            questCompleta: quest,
          ),
        ),
      );
    } else if (controller.estado == GenerarQuestEstado.error &&
        controller.mensajeError != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.mensajeError!),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: controller.puedeUsarFallback ? 'Respaldo' : 'Reintentar',
            onPressed: () {
              if (controller.puedeUsarFallback) {
                _jugarQuestRespaldo();
              } else {
                _generarQuest();
              }
            },
          ),
        ),
      );
    }
  }

  void _jugarQuestRespaldo() {
    final controller = context.read<GenerarQuestController>();
    final idSemilla = controller.questSemillaAleatoria();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CombateScreen(
          idQuest: idSemilla,
          idUsuario: widget.idUsuario,
          categoriaQuest: 'libre',
          questCompleta: null, // No hay pool narrativo en el fallback
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva quest')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Consumer<GenerarQuestController>(
          builder: (context, controller, _) {
            final generando = controller.estado == GenerarQuestEstado.generando;
            final error = _errorTema ?? controller.mensajeError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _temaController,
                  enabled: !generando,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Tema de la quest',
                    hintText: 'Ejemplo: recursividad en programación',
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: generando ? null : (_) => _generarQuest(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: generando ? null : _generarQuest,
                  child: generando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generar quest'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
