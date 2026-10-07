import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Botón "volver" de las pantallas que no tienen pestaña propia
/// (entrenamiento, ejercicios y calendario): se llega a ellas con `go`, así
/// que no hay pila que deshacer y se vuelve a su pestaña de origen.
class TabBackButton extends StatelessWidget {
  const TabBackButton({super.key, required this.to, this.tooltip = 'Volver'});

  /// Ruta de la pestaña a la que se vuelve.
  final String to;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.go(to),
    );
  }
}
