import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/exercise_model.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart';
import 'app_feedback.dart';
import 'custom_button.dart';

/// Abre la hoja para elegir ejercicios y comenzar un entrenamiento libre.
/// Devuelve `true` si el entrenamiento comenzó.
Future<bool> showFreeWorkoutSheet(BuildContext context) async {
  final provider = context.read<WorkoutProvider>();
  if (provider.active) {
    showAppMessage(
      context,
      'Ya tienes un entrenamiento en curso. Finalízalo o descártalo antes.',
      type: FeedbackType.info,
    );
    return false;
  }
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _FreeWorkoutSheet(),
  );
  return started ?? false;
}

class _FreeWorkoutSheet extends StatefulWidget {
  const _FreeWorkoutSheet();

  @override
  State<_FreeWorkoutSheet> createState() => _FreeWorkoutSheetState();
}

class _FreeWorkoutSheetState extends State<_FreeWorkoutSheet> {
  List<ExerciseModel>? _exercises;
  String? _error;
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await context.read<WorkoutProvider>().loadExercises();
      if (!mounted) return;
      setState(() => _exercises = list);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ProgressProvider.describeError(error));
    }
  }

  void _start() {
    final exercises = _exercises ?? const <ExerciseModel>[];
    final chosen = [
      for (final id in _selected) ...exercises.where((e) => e.id == id),
    ];
    final started = context.read<WorkoutProvider>().startFreeWorkout(chosen);
    Navigator.of(context).pop(started);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final exercises = _exercises;

    Widget content;
    if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (exercises == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (exercises.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'Todavía no tienes ejercicios. Crea al menos uno para '
              'entrenar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(false);
                context.push('/ejercicio/crear');
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear ejercicio'),
            ),
          ],
        ),
      );
    } else {
      content = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final exercise in exercises)
            FilterChip(
              label: Text(exercise.name),
              selected: _selected.contains(exercise.id),
              showCheckmark: true,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: _selected.contains(exercise.id)
                    ? AppColors.onPrimary
                    : palette.textPrimary,
              ),
              onSelected: (value) => setState(() {
                if (value) {
                  _selected.add(exercise.id);
                } else {
                  _selected.remove(exercise.id);
                }
              }),
            ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrenamiento libre',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige los ejercicios que harás hoy, sin crear una rutina.',
              style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 18),
            content,
            const SizedBox(height: 22),
            CustomButton(
              label: _selected.isEmpty
                  ? 'Selecciona ejercicios'
                  : 'Comenzar con ${_selected.length} '
                        '${_selected.length == 1 ? 'ejercicio' : 'ejercicios'}',
              icon: Icons.play_arrow_rounded,
              onPressed: _selected.isEmpty ? null : _start,
            ),
          ],
        ),
      ),
    );
  }
}
