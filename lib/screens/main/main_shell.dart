import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/responsive.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Menú principal, en el mismo orden que las ramas del router:
/// /rutinas, /entrenamiento, /ejercicio, /progreso, /calendario y /profile.
const _destinations = [
  _Destination('Rutinas', Icons.list_alt_outlined, Icons.list_alt_rounded),
  _Destination('Entrenar', Icons.timer_outlined, Icons.timer_rounded),
  _Destination(
    'Ejercicios',
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
  ),
  _Destination('Progreso', Icons.insights_outlined, Icons.insights_rounded),
  _Destination(
    'Calendario',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  _Destination('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Estructura principal: barra inferior en móvil y navegación lateral en
/// pantallas anchas (escritorio y web).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) {
      final palette = context.palette;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        // Con 6 destinos, en teléfonos estrechos solo se rotula el elegido
        // para que las etiquetas no se corten (el resto tiene tooltip).
        labelBehavior: MediaQuery.sizeOf(context).width < 420
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
