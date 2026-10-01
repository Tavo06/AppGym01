import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_day_model.dart';
import '../../models/routine_model.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/free_workout_sheet.dart';
import '../../widgets/responsive.dart';

/// Pantalla de entrenamiento (`/entrenamiento`).
///
/// Estado local (setState): serie actual, repeticiones y peso en curso,
/// ejercicio seleccionado, cronómetro y descanso.
/// Estado global (WorkoutProvider): las series ya registradas de la sesión,
/// que se guardan al finalizar.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.routine});

  /// Rutina enviada desde Rutinas. Al recibirla comienza el entrenamiento.
  final WorkoutRoutine? routine;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  String? _selectedExerciseId;
  int _restSeconds = AppConstants.defaultRestSeconds;

  /// Número de la serie que se está realizando en el ejercicio elegido.
  int _currentSet = 1;

  /// Repeticiones de la serie en curso.
  int _reps = 0;

  Timer? _timer;
  Timer? _restTimer;
  bool _timerActive = false;
  int _restRemaining = 0;
  bool _restPaused = false;

  /// Última rutina recibida, para no iniciarla dos veces.
  WorkoutRoutine? _receivedRoutine;

  /// Inicio del entrenamiento que refleja el estado local.
  DateTime? _seenStartedAt;

  @override
  void initState() {
    super.initState();
    _selectedExerciseId = null;
    _receiveRoutine();
  }

  @override
  void didUpdateWidget(covariant WorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _receiveRoutine();
  }

  /// Comienza el entrenamiento con la rutina recibida por navegación.
  void _receiveRoutine() {
    final routine = widget.routine;
    if (routine == null || identical(routine, _receivedRoutine)) return;
    _receivedRoutine = routine;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final started = context.read<WorkoutProvider>().startWorkout(
        routine: routine,
        allExercises: routine.exerciseDetails,
      );
      _resetLocalState();
      if (!started) {
        _showMessage(
          'Los ejercicios de esta rutina ya no existen. Edítala para '
          'seleccionar otros.',
        );
      }
      // Se limpia `extra` de la ruta: al volver a esta pestaña no debe
      // reiniciarse el entrenamiento.
      context.go('/entrenamiento');
    });
  }

  /// Limpia el estado local de la sesión (incluido el descanso, que antes
  /// quedaba congelado al finalizar durante un descanso).
  void _resetLocalState() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() {
      _selectedExerciseId = null;
      _currentSet = 1;
      _reps = 0;
      _restRemaining = 0;
      _restPaused = false;
      _weightController.clear();
      _repsController.clear();
    });
  }

  /// La serie actual del ejercicio elegido es la siguiente a las ya
  /// registradas.
  void _syncCurrentSet(String exerciseId) {
    _currentSet = context.read<WorkoutProvider>().seriesFor(exerciseId) + 1;
  }

  void _selectExercise(String exerciseId) {
    final provider = context.read<WorkoutProvider>();
    final sets = provider.setsFor(exerciseId);
    final plan = provider.plannedFor(exerciseId);
    setState(() {
      _selectedExerciseId = exerciseId;
      _syncCurrentSet(exerciseId);
      // Peso y repeticiones de partida: los de la última serie registrada
      // o, si aún no hay, los del plan de la rutina.
      double? weight;
      int? reps;
      if (sets.isNotEmpty) {
        weight = sets.last.weight;
        reps = sets.last.repetitions;
      } else if (plan != null) {
        weight = plan.weight;
        reps = plan.reps;
      }
      if (weight != null) {
        _weightController.text = weight <= 0
            ? ''
            : (weight == weight.roundToDouble()
                  ? '${weight.toInt()}'
                  : '$weight');
      }
      if (reps != null) {
        _reps = reps;
        _repsController.text = '$reps';
      }
      if (plan != null) _restSeconds = plan.restSeconds;
    });
  }

  /// Siguiente ejercicio pendiente después de [current] (o el primero
  /// pendiente si los siguientes ya están completos).
  ExerciseModel? _nextPending(WorkoutProvider provider, String current) {
    final exercises = provider.exercises;
    final index = exercises.indexWhere((e) => e.id == current);
    for (var offset = 1; offset < exercises.length; offset++) {
      final candidate = exercises[(index + offset) % exercises.length];
      if (!provider.isExerciseDone(candidate.id)) return candidate;
    }
    return null;
  }

  void _changeReps(int delta) {
    setState(() {
      _reps = (_reps + delta).clamp(0, 999);
      _repsController.text = _reps == 0 ? '' : '$_reps';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El cronómetro se sincroniza con el entrenamiento real: antes arrancaba
    // en `initState` y nunca se reiniciaba, de modo que al volver a la
    // pestaña mostraba el tiempo acumulado desde que se abrió la app.
    final provider = context.watch<WorkoutProvider>();
    final active = provider.active;
    if (active && provider.startedAt != _seenStartedAt) {
      // Empezó otro entrenamiento (desde aquí, Rutinas o el Panel): la serie
      // en curso vuelve a calcularse para el primer ejercicio.
      _seenStartedAt = provider.startedAt;
      _selectedExerciseId = null;
      _currentSet = 1;
    }
    if (active && !_timerActive) {
      _startElapsedTimer();
    } else if (!active && _timerActive) {
      _stopElapsedTimer();
      _restTimer?.cancel();
      _restRemaining = 0;
      _restPaused = false;
    }
  }

  void _startElapsedTimer() {
    _timer?.cancel();
    _timerActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  void _stopElapsedTimer() {
    _timer?.cancel();
    _timer = null;
    _timerActive = false;
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = seconds;
      _restPaused = false;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restPaused) return;
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          _restRemaining = 0;
          timer.cancel();
        }
      });
      if (_restRemaining == 0) {
        _showMessage('¡Descanso completado!', AppColors.success);
      }
    });
  }

  void _pauseRest() {
    setState(() => _restPaused = !_restPaused);
  }

  void _finishRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  double get _weight =>
      double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ?? 0;

  void _addSet() {
    final weight = _weight;
    final reps = _reps;
    final exerciseId = _selectedExerciseId;
    if (exerciseId == null) return;
    // El peso 0 es válido: permite registrar ejercicios con peso corporal
    // (dominadas, flexiones, cardio) que antes eran imposibles de guardar.
    if (weight < 0) {
      _showMessage('El peso no puede ser negativo.');
      return;
    }
    if (reps <= 0) {
      _showMessage('Ingresa el número de repeticiones.');
      return;
    }

    final provider = context.read<WorkoutProvider>();

    provider.addSet(
      exerciseId,
      weight: weight,
      repetitions: reps,
      restSeconds: _restSeconds,
    );

    // Se pasa a la siguiente serie; peso y repeticiones se conservan porque
    // lo habitual es repetirlos.
    setState(() => _currentSet++);
    _showMessage('Serie registrada.', AppColors.success);
    if (_restSeconds > 0) {
      _startRest(_restSeconds);
    }
  }

  Future<void> _finishWorkout() async {
    final provider = context.read<WorkoutProvider>();
    if (provider.totalCompletedSets == 0) {
      _showMessage('Registra al menos una serie para finalizar.');
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.flag_rounded,
      title: '¿Finalizar entrenamiento?',
      message:
          'Se guardarán ${provider.totalCompletedSets} series '
          'registradas en tu historial.',
      confirmLabel: 'Finalizar',
    );
    if (confirmed != true || !mounted) return;

    // El cronómetro se detiene recién al confirmar: si el guardado falla el
    // usuario debe poder seguir entrenando con el reloj en marcha.
    _stopElapsedTimer();
    final progress = context.read<ProgressProvider>();

    WorkoutSaveResult? result;
    try {
      result = await provider.finishWorkout();
    } catch (error) {
      if (!mounted) return;
      _startElapsedTimer();
      _showMessage('No se pudo guardar el entrenamiento. Revisa tu conexión.');
      return;
    }
    if (!mounted) return;
    if (result == null) {
      _startElapsedTimer();
      _showMessage('No se pudo guardar el entrenamiento.');
      return;
    }

    // Estado global: la sesión guardada actualiza historial, progreso
    // semanal, récords y estadísticas (notifyListeners → Consumer).
    final session = result.session ?? provider.lastSession;
    if (session != null) {
      progress.agregarSesion(session, newRecords: result.newRecords);
    }

    // Los récords nuevos se muestran en la pantalla de resumen, no aquí,
    // para no mostrarlos dos veces consecutivas.
    provider.clearActiveWorkout();
    _resetLocalState();
    // El resumen recibe el resultado y, al cerrarse, devuelve la sesión a
    // Rutinas.
    await context.push('/entrenamiento/resumen', extra: result);
  }

  void _showMessage(String message, [Color color = AppColors.error]) {
    if (!mounted) return;
    showAppMessage(
      context,
      message,
      type: color == AppColors.success
          ? FeedbackType.success
          : FeedbackType.error,
    );
  }

  /// Tiempo transcurrido desde el inicio real del entrenamiento (el mismo
  /// dato con el que se calcula la duración guardada), aunque la pestaña se
  /// haya abierto después.
  String _elapsedLabel(WorkoutProvider provider) {
    final startedAt = provider.startedAt;
    if (!provider.active || startedAt == null) {
      return Formatters.formatDuration(Duration.zero);
    }
    return Formatters.formatDuration(DateTime.now().difference(startedAt));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.active ? provider.routineName : 'Entrenar'),
        automaticallyImplyLeading: false,
        actions: [
          if (provider.active)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _elapsedLabel(provider),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: !provider.active
          ? _buildNoWorkout()
          : MaxWidth(child: _buildActiveWorkout(provider)),
    );
  }

  Widget _buildNoWorkout() {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No hay entrenamiento activo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comienza desde una de tus rutinas o elige ejercicios '
                'sueltos para un entrenamiento libre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Elegir una rutina',
                icon: Icons.list_alt_rounded,
                onPressed: () => context.go('/rutinas'),
              ),
              const SizedBox(height: 10),
              CustomButton(
                label: 'Entrenamiento libre',
                icon: Icons.bolt_rounded,
                variant: ButtonVariant.outline,
                onPressed: () => showFreeWorkoutSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWorkout(WorkoutProvider provider) {
    final exercises = provider.exercises;
    final safeSelected = exercises.any((e) => e.id == _selectedExerciseId)
        ? _selectedExerciseId
        : (exercises.isNotEmpty ? exercises.first.id : null);

    if (safeSelected != _selectedExerciseId && safeSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectExercise(safeSelected);
      });
    }

    return Column(
      children: [
        _buildStatsStrip(provider),
        Container(
          height: 52,
          color: context.palette.surfaceMuted,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: exercises.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final selected = exercise.id == safeSelected;
              final done = provider.isExerciseDone(exercise.id);
              return ChoiceChip(
                label: Text(exercise.name),
                selected: selected,
                showCheckmark: false,
                // Los ejercicios completos (según su plan) llevan un check.
                avatar: done
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: selected ? Colors.white : AppColors.success,
                      )
                    : null,
                onSelected: (_) => _selectExercise(exercise.id),
                backgroundColor: context.palette.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.palette.textPrimary,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (safeSelected != null) ...[
                _buildExerciseHeader(
                  exercises.firstWhere((e) => e.id == safeSelected),
                  provider,
                ),
                const SizedBox(height: 14),
                _buildSetsList(safeSelected, provider),
                const SizedBox(height: 20),
                _buildAddSetForm(safeSelected),
                if (provider.isExerciseDone(safeSelected) &&
                    _nextPending(provider, safeSelected) != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _selectExercise(
                      _nextPending(provider, safeSelected)!.id,
                    ),
                    icon: const Icon(Icons.skip_next_rounded),
                    label: Text(
                      'Siguiente: ${_nextPending(provider, safeSelected)!.name}',
                    ),
                  ),
                ],
              ],
              if (_restRemaining > 0) ...[
                const SizedBox(height: 20),
                _buildRestTimer(),
              ],
              const SizedBox(height: 20),
              CustomButton(
                label: 'Finalizar entrenamiento',
                icon: Icons.flag_circle_outlined,
                variant: ButtonVariant.secondary,
                loading: provider.saving,
                onPressed: _finishWorkout,
              ),
              const SizedBox(height: 10),
              CustomButton(
                label: 'Descartar entrenamiento',
                icon: Icons.delete_sweep_outlined,
                variant: ButtonVariant.text,
                onPressed: _discardWorkout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(WorkoutProvider provider) {
    return Container(
      color: context.palette.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(label: 'SERIES', value: '${provider.totalCompletedSets}'),
          _Stat(
            label: 'VOLUMEN',
            value: '${Formatters.formatNumber(provider.totalVolume)} kg',
          ),
          // Ejercicios completos según el plan / total de la sesión.
          _Stat(
            label: 'EJERCICIOS',
            value:
                '${provider.completedExercises}/${provider.exercises.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader(
    ExerciseModel exercise,
    WorkoutProvider provider,
  ) {
    final plan = provider.plannedFor(exercise.id);
    final position = provider.exercises.indexWhere((e) => e.id == exercise.id);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'EJERCICIO ${position + 1} DE ${provider.exercises.length}',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildExerciseTitle(exercise, plan),
        if (plan != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Objetivo: ${plan.sets} × ${plan.reps}'
                        '${plan.weight > 0 ? ' · ${Formatters.formatWeight(plan.weight)} kg' : ''}'
                        ' · descanso ${plan.restSeconds} s',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (plan.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.notes,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExerciseTitle(ExerciseModel exercise, RoutineExercise? plan) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.palette.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: context.palette.textPrimary,
                ),
              ),
              Text(
                exercise.muscleGroup,
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'SERIE ACTUAL',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                color: context.palette.textSecondary,
              ),
            ),
            Text(
              plan == null ? '$_currentSet' : '$_currentSet / ${plan.sets}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetsList(String exerciseId, WorkoutProvider provider) {
    final sets = provider.setsFor(exerciseId);
    if (sets.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Aún no hay series registradas para este ejercicio.',
          style: TextStyle(
            fontSize: 13.5,
            color: context.palette.textSecondary,
          ),
        ),
      );
    }
    return Column(
      children: [
        ...sets.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SetRow(
              setNumber: entry.value.setNumber,
              weight: entry.value.weight,
              repetitions: entry.value.repetitions,
              completed: entry.value.completed,
              onDelete: () => _confirmRemoveSet(exerciseId, entry.key),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveSet(String exerciseId, int index) async {
    final provider = context.read<WorkoutProvider>();
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar serie?',
      message: 'La serie se quitará de este entrenamiento.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true) return;
    provider.removeSet(exerciseId, index);
    if (exerciseId == _selectedExerciseId) {
      setState(() => _syncCurrentSet(exerciseId));
    }
  }

  Future<void> _discardWorkout() async {
    final provider = context.read<WorkoutProvider>();
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.warning_amber_rounded,
      title: '¿Descartar entrenamiento?',
      message:
          'Se perderán las ${provider.totalCompletedSets} series '
          'registradas en esta sesión. No se guardará nada.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    if (confirmed != true) return;
    provider.clearActiveWorkout();
    _resetLocalState();
    _showMessage('Entrenamiento descartado.');
  }

  Widget _buildAddSetForm(String exerciseId) {
    final palette = context.palette;
    // Vista previa de la serie en curso: volumen = peso × repeticiones.
    final weight = _weight;
    final preview = _reps > 0
        ? '${Formatters.formatWeight(weight)} kg × $_reps = '
              '${Formatters.formatVolume(weight * _reps)}'
        : 'Indica las repeticiones de la serie.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Serie $_currentSet en curso',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Una repetición menos',
                  onPressed: _reps > 0 ? () => _changeReps(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (value) =>
                        setState(() => _reps = int.tryParse(value.trim()) ?? 0),
                    decoration: const InputDecoration(
                      labelText: 'Repeticiones',
                      prefixIcon: Icon(Icons.repeat_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Una repetición más',
                  onPressed: () => _changeReps(1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preview,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'Descanso',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                // Opciones fijas más el descanso del plan, si es distinto.
                for (final preset in ({
                  ...AppConstants.restPresets,
                  if (_restSeconds > 0) _restSeconds,
                }.toList()..sort()))
                  ChoiceChip(
                    label: Text(
                      preset >= 60
                          ? '${Formatters.padClock(preset ~/ 60)}:'
                                '${Formatters.padClock(preset % 60)}'
                          : '${preset}s',
                    ),
                    selected: _restSeconds == preset,
                    onSelected: (_) => setState(() => _restSeconds = preset),
                    backgroundColor: context.palette.surface,
                    selectedColor: context.palette.primarySoft,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _restSeconds == preset
                          ? AppColors.primary
                          : context.palette.textPrimary,
                    ),
                    side: BorderSide(
                      color: _restSeconds == preset
                          ? AppColors.primary
                          : context.palette.surfaceMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              label: 'Agregar serie',
              icon: Icons.add_circle_outline_rounded,
              expanded: false,
              onPressed: _addSet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestTimer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Descanso',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${Formatters.padClock(_restRemaining ~/ 60)}:'
              '${Formatters.padClock(_restRemaining % 60)}',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: _restRemaining <= 10
                    ? AppColors.error
                    : context.palette.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            // `Wrap` para que los botones bajen de línea en pantallas estrechas.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _pauseRest,
                  icon: Icon(
                    _restPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: Text(_restPaused ? 'Reanudar' : 'Pausar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _finishRest,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Finalizar'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.weight,
    required this.repetitions,
    required this.completed,
    this.onDelete,
  });

  final int setNumber;
  final double weight;
  final int repetitions;
  final bool completed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.primary
                  : context.palette.textSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$setNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${Formatters.formatWeight(weight)} kg',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.close_rounded,
            size: 16,
            color: context.palette.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$repetitions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const Spacer(),
          if (onDelete != null)
            IconButton(
              tooltip: 'Eliminar serie',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 10.5,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
