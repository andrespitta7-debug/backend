import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/encuentro.dart';
import '../../../domain/entities/opcion_encuentro.dart';
import '../../../domain/usecases/finalizar_partida_usecase.dart';
import '../../../domain/usecases/responder_encuentro_usecase.dart';
import '../../../domain/entities/quest_completa.dart';
import '../../../domain/entities/wildcard.dart';
import '../../theme/app_theme.dart';
import '../progreso/progreso_screen.dart';
import 'combate_controller.dart';

enum _PosicionCombate { jugador, enemigo }

const _emojiJugador = '🧙';
const _emojiEnemigo = '👾';

class CombateScreen extends StatefulWidget {
  final String idQuest;
  final String idUsuario;
  final String? categoriaQuest;
  final QuestCompleta? questCompleta;

  const CombateScreen({
    super.key,
    required this.idQuest,
    required this.idUsuario,
    this.categoriaQuest,
    this.questCompleta,
  });

  @override
  State<CombateScreen> createState() => _CombateScreenState();
}

class _CombateScreenState extends State<CombateScreen>
    with TickerProviderStateMixin {
  CombateController? _controller;
  ResultadoCombate? _resultadoMostrado;
  int? _danioEnemigoVisible;
  int? _danioJugadorVisible;
  int _danioEnemigoKey = 0;
  int _danioJugadorKey = 0;
  Timer? _ocultarDanioEnemigo;
  Timer? _ocultarDanioJugador;

  late final AnimationController _temblorEnemigo;
  late final AnimationController _sacudidaPantalla;
  late final AnimationController _destelloCritico;
  double _sacudidaAmplitud = 8.0;

  @override
  void initState() {
    super.initState();
    _temblorEnemigo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _sacudidaPantalla = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _destelloCritico = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<CombateController>();
      controller.addListener(_detectarCambioDeEstado);
      _controller = controller;
      controller.cargarQuest(
        widget.idQuest, 
        widget.idUsuario,
        poolNarrativo: widget.questCompleta?.poolNarrativo,
        preguntasExtra: widget.questCompleta?.preguntasExtra,
        semilla: widget.questCompleta?.semilla ?? 0,
        temaQuest: widget.questCompleta?.quest.tema ?? '',
        categoriaQuest: widget.questCompleta?.quest.categoria ?? '',
        dificultadQuest: widget.questCompleta?.quest.dificultad ?? '',
      );
    });
  }

  void _detectarCambioDeEstado() {
    final controller = _controller;
    final resultado = controller?.resultadoUltimoTurno;
    if (controller == null || controller.cargando || resultado == null) return;
    if (identical(_resultadoMostrado, resultado)) return;
    _resultadoMostrado = resultado;

    if (resultado.danoAlEnemigo > 0) {
      _sacudidaAmplitud = 4.0;
      _sacudidaPantalla.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _mostrarDanioEnemigo(resultado.danoAlEnemigo);
        _temblorEnemigo.forward(from: 0);
        if (resultado.resultado == ResultadoTurno.critico) {
          _destelloCritico.forward(from: 0);
        }
      });
    }
    if (resultado.danoAlJugador > 0) {
      _sacudidaAmplitud = 8.0;
      _sacudidaPantalla.forward(from: 0);
      _mostrarDanioJugador(resultado.danoAlJugador);
    }
  }

  void _mostrarDanioEnemigo(int danio) {
    _ocultarDanioEnemigo?.cancel();
    if (mounted) {
      setState(() {
        _danioEnemigoVisible = danio;
        _danioEnemigoKey++;
      });
    }
    _ocultarDanioEnemigo = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _danioEnemigoVisible = null);
    });
  }

  void _mostrarDanioJugador(int danio) {
    _ocultarDanioJugador?.cancel();
    if (mounted) {
      setState(() {
        _danioJugadorVisible = danio;
        _danioJugadorKey++;
      });
    }
    _ocultarDanioJugador = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _danioJugadorVisible = null);
    });
  }

  @override
  void dispose() {
    _ocultarDanioEnemigo?.cancel();
    _ocultarDanioJugador?.cancel();
    _controller?.removeListener(_detectarCambioDeEstado);
    _temblorEnemigo.dispose();
    _sacudidaPantalla.dispose();
    _destelloCritico.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final controller = _controller;
        if (controller == null || controller.combateTerminado) {
          Navigator.of(context).pop();
          return;
        }
        _mostrarMenuPausa(context);
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('SysQuest'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _mostrarMenuPausa(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.superficieNoche,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.doradoCritico.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.doradoCritico.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause, color: AppTheme.doradoCritico, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'PAUSA',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: AppTheme.doradoCritico,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<CombateController>(
        builder: (context, controller, _) {
          if (controller.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          final encuentro = controller.encuentroActual;
          if (encuentro == null) {
            return const Center(
              child: Text('Aún no hay preguntas en esta quest.'),
            );
          }

          return AnimatedBuilder(
            animation: _sacudidaPantalla,
            builder: (context, child) {
              final desplazamiento =
                  math.sin(_sacudidaPantalla.value * math.pi * 12) * _sacudidaAmplitud;
              return Transform.translate(
                offset: Offset(desplazamiento, 0),
                child: child,
              );
            },
            child: _CombateContenido(
              controller: controller,
              turnoEnProceso: controller.turnoEnProceso,
              encuentro: encuentro,
              categoria:
                  widget.categoriaQuest ??
                  (widget.idQuest == 'quest-001' ? 'debug' : null),
              danioEnemigo: _danioEnemigoVisible,
              danioEnemigoKey: _danioEnemigoKey,
              danioJugador: _danioJugadorVisible,
              danioJugadorKey: _danioJugadorKey,
              temblorEnemigo: _temblorEnemigo,
              destelloCritico: _destelloCritico,
              onElegirOpcion: controller.elegirOpcion,
              onContinuar: controller.continuarSiguienteEncuentro,
              onVolverAJugar: _volverAJugar,
              onVerProgreso: _verProgreso,
              onDismissNarrativa: () {
                setState(() {
                  controller.mensajeNarrativoActual = null;
                });
                if (controller.encuentroSuperado) {
                  controller.continuarSiguienteEncuentro();
                }
              },
            ),
          );
        },
      ),
    ));
  }

  void _mostrarMenuPausa(BuildContext context) {
    final controller = _controller;
    if (controller == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.superficieNoche,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.doradoCritico, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.doradoCritico.withValues(alpha: 0.3),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'PAUSA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 18,
                    color: AppTheme.doradoCritico,
                  ),
                ),
                const SizedBox(height: 20),
                _FilaStatPausa(
                  icono: Icons.star,
                  etiqueta: 'Score',
                  valor: '${controller.score}',
                ),
                const SizedBox(height: 10),
                _FilaStatPausa(
                  icono: Icons.flag,
                  etiqueta: 'Ronda',
                  valor: '${controller.ronda}',
                ),
                const SizedBox(height: 10),
                _FilaStatPausa(
                  icono: Icons.whatshot,
                  etiqueta: 'Enemigos derrotados',
                  valor: '${controller.enemigosDerrotados}',
                ),
                const SizedBox(height: 10),
                _FilaStatPausa(
                  icono: Icons.favorite,
                  etiqueta: 'Vida',
                  valor: '${controller.vidaJugador}/100',
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    controller.continuarCombate();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeVida,
                    foregroundColor: AppTheme.fondoNoche,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await controller.retirarse();
                    if (!mounted) return;
                    Navigator.of(this.context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Retirarse de la run'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rojoDanio,
                    side: const BorderSide(color: AppTheme.rojoDanio, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _volverAJugar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CombateScreen(idQuest: widget.idQuest, idUsuario: widget.idUsuario),
      ),
    );
  }

  void _verProgreso() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProgresoScreen(idUsuario: widget.idUsuario),
      ),
    );
  }
}

class _CombateContenido extends StatelessWidget {
  final CombateController controller;
  final bool turnoEnProceso;
  final Encuentro encuentro;
  final String? categoria;
  final int? danioEnemigo;
  final int danioEnemigoKey;
  final int? danioJugador;
  final int danioJugadorKey;
  final AnimationController temblorEnemigo;
  final AnimationController destelloCritico;
  final ValueChanged<OpcionEncuentro> onElegirOpcion;
  final VoidCallback onContinuar;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVerProgreso;
  final VoidCallback onDismissNarrativa;

  const _CombateContenido({
    required this.controller,
    required this.turnoEnProceso,
    required this.encuentro,
    required this.categoria,
    required this.danioEnemigo,
    required this.danioEnemigoKey,
    required this.danioJugador,
    required this.danioJugadorKey,
    required this.temblorEnemigo,
    required this.destelloCritico,
    required this.onElegirOpcion,
    required this.onContinuar,
    required this.onVolverAJugar,
    required this.onVerProgreso,
    required this.onDismissNarrativa,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnemigoCard(
            categoria: categoria,
            nombre: 'Encuentro ${encuentro.numero}',
            vida: context.watch<CombateController>().vidaEnemigo,
            vidaMaxima: encuentro.vidaEnemigo,
            esJefe: encuentro.esJefe,
            temblor: temblorEnemigo,
            destello: destelloCritico,
            danio: danioEnemigo,
            danioKey: danioEnemigoKey,
          ),
          const SizedBox(height: 16),
          if (controller.mensajeNarrativoActual != null)
            _PanelNarrativo(
              texto: controller.mensajeNarrativoActual!,
              onContinuar: onDismissNarrativa,
            )
          else if (controller.encuentroSuperado)
            _RondaSuperada(onContinuar: onContinuar)
          else if (controller.combateTerminado)
            _FinCombate(
              gano: controller.jugadorGano,
              guardando: controller.guardandoResultado,
              onVolverAJugar: onVolverAJugar,
              onVerProgreso: onVerProgreso,
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AvatarCombate(
                  emoji: _emojiJugador,
                  posicion: _PosicionCombate.jugador,
                  animacionActiva: controller.resultadoUltimoTurno,
                ),
                _AvatarCombate(
                  emoji: _emojiEnemigo,
                  posicion: _PosicionCombate.enemigo,
                  animacionActiva: controller.resultadoUltimoTurno,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DialogoPregunta(pregunta: encuentro.pregunta),
            const SizedBox(height: 16),
            _BarraVidaJugador(
              valor: controller.vidaJugador,
              danio: danioJugador,
              danioKey: danioJugadorKey,
            ),
            const SizedBox(height: 16),
            _FilaWildcards(
              wildcards: controller.wildcards,
              pistaActiva: controller.pistaActiva,
              golpeDobleActivo: controller.golpeDobleActivo,
              roboDeVidaActivo: controller.roboDeVidaActivo,
              turnoEnProceso: turnoEnProceso,
              onUsarWildcard: controller.usarWildcard,
            ),
            const SizedBox(height: 16),
            if (controller.pistaActiva != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.doradoCritico.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.doradoCritico.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.pistaActiva!,
                        style: const TextStyle(
                          color: AppTheme.doradoCritico,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...encuentro.opciones
                .where((op) => !controller.opcionesOcultas.contains(op.texto))
                .map(
              (opcion) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OpcionButton(
                  letra: opcion.letra,
                  texto: opcion.texto,
                  onPressed: turnoEnProceso
                      ? null
                      : () => onElegirOpcion(opcion),
                ),
              ),
            ),
            if (turnoEnProceso)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Resolviendo turno...',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: AppTheme.azulTexto,
                    ),
                  ),
                ),
              ),
            if (controller.mensajeUltimoTurno != null)
              _MensajeTurno(texto: controller.mensajeUltimoTurno!),

            // Consola narrativa (estilo Dwarf Fortress)
            const SizedBox(height: 16),
            _ConsolaNarrativa(historial: controller.historialNarrativo),
          ],
        ],
      ),
    );
  }
}

class _EnemigoCard extends StatefulWidget {
  final String? categoria;
  final String nombre;
  final int vida;
  final int vidaMaxima;
  final bool esJefe;
  final AnimationController temblor;
  final AnimationController destello;
  final int? danio;
  final int danioKey;

  const _EnemigoCard({
    required this.categoria,
    required this.nombre,
    required this.vida,
    required this.vidaMaxima,
    required this.esJefe,
    required this.temblor,
    required this.destello,
    required this.danio,
    required this.danioKey,
  });

  @override
  State<_EnemigoCard> createState() => _EnemigoCardState();
}

class _EnemigoCardState extends State<_EnemigoCard> with TickerProviderStateMixin {
  late final AnimationController _flashDanio;
  late final AnimationController _particulasController;
  int _danioKeyAnterior = -1;

  @override
  void initState() {
    super.initState();
    _flashDanio = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _particulasController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_EnemigoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danioKey != oldWidget.danioKey && widget.danio != null && widget.danio! > 0) {
      if (widget.danioKey != _danioKeyAnterior) {
        _danioKeyAnterior = widget.danioKey;
        _flashDanio.forward(from: 0.0).then((_) => _flashDanio.reverse());
        _particulasController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _flashDanio.dispose();
    _particulasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borde = widget.esJefe ? AppTheme.doradoCritico : AppTheme.superficieElevada;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.temblor, widget.destello, _flashDanio, _particulasController]),
      builder: (context, child) {
        final desplazamiento = math.sin(widget.temblor.value * math.pi * 12) * 5;
        final brillo = widget.destello.value;
        
        Color colorFondo = Color.lerp(
          AppTheme.superficieNoche,
          AppTheme.doradoCritico.withValues(alpha: 0.25),
          brillo,
        )!;

        if (_flashDanio.value > 0) {
          colorFondo = Color.lerp(
            colorFondo,
            Colors.red.withValues(alpha: 0.5),
            _flashDanio.value,
          )!;
        }

        return Transform.translate(
          offset: Offset(desplazamiento, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borde, width: widget.esJefe ? 3 : 2),
              boxShadow: widget.esJefe
                  ? [
                      BoxShadow(
                        color: AppTheme.doradoCritico.withValues(alpha: 0.25),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Text(
                            _iconoCategoria(widget.categoria),
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.nombre,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                    if (widget.esJefe) const _EtiquetaJefe(),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _BarraVida(
                                  etiqueta: 'VIDA',
                                  valor: widget.vida,
                                  maximo: widget.vidaMaxima,
                                  color: AppTheme.rojoDanio,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.danio != null)
                        Positioned(
                          right: 20,
                          top: -8,
                          child: _NumeroDanio(
                            key: ValueKey(widget.danioKey),
                            valor: widget.danio!,
                            color: AppTheme.rojoDanio,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_particulasController.isAnimating)
                  ..._generarParticulas(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _generarParticulas() {
    final progreso = _particulasController.value;
    final opacidad = 1.0 - progreso;
    final radio = 40.0 * Curves.easeOut.transform(progreso);
    
    return List.generate(6, (i) {
      final angulo = i * (math.pi * 2 / 6);
      final dx = math.cos(angulo) * radio;
      final dy = math.sin(angulo) * radio;
      
      return Positioned(
        left: 40 + dx, // Centro aproximado del icono
        top: 40 + dy,
        child: Opacity(
          opacity: opacidad,
          child: const Text('💥', style: TextStyle(fontSize: 14)),
        ),
      );
    });
  }
}

class _DialogoPregunta extends StatelessWidget {
  final String pregunta;
  const _DialogoPregunta({required this.pregunta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.superficieElevada,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.doradoCritico.withValues(alpha: 0.7),
        ),
      ),
      child: Text(pregunta, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _BarraVidaJugador extends StatelessWidget {
  final int valor;
  final int? danio;
  final int danioKey;

  const _BarraVidaJugador({
    required this.valor,
    required this.danio,
    required this.danioKey,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _BarraVida(
          etiqueta: 'TU VIDA  $valor/100',
          valor: valor,
          maximo: 100,
          color: AppTheme.verdeVida,
        ),
        if (danio != null)
          Positioned(
            right: 20,
            top: -8,
            child: _NumeroDanio(
              key: ValueKey(danioKey),
              valor: danio!,
              color: AppTheme.rojoDanio,
            ),
          ),
      ],
    );
  }
}

class _BarraVida extends StatefulWidget {
  final String etiqueta;
  final int valor;
  final int maximo;
  final Color color;

  const _BarraVida({
    required this.etiqueta,
    required this.valor,
    required this.maximo,
    required this.color,
  });

  @override
  State<_BarraVida> createState() => _BarraVidaState();
}

class _BarraVidaState extends State<_BarraVida> with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late int _valorAnterior;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _valorAnterior = widget.valor;
  }

  @override
  void didUpdateWidget(_BarraVida oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor < _valorAnterior) {
      _flashController.forward(from: 0.0).then((_) => _flashController.reverse());
    }
    _valorAnterior = widget.valor;
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progreso = widget.maximo == 0 ? 0.0 : (widget.valor / widget.maximo).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progreso),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, valorAnimado, _) {
              return AnimatedBuilder(
                animation: _flashController,
                builder: (context, _) {
                  final colorAct = Color.lerp(widget.color, Colors.white, _flashController.value)!;
                  return LinearProgressIndicator(
                    minHeight: 12,
                    value: valorAnimado,
                    color: colorAct,
                    backgroundColor: AppTheme.superficieElevada,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OpcionButton extends StatelessWidget {
  final String letra;
  final String texto;
  final VoidCallback? onPressed;

  const _OpcionButton({
    required this.letra,
    required this.texto,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.superficieNoche,
          foregroundColor: AppTheme.azulTexto,
          side: const BorderSide(color: AppTheme.superficieElevada, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$letra  ',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: AppTheme.doradoCritico,
                ),
              ),
              TextSpan(
                text: texto,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MensajeTurno extends StatelessWidget {
  final String texto;
  const _MensajeTurno({required this.texto});

  @override
  Widget build(BuildContext context) {
    final esDanio = texto.contains('Incorrecto');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: esDanio ? AppTheme.rojoDanio : AppTheme.doradoCritico,
          fontFamily: 'PressStart2P',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RondaSuperada extends StatelessWidget {
  final VoidCallback onContinuar;
  const _RondaSuperada({required this.onContinuar});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.shield, color: AppTheme.doradoCritico, size: 56),
        const SizedBox(height: 12),
        Text(
          '¡Ronda ganada!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onContinuar,
          child: const Text('Siguiente reto'),
        ),
      ],
    );
  }
}

class _FinCombate extends StatelessWidget {
  final bool gano;
  final bool guardando;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVerProgreso;

  const _FinCombate({
    required this.gano,
    required this.guardando,
    required this.onVolverAJugar,
    required this.onVerProgreso,
  });

  @override
  Widget build(BuildContext context) {
    final xp = gano
        ? FinalizarPartidaUseCase.xpPorVictoria
        : FinalizarPartidaUseCase.xpPorDerrota;
    return Column(
      children: [
        Icon(
          gano ? Icons.emoji_events : Icons.close,
          color: gano ? AppTheme.doradoCritico : AppTheme.rojoDanio,
          size: 72,
        ),
        const SizedBox(height: 12),
        Text(
          gano ? '¡Victoria!' : 'Derrota',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text('XP ganada: $xp', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(
          guardando ? 'Guardando progreso...' : 'Progreso guardado',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!guardando) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onVolverAJugar,
            child: const Text('Volver a jugar'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onVerProgreso,
            child: const Text('Mi progreso'),
          ),
        ],
      ],
    );
  }
}

class _EtiquetaJefe extends StatelessWidget {
  const _EtiquetaJefe();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.doradoCritico,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'JEFE',
        style: TextStyle(
          color: AppTheme.fondoNoche,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NumeroDanio extends StatefulWidget {
  final int valor;
  final Color color;

  const _NumeroDanio({super.key, required this.valor, required this.color});

  @override
  State<_NumeroDanio> createState() => _NumeroDanioState();
}

class _NumeroDanioState extends State<_NumeroDanio> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacidad;
  late final Animation<double> _desplazamiento;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacidad = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15), 
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),          
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25), 
    ]).animate(_controller);

    _desplazamiento = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esCritico = widget.valor >= 25;
    final double fontSize = esCritico ? 32 : 24;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacidad.value,
        child: Transform.translate(
          offset: Offset(0, _desplazamiento.value),
          child: child,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            '-${widget.valor}',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: fontSize,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = Colors.black,
            ),
          ),
          Text(
            '-${widget.valor}',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: fontSize,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

String _iconoCategoria(String? categoria) {
  switch (categoria) {
    case 'debug':
      return '🐞';
    case 'database':
      return '🗄️';
    case 'algorithm':
      return '🧩';
    case 'network':
      return '🌐';
    case 'architecture':
      return '🏛️';
    case 'cyber':
      return '🛡️';
    default:
      return '👾';
  }
}

class _PanelNarrativo extends StatelessWidget {
  final String texto;
  final VoidCallback onContinuar;

  const _PanelNarrativo({
    required this.texto,
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.superficieElevada,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.azulTexto.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.azulTexto.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.azulTexto, size: 48),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.azulTexto,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'NUEVO',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: AppTheme.fondoNoche,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppTheme.azulTexto,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: onContinuar,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.azulTexto,
              foregroundColor: AppTheme.fondoNoche,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsolaNarrativa extends StatefulWidget {
  final List<String> historial;
  const _ConsolaNarrativa({required this.historial});
  
  @override
  State<_ConsolaNarrativa> createState() => _ConsolaNarrativaState();
}

class _ConsolaNarrativaState extends State<_ConsolaNarrativa> {
  bool _expandida = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.superficieNoche,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.superficieElevada, width: 2),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandida = !_expandida),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '> HISTORIAL DE LA RUN',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: AppTheme.azulTexto,
                    ),
                  ),
                  Icon(
                    _expandida ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.azulTexto,
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _expandida ? 180 : 0,
              padding: _expandida
                  ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
                  : EdgeInsets.zero,
              child: ListView.builder(
                itemCount: widget.historial.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '> ${widget.historial[index]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.azulTexto.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCombate extends StatefulWidget {
  final String emoji;
  final _PosicionCombate posicion;
  final ResultadoCombate? animacionActiva;

  const _AvatarCombate({
    required this.emoji,
    required this.posicion,
    required this.animacionActiva,
  });

  @override
  State<_AvatarCombate> createState() => _AvatarCombateState();
}

class _AvatarCombateState extends State<_AvatarCombate> {
  double _desplazamiento = 0;
  double _escala = 1.0;
  double _rotacion = 0.0;
  ResultadoCombate? _ultimoResultadoProcesado;
  Timer? _timerAnimacion;

  @override
  void didUpdateWidget(covariant _AvatarCombate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animacionActiva != null &&
        widget.animacionActiva != _ultimoResultadoProcesado) {
      _ultimoResultadoProcesado = widget.animacionActiva;
      _activarAnimacion(widget.animacionActiva!);
    }
  }

  @override
  void dispose() {
    _timerAnimacion?.cancel();
    super.dispose();
  }

  void _activarAnimacion(ResultadoCombate resultado) {
    final esAcierto = resultado.resultado == ResultadoTurno.acierto ||
        resultado.resultado == ResultadoTurno.critico;
    final esFallo = resultado.resultado == ResultadoTurno.fallo;

    _timerAnimacion?.cancel();

    if (esAcierto && widget.posicion == _PosicionCombate.jugador) {
      setState(() {
        _desplazamiento = 50;
        _escala = 1.3;
        _rotacion = -15 * (math.pi / 180);
      });
      _timerAnimacion = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _desplazamiento = 0;
            _escala = 1.0;
            _rotacion = 0.0;
          });
        }
      });
    } else if (esFallo && widget.posicion == _PosicionCombate.enemigo) {
      setState(() => _desplazamiento = -50);
      _timerAnimacion = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _desplazamiento = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 120,
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: widget.posicion == _PosicionCombate.jugador
              ? Alignment.centerLeft
              : Alignment.centerRight,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              left: widget.posicion == _PosicionCombate.jugador ? _desplazamiento : null,
              right: widget.posicion == _PosicionCombate.enemigo ? -_desplazamiento : null,
              top: 0,
              bottom: 0,
              width: 80,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                transformAlignment: Alignment.center,
                // ignore: deprecated_member_use
                transform: Matrix4.identity()
                  ..rotateZ(_rotacion)
                  ..scale(_escala),
                child: Center(
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaStatPausa extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _FilaStatPausa({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.superficieElevada,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.azulTexto.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppTheme.azulTexto, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: AppTheme.azulTexto,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: AppTheme.doradoCritico,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaWildcards extends StatelessWidget {
  final Map<TipoWildcard, int> wildcards;
  final String? pistaActiva;
  final bool golpeDobleActivo;
  final bool roboDeVidaActivo;
  final bool turnoEnProceso;
  final ValueChanged<TipoWildcard> onUsarWildcard;

  const _FilaWildcards({
    required this.wildcards,
    required this.pistaActiva,
    required this.golpeDobleActivo,
    required this.roboDeVidaActivo,
    required this.turnoEnProceso,
    required this.onUsarWildcard,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: TipoWildcard.values.map((tipo) {
        final cantidad = wildcards[tipo] ?? 0;
        final activa = _esActiva(tipo);
        return _WildcardButton(
          tipo: tipo,
          cantidad: cantidad,
          activa: activa,
          habilitada: cantidad > 0 && !turnoEnProceso,
          onPressed: () => onUsarWildcard(tipo),
        );
      }).toList(),
    );
  }

  bool _esActiva(TipoWildcard tipo) {
    if (tipo == TipoWildcard.pista) return pistaActiva != null;
    if (tipo == TipoWildcard.golpeDoble) return golpeDobleActivo;
    if (tipo == TipoWildcard.roboDeVida) return roboDeVidaActivo;
    return false;
  }
}

class _WildcardButton extends StatelessWidget {
  final TipoWildcard tipo;
  final int cantidad;
  final bool activa;
  final bool habilitada;
  final VoidCallback onPressed;

  const _WildcardButton({
    required this.tipo,
    required this.cantidad,
    required this.activa,
    required this.habilitada,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final w = Wildcard(tipo: tipo, cantidad: cantidad);
    final color = activa
        ? AppTheme.verdeVida
        : (habilitada ? AppTheme.doradoCritico : AppTheme.superficieElevada);

    return Tooltip(
      message: w.descripcion,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: habilitada ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.superficieNoche,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 2),
              boxShadow: activa
                  ? [BoxShadow(color: AppTheme.verdeVida.withValues(alpha: 0.4), blurRadius: 12)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(w.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 2),
                Text(
                  'x$cantidad',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
