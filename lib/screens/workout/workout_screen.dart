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
import '../../widgets/tab_back_button.dart';
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

  /// Duración total del descanso en curso (para el anillo del temporizador).
  int _restTotal = 0;
  bool _restPaused = false;

  /// Modo foco: una página por ejercicio, se cambia deslizando.
  final PageController _pageController = PageController();

  /// Paleta del modo foco (siempre oscura). Se fija en `build`, dentro del
  /// tema oscuro, porque el `context` del State está fuera de ese tema.
  AppPalette _p = AppPalette.dark;

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
    _showPageOf(exerciseId);
  }

  /// Lleva el carrusel a la página de [exerciseId] (al elegirlo desde la
  /// barra de progreso, las flechas o "Siguiente").
  void _showPageOf(String exerciseId) {
    final index = context.read<WorkoutProvider>().exercises.indexWhere(
      (e) => e.id == exerciseId,
    );
    if (index < 0 || !_pageController.hasClients) return;
    final current = _pageController.page?.round();
    if (current == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Ajusta el peso de la serie en curso (botones ±2,5 kg).
  void _changeWeight(double delta) {
    final value = (_weight + delta).clamp(0.0, 999.0);
    setState(() {
      _weightController.text = value == value.roundToDouble()
          ? '${value.toInt()}'
          : value.toStringAsFixed(1);
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
      _restTotal = seconds;
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

  /// Alarga el descanso en curso.
  void _extendRest(int seconds) {
    setState(() {
      _restRemaining += seconds;
      _restTotal += seconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _pageController.dispose();
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
    // Sin aviso "Serie registrada.": en el modo foco ya lo indican el
    // contador de serie y el descanso, y el aviso tapaba "Finalizar".
    setState(() => _currentSet++);
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

  /// Tema del modo foco: siempre oscuro, aunque la app esté en modo claro.
  static final ThemeData _focusTheme = AppTheme.dark;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Theme(
      data: _focusTheme,
      child: Builder(
        builder: (context) {
          // Los métodos auxiliares usan el `context` del State (fuera de
          // este tema): toman la paleta oscura de aquí.
          _p = context.palette;
          return Scaffold(
            backgroundColor: _p.background,
            appBar: AppBar(
              backgroundColor: _p.background,
              title: Text(
                provider.active ? provider.routineName : 'Entrenar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              automaticallyImplyLeading: false,
              leading: const TabBackButton(
                to: '/rutinas',
                tooltip: 'Ir a rutinas',
              ),
              actions: [
                if (provider.active) ...[
                  _ElapsedPill(label: _elapsedLabel(provider)),
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (_) => _discardWorkout(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'discard',
                        child: Text('Descartar entrenamiento'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
            body: !provider.active
                ? _buildNoWorkout()
                : MaxWidth(child: _buildActiveWorkout(provider)),
            bottomNavigationBar: provider.active
                ? SafeArea(
                    minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    // `heightFactor: 1`: la barra mide lo que el botón (con
                    // `MaxWidth` ocupaba toda la altura y dejaba el cuerpo
                    // sin espacio).
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.content,
                        ),
                        child: CustomButton(
                          label: 'Finalizar entrenamiento',
                          icon: Icons.flag_rounded,
                          variant: ButtonVariant.outline,
                          loading: provider.saving,
                          onPressed: _finishWorkout,
                        ),
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildNoWorkout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const ShapeDecoration(
                  shape: AppShapes.button,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryGradientEnd],
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 52,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No hay entrenamiento activo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: _p.textPrimary,
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
                  color: _p.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
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
        _buildProgressBar(provider, safeSelected),
        _buildStatsRow(provider),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: exercises.length,
            // Deslizar cambia de ejercicio (y precarga su peso y reps).
            onPageChanged: (index) {
              final id = exercises[index].id;
              if (id != _selectedExerciseId) _selectExercise(id);
            },
            itemBuilder: (context, index) =>
                _buildExercisePage(provider, exercises[index], index),
          ),
        ),
      ],
    );
  }

  /// Un segmento por ejercicio: lima si está completo, índigo el actual.
  /// Tocar un segmento lleva a ese ejercicio.
  Widget _buildProgressBar(WorkoutProvider provider, String? selected) {
    final exercises = provider.exercises;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          for (final exercise in exercises)
            Expanded(
              child: Tooltip(
                message: exercise.name,
                child: InkWell(
                  onTap: () => _selectExercise(exercise.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 10,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: exercise.id == selected ? 8 : 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: provider.isExerciseDone(exercise.id)
                            ? AppColors.accent
                            : exercise.id == selected
                            ? AppColors.primary
                            : _p.surfaceMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(WorkoutProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
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

  /// Página de un ejercicio: cabecera, contador grande, descanso, mandos de
  /// peso y repeticiones, registrar la serie y series hechas.
  Widget _buildExercisePage(
    WorkoutProvider provider,
    ExerciseModel exercise,
    int index,
  ) {
    final count = provider.exercises.length;
    final plan = provider.plannedFor(exercise.id);
    // Solo la página del ejercicio elegido tiene la serie en curso.
    final isCurrent = exercise.id == _selectedExerciseId;
    final next = isCurrent && provider.isExerciseDone(exercise.id)
        ? _nextPending(provider, exercise.id)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'EJERCICIO ${index + 1} DE $count',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: _p.textSecondary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ejercicio anterior',
              visualDensity: VisualDensity.compact,
              onPressed: index > 0
                  ? () => _selectExercise(provider.exercises[index - 1].id)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Ejercicio siguiente',
              visualDensity: VisualDensity.compact,
              onPressed: index < count - 1
                  ? () => _selectExercise(provider.exercises[index + 1].id)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Text(
          exercise.name.toUpperCase(),
          style: TextStyle(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: _p.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          exercise.muscleGroup,
          style: TextStyle(fontSize: 14, color: _p.textSecondary),
        ),
        if (plan != null) ...[
          const SizedBox(height: 12),
          _PlanTarget(plan: plan, palette: _p),
        ],
        if (isCurrent) ...[
          const SizedBox(height: 20),
          _buildCounter(plan),
          if (_restRemaining > 0) ...[
            const SizedBox(height: 18),
            _buildRestPanel(),
          ],
          const SizedBox(height: 18),
          _buildSetControls(),
        ],
        const SizedBox(height: 22),
        _buildSetsList(exercise.id, provider),
        if (next != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _selectExercise(next.id),
            icon: const Icon(Icons.skip_next_rounded),
            label: Text('Siguiente: ${next.name}'),
          ),
        ],
      ],
    );
  }

  /// "SERIE" con el número enorme: "2 / 4" (o "2" sin plan).
  Widget _buildCounter(RoutineExercise? plan) {
    return Column(
      children: [
        Text(
          'SERIE',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: _p.textSecondary,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            plan == null ? '$_currentSet' : '$_currentSet / ${plan.sets}',
            style: TextStyle(
              fontSize: 72,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: _p.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          'Serie $_currentSet en curso',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _p.primaryText,
          ),
        ),
      ],
    );
  }

  /// Mandos grandes de peso y repeticiones, descanso y "Agregar serie".
  Widget _buildSetControls() {
    final weight = _weight;
    final preview = _reps > 0
        ? '${Formatters.formatWeight(weight)} kg × $_reps = '
              '${Formatters.formatVolume(weight * _reps)}'
        : 'Indica las repeticiones de la serie.';
    final presets = {
      ...AppConstants.restPresets,
      if (_restSeconds > 0) _restSeconds,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stepper(
                palette: _p,
                label: 'Peso (kg)',
                controller: _weightController,
                decimal: true,
                lessTooltip: 'Menos peso',
                moreTooltip: 'Más peso',
                onLess: _weight > 0 ? () => _changeWeight(-2.5) : null,
                onMore: () => _changeWeight(2.5),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stepper(
                palette: _p,
                label: 'Repeticiones',
                controller: _repsController,
                lessTooltip: 'Una repetición menos',
                moreTooltip: 'Una repetición más',
                onLess: _reps > 0 ? () => _changeReps(-1) : null,
                onMore: () => _changeReps(1),
                onChanged: (value) =>
                    setState(() => _reps = int.tryParse(value.trim()) ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          preview,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: _p.textSecondary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: _p.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Descanso',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _p.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Opciones fijas más el descanso del plan, si es distinto.
                  for (final preset in presets)
                    ChoiceChip(
                      label: Text(
                        preset >= 60
                            ? '${Formatters.padClock(preset ~/ 60)}:'
                                  '${Formatters.padClock(preset % 60)}'
                            : '${preset}s',
                      ),
                      selected: _restSeconds == preset,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _restSeconds = preset),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _restSeconds == preset
                            ? AppColors.onPrimary
                            : _p.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomButton(
          label: 'Agregar serie',
          icon: Icons.check_rounded,
          onPressed: _addSet,
        ),
      ],
    );
  }

  /// Descanso con temporizador circular: pausar, +15 s y saltar.
  Widget _buildRestPanel() {
    final total = _restTotal <= 0 ? _restRemaining : _restTotal;
    final progress = total <= 0 ? 0.0 : _restRemaining / total;
    final ending = _restRemaining <= 10;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: ShapeDecoration(
        color: _p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: _p.border),
        ),
      ),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: ending ? AppColors.accent : AppColors.primary,
                    backgroundColor: _p.surfaceMuted,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DESCANSO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                        color: _p.textSecondary,
                      ),
                    ),
                    // Se reduce si no cabe dentro del anillo.
                    SizedBox(
                      width: 116,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${Formatters.padClock(_restRemaining ~/ 60)}:'
                          '${Formatters.padClock(_restRemaining % 60)}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: ending ? AppColors.accent : _p.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // `Wrap` para que los botones bajen de línea en pantallas estrechas.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _pauseRest,
                icon: Icon(
                  _restPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(_restPaused ? 'Reanudar' : 'Pausar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              OutlinedButton(
                onPressed: () => _extendRest(15),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('+15 s'),
              ),
              FilledButton.icon(
                onPressed: _finishRest,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Saltar descanso'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetsList(String exerciseId, WorkoutProvider provider) {
    final sets = provider.setsFor(exerciseId);
    if (sets.isEmpty) {
      return Text(
        'Aún no hay series registradas para este ejercicio.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: _p.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SERIES HECHAS',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: _p.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in sets.asMap().entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SetRow(
              palette: _p,
              setNumber: entry.value.setNumber,
              weight: entry.value.weight,
              repetitions: entry.value.repetitions,
              completed: entry.value.completed,
              onDelete: () => _confirmRemoveSet(exerciseId, entry.key),
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
}

/// Cronómetro del entrenamiento en la barra superior.
class _ElapsedPill extends StatelessWidget {
  const _ElapsedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const ShapeDecoration(
        color: AppColors.accent,
        shape: AppShapes.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 16, color: AppColors.onAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.onAccent,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Objetivo del plan para el ejercicio (series × reps, peso, descanso) y
/// sus notas.
class _PlanTarget extends StatelessWidget {
  const _PlanTarget({required this.plan, required this.palette});

  final RoutineExercise plan;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: ShapeDecoration(
        color: palette.primarySoft,
        shape: AppShapes.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: palette.primaryText),
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
    );
  }
}

/// Mando grande: valor editable con botones − y + debajo.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.palette,
    required this.label,
    required this.controller,
    required this.lessTooltip,
    required this.moreTooltip,
    required this.onMore,
    required this.onChanged,
    this.onLess,
    this.decimal = false,
  });

  final AppPalette palette;
  final String label;
  final TextEditingController controller;
  final String lessTooltip;
  final String moreTooltip;
  final VoidCallback? onLess;
  final VoidCallback onMore;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textAlign: TextAlign.center,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: label,
              floatingLabelAlignment: FloatingLabelAlignment.center,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Biselados, como el resto de botones de Vatio.
              Expanded(
                child: IconButton.filledTonal(
                  tooltip: lessTooltip,
                  onPressed: onLess,
                  style: IconButton.styleFrom(shape: AppShapes.small),
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IconButton.filled(
                  tooltip: moreTooltip,
                  onPressed: onMore,
                  style: IconButton.styleFrom(shape: AppShapes.small),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.palette,
    required this.setNumber,
    required this.weight,
    required this.repetitions,
    required this.completed,
    this.onDelete,
  });

  final AppPalette palette;
  final int setNumber;
  final double weight;
  final int repetitions;
  final bool completed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: AppShapes.small,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: completed ? AppColors.accent : palette.surfaceMuted,
              shape: AppShapes.chip,
            ),
            child: Text(
              '$setNumber',
              style: TextStyle(
                color: completed ? AppColors.onAccent : palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${Formatters.formatWeight(weight)} kg',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.close_rounded, size: 16, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$repetitions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
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
    final palette = context.palette;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 10.5,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
