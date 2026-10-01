import 'package:flutter/material.dart';

/// Puntos de corte de la aplicación.
class Breakpoints {
  Breakpoints._();

  /// A partir de este ancho se usa navegación lateral (escritorio/tablet).
  static const double rail = 840;

  /// Ancho máximo del contenido en pantallas de listas y paneles.
  static const double content = 980;

  /// Ancho máximo de formularios, para no estirarlos en escritorio.
  static const double form = 560;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= rail;
}

/// `SingleChildScrollView` para formularios: en escritorio centra el
/// contenido con un ancho máximo cómodo; en móvil se comporta igual.
class FormScrollView extends StatelessWidget {
  const FormScrollView({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = Breakpoints.form,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: MaxWidth(maxWidth: maxWidth, child: child),
    );
  }
}

/// Centra su contenido y limita su ancho. En móvil no cambia nada.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
