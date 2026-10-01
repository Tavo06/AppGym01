import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/exercise_model.dart';
import '../providers/progress_provider.dart';

/// Historial de un ejercicio: sesiones en las que se hizo, con sus series
/// (peso × repeticiones) y volumen. Los datos vienen de [ProgressProvider].
Future<void> showExerciseHistorySheet(
  BuildContext context,
  ExerciseModel exercise,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExerciseHistory(exercise: exercise),
  );
}

class _ExerciseHistory extends StatelessWidget {
  const _ExerciseHistory({required this.exercise});

  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Consumer<ProgressProvider>(
          builder: (context, progress, _) {
            final entries = [
              for (final session in progress.workouts)
                for (final record in session.exercises)
                  if (record.exerciseId == exercise.id)
                    (session: session, record: record),
            ];
            final weekly = progress.weeklyBestWeight(exercise.id, limit: 4);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  [
                    exercise.muscleGroup,
                    if (exercise.equipment.isNotEmpty) exercise.equipment,
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                if (weekly.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in weekly)
                        Chip(
                          label: Text(
                            'Sem. ${w.weekStart.day}/${w.weekStart.month}: '
                            '${Formatters.formatWeight(w.bestWeight)} kg',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Todavía no registraste este ejercicio en un '
                      'entrenamiento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ),
                for (final entry in entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  Formatters.formatRelativeDay(
                                    entry.session.finishedAt ??
                                        entry.session.startedAt,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                Formatters.formatVolume(entry.record.volume),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            entry.session.routineName,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final set in entry.record.sets)
                                if (set.completed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${Formatters.formatWeight(set.weight)} '
                                      'kg × ${set.repetitions}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
