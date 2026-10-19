import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/wildcard.dart';

/// Diálogo interactivo para la Tienda del Mercader del Overworld 2D
class MercaderTiendaDialog extends StatefulWidget {
  final int scoreDisponible;
  final Map<TipoWildcard, int> inventarioActual;
  final Function(TipoWildcard tipo, int costo) onComprar;

  const MercaderTiendaDialog({
    super.key,
    required this.scoreDisponible,
    required this.inventarioActual,
    required this.onComprar,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required int scoreDisponible,
    required Map<TipoWildcard, int> inventarioActual,
    required Function(TipoWildcard tipo, int costo) onComprar,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => MercaderTiendaDialog(
        scoreDisponible: scoreDisponible,
        inventarioActual: inventarioActual,
        onComprar: onComprar,
      ),
    );
  }

  @override
  State<MercaderTiendaDialog> createState() => _MercaderTiendaDialogState();
}

class _MercaderTiendaDialogState extends State<MercaderTiendaDialog> {
  late int _score;
  late Map<TipoWildcard, int> _inventario;

  @override
  void initState() {
    super.initState();
    _score = widget.scoreDisponible;
    _inventario = Map.from(widget.inventarioActual);
  }

  void _intentarComprar(TipoWildcard tipo, int costo, String nombre) {
    if (_score < costo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Oro/Puntos insuficientes para comprar $nombre!'),
          backgroundColor: AppTheme.rojoDanio,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _score -= costo;
      _inventario[tipo] = (_inventario[tipo] ?? 0) + 1;
    });

    widget.onComprar(tipo, costo);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Compraste 1x $nombre por $costo pts!'),
        backgroundColor: AppTheme.verdeVida,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16152B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purpleAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withValues(alpha: 0.3),
              blurRadius: 28,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Mercader
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: const Text('🧙‍♂️', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIENDA DEL MERCADER',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¡Intercambia tus puntos por mejoras tácticas!',
                        style: TextStyle(
                          color: AppTheme.azulTexto.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                )
              ],
            ),
            const SizedBox(height: 16),
            // Balance de oro / score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.doradoCritico.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🪙 ORO / PUNTOS:',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: AppTheme.doradoCritico,
                    ),
                  ),
                  Text(
                    '$_score pts',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: AppTheme.doradoCritico,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Lista de Artículos
            _ArticuloMercader(
              icono: '💡',
              nombre: 'Pergamino de Pistas',
              descripcion: 'Muestra la explicación teórica o pista para la pregunta actual.',
              costo: 100,
              cantidad: _inventario[TipoWildcard.pista] ?? 0,
              onComprar: () => _intentarComprar(
                TipoWildcard.pista,
                100,
                'Pergamino de Pistas',
              ),
            ),
            const SizedBox(height: 10),
            _ArticuloMercader(
              icono: '⚔️',
              nombre: 'Filo Crítico (Golpe Doble)',
              descripcion: 'Duplica el daño que infliges al enemigo en tu siguiente acierto.',
              costo: 150,
              cantidad: _inventario[TipoWildcard.golpeDoble] ?? 0,
              onComprar: () => _intentarComprar(
                TipoWildcard.golpeDoble,
                150,
                'Filo Crítico',
              ),
            ),
            const SizedBox(height: 10),
            _ArticuloMercader(
              icono: '❤️',
              nombre: 'Poción Vampírica (Robo de Vida)',
              descripcion: 'Restaura tus puntos de vida equivalentes al daño infligido.',
              costo: 200,
              cantidad: _inventario[TipoWildcard.roboDeVida] ?? 0,
              onComprar: () => _intentarComprar(
                TipoWildcard.roboDeVida,
                200,
                'Poción Vampírica',
              ),
            ),
            const SizedBox(height: 10),
            _ArticuloMercader(
              icono: '🎯',
              nombre: 'Orbe 50/50',
              descripcion: 'Descarta 2 opciones incorrectas inmediatamente.',
              costo: 120,
              cantidad: _inventario[TipoWildcard.cincuentaCincuenta] ?? 0,
              onComprar: () => _intentarComprar(
                TipoWildcard.cincuentaCincuenta,
                120,
                'Orbe 50/50',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Regresar al Mapa', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticuloMercader extends StatelessWidget {
  final String icono;
  final String nombre;
  final String descripcion;
  final int costo;
  final int cantidad;
  final VoidCallback onComprar;

  const _ArticuloMercader({
    required this.icono,
    required this.nombre,
    required this.descripcion,
    required this.costo,
    required this.cantidad,
    required this.onComprar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF221F3B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(icono, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      'Posees: $cantidad',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: AppTheme.azulTexto.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.doradoCritico,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(60, 36),
            ),
            onPressed: onComprar,
            child: Text(
              '$costo pts',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
