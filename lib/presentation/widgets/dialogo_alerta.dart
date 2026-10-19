import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Diálogo modal llamativo y estilizado para alertas y errores en SysQuest
class DialogoAlertaSysQuest extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final IconData icono;
  final Color colorPrimario;
  final String textoBoton;
  final VoidCallback? onAceptar;
  final String? textoBotonSecundario;
  final VoidCallback? onSecundario;

  const DialogoAlertaSysQuest({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.icono = Icons.error_outline,
    this.colorPrimario = AppTheme.rojoDanio,
    this.textoBoton = 'Entendido',
    this.onAceptar,
    this.textoBotonSecundario,
    this.onSecundario,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    IconData icono = Icons.error_outline,
    Color colorPrimario = AppTheme.rojoDanio,
    String textoBoton = 'Entendido',
    VoidCallback? onAceptar,
    String? textoBotonSecundario,
    VoidCallback? onSecundario,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogoAlertaSysQuest(
        titulo: titulo,
        mensaje: mensaje,
        icono: icono,
        colorPrimario: colorPrimario,
        textoBoton: textoBoton,
        onAceptar: onAceptar != null
            ? () {
                Navigator.of(ctx).pop();
                onAceptar();
              }
            : () => Navigator.of(ctx).pop(),
        textoBotonSecundario: textoBotonSecundario,
        onSecundario: onSecundario != null
            ? () {
                Navigator.of(ctx).pop();
                onSecundario();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF161922),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorPrimario, width: 2),
          boxShadow: [
            BoxShadow(
              color: colorPrimario.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorPrimario.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: colorPrimario, width: 2),
              ),
              child: Icon(icono, color: colorPrimario, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: colorPrimario,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.azulTexto,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimario,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onAceptar ?? () => Navigator.of(context).pop(),
                child: Text(
                  textoBoton,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (textoBotonSecundario != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulTexto,
                    side: const BorderSide(color: Color(0xFF3E455B), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onSecundario ?? () => Navigator.of(context).pop(),
                  child: Text(
                    textoBotonSecundario!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
