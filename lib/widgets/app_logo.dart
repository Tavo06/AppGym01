import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

/// Logo de Vatio: loseta biselada (esquinas cortadas, como los botones) con
/// el degradado de marca y un rayo lima. Opcionalmente, el nombre debajo.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 84,
    this.radius = 24,
    this.withText = true,
    this.textSize = 26,
  });

  final double size;

  /// Tamaño del corte de las esquinas (antes, radio del redondeo).
  final double radius;
  final bool withText;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: CustomPaint(
            // Corte del 16 % como máximo: más parecería un octógono.
            painter: VatioMarkPainter(
              bevel: radius < size * 0.16 ? radius : size * 0.16,
              shadow: true,
            ),
          ),
        ),
        if (withText) ...[
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: AppConstants.appName,
                  style: TextStyle(color: context.palette.textPrimary),
                ),
                // Punto lima: firma de la marca.
                const TextSpan(
                  text: '.',
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ],
    );
  }
}

/// Dibuja la marca de Vatio en el tamaño disponible.
///
/// - [bevel]: corte de las esquinas en píxeles (con [fullBleed] se ignora).
/// - [fullBleed]: fondo cuadrado completo y rayo más pequeño, para iconos
///   "maskable" que el sistema recorta con su propia forma.
/// - [shadow]: sombra suave bajo la loseta (en la app, no en los iconos).
class VatioMarkPainter extends CustomPainter {
  const VatioMarkPainter({
    this.bevel = 24,
    this.fullBleed = false,
    this.shadow = false,
  });

  final double bevel;
  final bool fullBleed;
  final bool shadow;

  /// Rayo en coordenadas de 0 a 1 dentro de la loseta.
  static const List<Offset> _bolt = [
    Offset(0.50, 0.14),
    Offset(0.29, 0.55),
    Offset(0.47, 0.55),
    Offset(0.40, 0.87),
    Offset(0.72, 0.43),
    Offset(0.54, 0.43),
    Offset(0.67, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tile = Path();
    if (fullBleed) {
      tile.addRect(Offset.zero & size);
    } else {
      final c = bevel.clamp(0.0, w / 3);
      tile
        ..moveTo(c, 0)
        ..lineTo(w - c, 0)
        ..lineTo(w, c)
        ..lineTo(w, h - c)
        ..lineTo(w - c, h)
        ..lineTo(c, h)
        ..lineTo(0, h - c)
        ..lineTo(0, c)
        ..close();
    }
    if (shadow) {
      canvas.drawShadow(
        tile,
        AppColors.primary.withValues(alpha: 0.6),
        w * 0.08,
        false,
      );
    }
    canvas.drawPath(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryGradientEnd],
        ).createShader(Offset.zero & size),
    );

    // En los iconos "maskable" el rayo va dentro de la zona segura (80 %).
    final scale = fullBleed ? 0.72 : 1.0;
    final inset = (1 - scale) / 2;
    final bolt = Path();
    for (var i = 0; i < _bolt.length; i++) {
      final p = Offset(
        (inset + _bolt[i].dx * scale) * w,
        (inset + _bolt[i].dy * scale) * h,
      );
      i == 0 ? bolt.moveTo(p.dx, p.dy) : bolt.lineTo(p.dx, p.dy);
    }
    bolt.close();
    canvas.drawPath(bolt, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(VatioMarkPainter oldDelegate) =>
      oldDelegate.bevel != bevel ||
      oldDelegate.fullBleed != fullBleed ||
      oldDelegate.shadow != shadow;
}
