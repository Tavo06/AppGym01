import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/exercise_model.dart';
import '../models/routine_model.dart';
import '../models/scheduled_workout_model.dart';
import '../providers/progress_provider.dart';
import '../providers/workout_provider.dart';
import '../services/firestore_service.dart';
import 'app_feedback.dart';
import 'confirmation_dialog.dart';

/// Entrena un día programado (desde el Calendario o el Panel): lee la
/// rutina y sus ejercicios y la lleva como objeto a `/entrenamiento`, igual
/// que desde Rutinas. Si ya hay un entrenamiento en curso, pregunta antes
/// de descartarlo.
Future<void> startScheduledWorkout(
  BuildContext context,
  ScheduledWorkout item,
) async {
  final workout = context.read<WorkoutProvider>();
  final uid = workout.userId;
  if (uid == null) return;
  final firestore = FirestoreService();
  try {
    final results = await Future.wait([
      firestore.getRoutines(uid),
      firestore.getExercises(uid),
    ]);
    if (!context.mounted) return;
    final routines = (results[0] as List).cast<WorkoutRoutine>();
    final exercises = (results[1] as List).cast<ExerciseModel>();
    WorkoutRoutine? routine;
    for (final r in routines) {
      if (r.id == item.routineId) routine = r.withExercises(exercises);
    }
    if (routine == null) {
      showAppMessage(context, 'Esa rutina ya no existe.');
      return;
    }
    final day =
        routine.dayById(item.dayId) ??
        (routine.days.isNotEmpty ? routine.days.first : null);
    final toStart = day == null ? routine : routine.forDay(day);
    if (toStart.exerciseDetails.isEmpty) {
      showAppMessage(
        context,
        'Los ejercicios de esa rutina ya no existen. Edítala para '
        'seleccionar otros.',
      );
      return;
    }
    if (workout.active) {
      final replace = await ConfirmationDialog.show(
        context,
        icon: Icons.warning_amber_rounded,
        title: 'Ya tienes un entrenamiento en curso',
        message:
            'Si comienzas "${toStart.name}", el entrenamiento actual se '
            'descartará.',
        confirmLabel: 'Descartar y comenzar',
        cancelLabel: 'Seguir con el actual',
        destructive: true,
      );
      if (!context.mounted) return;
      if (replace != true) {
        context.go('/entrenamiento');
        return;
      }
    }
    context.go('/entrenamiento', extra: toStart);
  } catch (error) {
    if (!context.mounted) return;
    showAppMessage(context, ProgressProvider.describeError(error));
  }
}
