import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_day_model.dart';
import '../../models/routine_model.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/responsive.dart';

/// Detalle de una rutina (`/rutinas/detalle`): sus días con el plan de cada
/// ejercicio y un botón para entrenar cada día.
///
/// Devuelve con `pop` el [RoutineDay] elegido para entrenar, o `'edit'`
/// si se pidió editarla; quien la abrió decide qué hacer.
class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({super.key, required this.routine});

  /// Rutina relacionada con sus ejercicios (`withExercises`).
  final WorkoutRoutine? routine;

  @override
  Widget build(BuildContext context) {
    final routine = this.routine;
    if (routine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rutina')),
        body: const Center(child: Text('No se encontró la rutina.')),
      );
    }
    final palette = context.palette;
    final byId = {for (final e in routine.exerciseDetails) e.id: e};

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            tooltip: 'Editar rutina',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.pop('edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (routine.description.isNotEmpty) ...[
                  Text(
                    routine.description,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (routine.goal.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.flag_outlined, size: 16),
                        label: Text(routine.goal),
                      ),
                    for (final group in routine.muscleGroups)
                      Chip(
                        avatar: const Icon(
                          Icons.accessibility_new_rounded,
                          size: 16,
                        ),
                        label: Text(group),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                StatGrid(
                  minTileWidth: 140,
                  children: [
                    ProgressCard(
                      icon: Icons.calendar_view_week_rounded,
                      label: 'Días',
                      value: '${routine.days.length}',
                    ),
                    ProgressCard(
                      icon: Icons.fitness_center_rounded,
                      label: 'Ejercicios',
                      value: '${routine.exercises.length}',
                      color: AppColors.violet,
                    ),
                    ProgressCard(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Series',
                      value: '${routine.totalSets}',
                      color: AppColors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - 16 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var i = 0; i < routine.days.length; i++)
                          SizedBox(
                            width: width,
                            child: _DayCard(
                              number: i + 1,
                              day: routine.days[i],
                              exercises: byId,
                              onTrain: () => context.pop(routine.days[i]),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.number,
    required this.day,
    required this.exercises,
    required this.onTrain,
  });

  final int number;
  final RoutineDay day;
  final Map<String, ExerciseModel> exercises;
  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final available = day.exercises
        .where((e) => exercises.containsKey(e.exerciseId))
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${available.length} ejercicios · '
                        '${day.totalSets} series',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final plan in available)
              _PlanRow(plan: plan, exercise: exercises[plan.exerciseId]!),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: available.isEmpty ? null : onTrain,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Entrenar ${day.name}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.exercise});

  final RoutineExercise plan;
  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = [
      '${plan.sets} × ${plan.reps}',
      if (plan.weight > 0) '${Formatters.formatWeight(plan.weight)} kg',
      'descanso ${plan.restSeconds} s',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.textSecondary,
                  ),
                ),
                if (plan.notes.isNotEmpty)
                  Text(
                    plan.notes,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir qué día de la rutina entrenar.
Future<RoutineDay?> showRoutineDayPicker(
  BuildContext context,
  WorkoutRoutine routine,
) {
  return showModalBottomSheet<RoutineDay>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Qué día vas a entrenar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                routine.name,
                style: TextStyle(fontSize: 13, color: palette.textSecondary),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < routine.days.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: palette.primarySoft,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(routine.days[i].name),
                    subtitle: Text(
                      '${routine.days[i].exercises.length} ejercicios · '
                      '${routine.days[i].totalSets} series',
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(routine.days[i]),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
