import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_day_model.dart';
import '../../models/routine_model.dart';
import '../../models/workout_model.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/free_workout_sheet.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive.dart';
import '../../widgets/routine_card.dart';
import 'routine_detail_screen.dart';

/// Pantalla principal (`/rutinas`). Envía la rutina elegida a
/// `/entrenamiento` y recibe de vuelta la sesión completada.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, this.completedSession});

  /// Sesión que devuelve el flujo de entrenamiento al terminar.
  final WorkoutSession? completedSession;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<WorkoutRoutine> _routines = [];
  List<ExerciseModel> _exercises = [];
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String? _uid;
  bool _visible = true;

  /// Última sesión completada recibida por navegación.
  WorkoutSession? _completed;

  @override
  void initState() {
    super.initState();
    _receiveSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant RoutinesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.completedSession, oldWidget.completedSession)) {
      _receiveSession();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Las pestañas inactivas quedan con los tickers desactivados. Al volver
    // a esta pestaña se recargan rutinas y ejercicios, que pueden haber
    // cambiado en la pestaña Ejercicios.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible && _loaded) _load();
    _visible = visible;
  }

  void _receiveSession() {
    final session = widget.completedSession;
    if (session == null) return;
    _completed = session;
    // Se limpia `extra` de la ruta para que la sesión no vuelva a llegar al
    // regresar a esta pestaña más tarde.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/rutinas');
    });
  }

  Future<void>? _inFlight;

  /// Evita lecturas duplicadas si se pide recargar mientras ya se carga.
  Future<void> _load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    final uid = context.read<WorkoutProvider>().userId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _uid = uid;
    });
    try {
      final results = await Future.wait([
        _firestore.getRoutines(uid),
        _firestore.getExercises(uid),
      ]);
      if (!mounted) return;
      final exercises = (results[1] as List).cast<ExerciseModel>();
      setState(() {
        _exercises = exercises;
        // Cada rutina se relaciona con sus objetos ExerciseModel.
        _routines = (results[0] as List)
            .cast<WorkoutRoutine>()
            .map((routine) => routine.withExercises(exercises))
            .toList();
        _loaded = true;
      });
    } catch (error) {
      // Un fallo de red no debe mostrarse como "no tienes rutinas".
      if (!mounted) return;
      setState(() => _error = ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateRoutine() async {
    await context.push('/rutinas/crear');
    if (!mounted) return;
    await _load();
  }

  Future<void> _openCreateExercise() async {
    await context.push('/ejercicio/crear');
    if (!mounted) return;
    await _load();
  }

  /// Abre el detalle de la rutina; desde allí se elige un día para entrenar
  /// o se pide editarla.
  Future<void> _openDetail(WorkoutRoutine routine) async {
    final result = await context.push<Object>(
      '/rutinas/detalle',
      extra: routine,
    );
    if (!mounted) return;
    if (result is RoutineDay) {
      await _startRoutine(routine, day: result);
    } else if (result == 'edit') {
      await _openEdit(routine);
    }
  }

  Future<void> _openEdit(WorkoutRoutine routine) async {
    await context.push('/rutinas/crear', extra: routine);
    if (mounted) await _load();
  }

  /// Entrena un día de la rutina. Con un solo día se entrena directamente;
  /// con varios, se pregunta cuál.
  Future<void> _startRoutine(
    WorkoutRoutine fullRoutine, {
    RoutineDay? day,
  }) async {
    final provider = context.read<WorkoutProvider>();
    if (fullRoutine.exercises.isEmpty) {
      showAppMessage(context, 'Esta rutina no tiene ejercicios.');
      return;
    }
    var chosen = day;
    if (chosen == null && fullRoutine.days.length > 1) {
      chosen = await showRoutineDayPicker(context, fullRoutine);
      if (chosen == null || !mounted) return;
    }
    chosen ??= fullRoutine.days.isNotEmpty ? fullRoutine.days.first : null;
    final routine = chosen == null ? fullRoutine : fullRoutine.forDay(chosen);
    if (routine.exerciseDetails.isEmpty) {
      showAppMessage(
        context,
        'Los ejercicios de esta rutina ya no existen. Edítala para '
        'seleccionar otros.',
      );
      return;
    }
    if (provider.active) {
      // Antes se reemplazaba el entrenamiento en curso sin avisar y se
      // perdían sus series.
      final replace = await ConfirmationDialog.show(
        context,
        icon: Icons.warning_amber_rounded,
        title: 'Ya tienes un entrenamiento en curso',
        message:
            '"${provider.routineName}" tiene '
            '${provider.totalCompletedSets} series registradas. Si comienzas '
            '"${routine.name}", ese entrenamiento se descartará.',
        confirmLabel: 'Descartar y comenzar',
        cancelLabel: 'Seguir con el actual',
        destructive: true,
      );
      if (!mounted) return;
      if (replace != true) {
        context.go('/entrenamiento');
        return;
      }
    }
    if (!mounted) return;
    // La rutina viaja como objeto a la pantalla de entrenamiento.
    context.go('/entrenamiento', extra: routine);
  }

  Future<void> _deleteRoutine(WorkoutRoutine routine) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar rutina?',
      message:
          'Se eliminará "${routine.name}". Tu historial de '
          'entrenamientos se conserva. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || _uid == null) return;
    try {
      await _firestore.deleteRoutine(_uid!, routine.id);
      if (!mounted) return;
      setState(() => _routines.removeWhere((r) => r.id == routine.id));
      showAppMessage(context, 'Rutina eliminada.', type: FeedbackType.success);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        'No se pudo eliminar la rutina. '
        '${ProgressProvider.describeError(error)}',
      );
    }
  }

  Future<void> _startFreeWorkout() async {
    final started = await showFreeWorkoutSheet(context);
    if (started && mounted) context.go('/entrenamiento');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis rutinas'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/home'),
            icon: const Icon(Icons.dashboard_outlined, size: 20),
            label: const Text('Panel'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && !_loaded) {
      return const LoadingWidget(message: 'Cargando rutinas...');
    }
    if (_error != null && !_loaded) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final completed = _completed;
    if (_routines.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (completed != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _CompletedSessionCard(
                    session: completed,
                    onClose: () => setState(() => _completed = null),
                  ),
                ),
              EmptyState(
                icon: Icons.list_alt_rounded,
                title: 'Todavía no tienes rutinas',
                subtitle: _exercises.isEmpty
                    ? 'Primero crea algunos ejercicios y luego agrúpalos en '
                          'una rutina.'
                    : 'Crea tu primera rutina con los ejercicios que '
                          'quieras realizar.',
                actionLabel: _exercises.isEmpty
                    ? 'Crear ejercicios'
                    : 'Crear rutina',
                onAction: _exercises.isEmpty
                    ? _openCreateExercise
                    : _openCreateRoutine,
              ),
              TextButton.icon(
                onPressed: _startFreeWorkout,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('O entrena en modo libre'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (completed != null) ...[
                  _CompletedSessionCard(
                    session: completed,
                    onClose: () => setState(() => _completed = null),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openCreateRoutine,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nueva rutina'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startFreeWorkout,
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('Libre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - 14 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final routine in _routines)
                          SizedBox(
                            width: width,
                            child: RoutineCard(
                              routine: routine,
                              exerciseCount: routine.exercises.length,
                              exerciseNames: [
                                for (final e in routine.exerciseDetails) e.name,
                              ],
                              onStart: () => _startRoutine(routine),
                              onTap: () => _openDetail(routine),
                              onDelete: () => _deleteRoutine(routine),
                              onEdit: () => _openEdit(routine),
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

/// Resumen de la sesión que el entrenamiento devolvió a esta pantalla.
class _CompletedSessionCard extends StatelessWidget {
  const _CompletedSessionCard({required this.session, required this.onClose});

  final WorkoutSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      color: palette.primarySoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sesión completada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            Text(
              '${session.routineName} · ${session.totalSets} series · '
              '${session.totalReps} reps · '
              '${Formatters.formatVolume(session.totalVolume)} · '
              '${Formatters.formatDuration(session.duration)}',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go('/progreso'),
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('Ver mi progreso'),
            ),
          ],
        ),
      ),
    );
  }
}
