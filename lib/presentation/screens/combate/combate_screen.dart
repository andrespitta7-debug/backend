import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/encuentro.dart';
import '../../../domain/entities/opcion_encuentro.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/finalizar_partida_usecase.dart';
import '../../../domain/usecases/responder_encuentro_usecase.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../progreso/progreso_screen.dart';
import 'combate_controller.dart';

class CombateScreen extends StatefulWidget {
  final String idQuest;
  final String idUsuario;
  final String? categoriaQuest;

  const CombateScreen({
    super.key,
    required this.idQuest,
    required this.idUsuario,
    this.categoriaQuest,
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
      controller.cargarQuest(widget.idQuest, widget.idUsuario);
    });
  }

  void _detectarCambioDeEstado() {
    final controller = _controller;
    final resultado = controller?.resultadoUltimoTurno;
    if (controller == null || controller.cargando || resultado == null) return;
    if (identical(_resultadoMostrado, resultado)) return;
    _resultadoMostrado = resultado;

    if (resultado.danoAlEnemigo > 0) {
      _mostrarDanioEnemigo(resultado.danoAlEnemigo);
      _temblorEnemigo.forward(from: 0);
      if (resultado.resultado == ResultadoTurno.critico) {
        _destelloCritico.forward(from: 0);
      }
    }
    if (resultado.danoAlJugador > 0) {
      _mostrarDanioJugador(resultado.danoAlJugador);
      _sacudidaPantalla.forward(from: 0);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SysQuest'),
        actions: [
          TextButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
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
                  math.sin(_sacudidaPantalla.value * math.pi * 8) * 4;
              return Transform.translate(
                offset: Offset(desplazamiento, 0),
                child: child,
              );
            },
            child: _CombateContenido(
              controller: controller,
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await context.read<CerrarSesionUseCase>().ejecutar();
    if (!mounted) return;
    context.read<AuthController>().cerrarSesion();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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

  const _CombateContenido({
    required this.controller,
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
            vida: controller.vidaEnemigo,
            vidaMaxima: encuentro.vidaEnemigo,
            esJefe: encuentro.esJefe,
            temblor: temblorEnemigo,
            destello: destelloCritico,
            danio: danioEnemigo,
            danioKey: danioEnemigoKey,
          ),
          const SizedBox(height: 16),
          if (controller.encuentroSuperado)
            _RondaSuperada(onContinuar: onContinuar)
          else if (controller.combateTerminado)
            _FinCombate(
              gano: controller.jugadorGano,
              guardando: controller.guardandoResultado,
              onVolverAJugar: onVolverAJugar,
              onVerProgreso: onVerProgreso,
            )
          else ...[
            _DialogoPregunta(pregunta: encuentro.pregunta),
            const SizedBox(height: 16),
            _BarraVidaJugador(
              valor: controller.vidaJugador,
              danio: danioJugador,
              danioKey: danioJugadorKey,
            ),
            const SizedBox(height: 16),
            ...encuentro.opciones.map(
              (opcion) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OpcionButton(
                  letra: opcion.letra,
                  texto: opcion.texto,
                  onPressed: () => onElegirOpcion(opcion),
                ),
              ),
            ),
            if (controller.mensajeUltimoTurno != null)
              _MensajeTurno(texto: controller.mensajeUltimoTurno!),
          ],
        ],
      ),
    );
  }
}

class _EnemigoCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final borde = esJefe ? AppTheme.doradoCritico : AppTheme.superficieElevada;
    return AnimatedBuilder(
      animation: Listenable.merge([temblor, destello]),
      builder: (context, child) {
        final desplazamiento = math.sin(temblor.value * math.pi * 12) * 5;
        final brillo = destello.value;
        return Transform.translate(
          offset: Offset(desplazamiento, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(
                AppTheme.superficieNoche,
                AppTheme.doradoCritico.withValues(alpha: 0.25),
                brillo,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borde, width: esJefe ? 2 : 1),
              boxShadow: esJefe
                  ? [
                      BoxShadow(
                        color: AppTheme.doradoCritico.withValues(alpha: 0.25),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      Text(
                        _iconoCategoria(categoria),
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
                                    nombre,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                if (esJefe) const _EtiquetaJefe(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _BarraVida(
                              etiqueta: 'VIDA',
                              valor: vida,
                              maximo: vidaMaxima,
                              color: AppTheme.rojoDanio,
                            ),
                          ],
                        ),
                      ),
                    ],
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
              ),
            ),
          ),
        );
      },
    );
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

class _BarraVida extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final progreso = maximo == 0 ? 0.0 : (valor / maximo).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: progreso, end: progreso),
            duration: const Duration(milliseconds: 450),
            builder: (context, valorAnimado, _) => LinearProgressIndicator(
              minHeight: 12,
              value: valorAnimado,
              color: color,
              backgroundColor: AppTheme.superficieElevada,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcionButton extends StatelessWidget {
  final String letra;
  final String texto;
  final VoidCallback onPressed;

  const _OpcionButton({
    required this.letra,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.superficieNoche,
          foregroundColor: AppTheme.azulTexto,
          side: const BorderSide(color: AppTheme.superficieElevada),
          alignment: Alignment.centerLeft,
        ),
        child: Text('$letra  $texto'),
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
          fontWeight: FontWeight.bold,
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

class _NumeroDanio extends StatelessWidget {
  final int valor;
  final Color color;

  const _NumeroDanio({super.key, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 750),
      builder: (context, progreso, child) => Opacity(
        opacity: 1 - progreso,
        child: Transform.translate(
          offset: Offset(0, -28 * progreso),
          child: child,
        ),
      ),
      child: Text(
        '-$valor',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ).copyWith(color: color),
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
