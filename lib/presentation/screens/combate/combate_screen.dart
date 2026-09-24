import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../progreso/progreso_screen.dart';
import 'combate_controller.dart';

class CombateScreen extends StatefulWidget {
  final String idQuest;
  final String idUsuario;
  const CombateScreen({
    super.key,
    required this.idQuest,
    required this.idUsuario,
  });

  @override
  State<CombateScreen> createState() => _CombateScreenState();
}

class _CombateScreenState extends State<CombateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CombateController>().cargarQuest(
        widget.idQuest,
        widget.idUsuario,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SysQuest')),
      body: Consumer<CombateController>(
        builder: (context, c, _) {
          if (c.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          final encuentro = c.encuentroActual;
          if (encuentro == null) {
            return const Center(
              child: Text('Aún no hay preguntas en esta quest.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (encuentro.esJefe)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '⚔️ ¡Reto final!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                _BarraVida(
                  label: 'Rival',
                  valor: c.vidaEnemigo,
                  max: encuentro.vidaEnemigo,
                ),
                const SizedBox(height: 8),
                _BarraVida(label: 'Jugador', valor: c.vidaJugador, max: 100),
                const SizedBox(height: 24),

                if (c.encuentroSuperado) ...[
                  Text(
                    '¡Ronda ganada!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => c.continuarSiguienteEncuentro(),
                    child: const Text('Siguiente reto'),
                  ),
                ] else ...[
                  Text(
                    encuentro.pregunta,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (!c.combateTerminado)
                    ...encuentro.opciones.map(
                      (op) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ElevatedButton(
                          onPressed: () => c.elegirOpcion(op),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('${op.letra}) ${op.texto}'),
                          ),
                        ),
                      ),
                    ),
                  if (c.mensajeUltimoTurno != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      c.mensajeUltimoTurno!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],

                if (c.combateTerminado) ...[
                  const SizedBox(height: 20),
                  Text(
                    c.jugadorGano ? '¡Victoria!' : 'Derrota',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (c.guardandoResultado)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Guardando progreso...',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Progreso guardado ✓',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProgresoScreen(idUsuario: widget.idUsuario),
                          ),
                        );
                      },
                      child: const Text('Ver mi progreso'),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BarraVida extends StatelessWidget {
  final String label;
  final int valor;
  final int max;
  const _BarraVida({
    required this.label,
    required this.valor,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $valor/$max'),
        LinearProgressIndicator(value: max == 0 ? 0 : valor / max),
      ],
    );
  }
}
