import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'responsive.dart';

/// Secciones de la pestaña "Entrenar".
enum TrainSection { rutinas, ejercicios }

/// Selector "Rutinas | Ejercicios" en lo alto de la pestaña Entrenar: hace
/// visibles los ejercicios, que no tienen pestaña propia en la barra.
class TrainSectionTabs extends StatelessWidget {
  const TrainSectionTabs({super.key, required this.current});

  final TrainSection current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: MaxWidth(
        maxWidth: Breakpoints.form,
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<TrainSection>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TrainSection.rutinas,
                icon: Icon(Icons.list_alt_rounded),
                label: Text('Rutinas'),
              ),
              ButtonSegment(
                value: TrainSection.ejercicios,
                icon: Icon(Icons.fitness_center_rounded),
                label: Text('Ejercicios'),
              ),
            ],
            selected: {current},
            onSelectionChanged: (selection) {
              final section = selection.first;
              if (section == current) return;
              context.go(
                section == TrainSection.rutinas ? '/rutinas' : '/ejercicio',
              );
            },
          ),
        ),
      ),
    );
  }
}
