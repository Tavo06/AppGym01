import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/responsive.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Pestañas visibles, en el mismo orden que las 5 primeras ramas del
/// router: /hoy, /rutinas, /alimentacion, /progreso y /profile.
const _destinations = [
  _Destination('Hoy', Icons.bolt_outlined, Icons.bolt_rounded),
  _Destination(
    'Entrenar',
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
  ),
  _Destination('Comida', Icons.restaurant_outlined, Icons.restaurant_rounded),
  _Destination('Progreso', Icons.insights_outlined, Icons.insights_rounded),
  _Destination('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Índices de las ramas del router.
abstract final class ShellBranch {
  static const int hoy = 0;
  static const int entrenar = 1;
  static const int perfil = 4;
  static const int entrenamiento = 5;
  static const int ejercicios = 6;
  static const int calendario = 7;
}

/// Estructura principal: barra inferior flotante en móvil y navegación
/// lateral en pantallas anchas (escritorio y web).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Pestaña que se marca para cada rama: las ramas sin pestaña propia
  /// marcan la de la que dependen (entrenamiento y ejercicios → Entrenar,
  /// calendario → Hoy).
  @visibleForTesting
  static int parentTab(int branch) => switch (branch) {
    ShellBranch.entrenamiento || ShellBranch.ejercicios => ShellBranch.entrenar,
    ShellBranch.calendario => ShellBranch.hoy,
    _ => branch,
  };

  void _select(BuildContext context, int tab) {
    final current = navigationShell.currentIndex;
    // "Entrenar" con un entrenamiento en curso lleva directamente a él
    // (salvo que ya se esté en él: entonces vuelve a las rutinas).
    if (tab == ShellBranch.entrenar &&
        current != ShellBranch.entrenamiento &&
        context.read<WorkoutProvider>().active) {
      navigationShell.goBranch(ShellBranch.entrenamiento);
      return;
    }
    navigationShell.goBranch(tab, initialLocation: tab == current);
  }

  @override
  Widget build(BuildContext context) {
    // Modo foco: con el entrenamiento en curso en pantalla, sin barra de
    // navegación (se sale con el botón "volver" de la pantalla).
    final focus =
        navigationShell.currentIndex == ShellBranch.entrenamiento &&
        context.watch<WorkoutProvider>().active;
    if (focus) return Scaffold(body: navigationShell);

    final selected = parentTab(navigationShell.currentIndex);
    if (Breakpoints.isWide(context)) {
      final palette = context.palette;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (tab) => _select(context, tab),
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.85,
              leading: const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 12),
                child: AppLogo(size: 48, radius: 14, withText: false),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: palette.border),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(28));
    return Scaffold(
      body: navigationShell,
      // Barra flotante: separada de los bordes, redondeada y con sombra
      // suave (en oscuro, un borde tenue en lugar de sombra).
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: radius,
            border: dark ? Border.all(color: palette.border) : null,
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          // Margen interior: la esquina redondeada no debe recortar el
          // indicador del primer y el último destino.
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                selectedIndex: selected,
                onDestinationSelected: (tab) => _select(context, tab),
                // Con 5 pestañas caben todas las etiquetas.
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
