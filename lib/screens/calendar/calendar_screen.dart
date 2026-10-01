import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_day_model.dart';
import '../../models/routine_model.dart';
import '../../models/scheduled_workout_model.dart';
import '../../models/workout_model.dart';
import '../../providers/progress_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/month_calendar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/workout_card.dart';

/// Mi calendario (`/calendario`): días entrenados (de ProgressProvider) y
/// entrenamientos programados (de ScheduleProvider).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress = context.read<ProgressProvider>();
      if (!progress.hasData && !progress.loading) progress.refresh();
      final schedule = context.read<ScheduleProvider>();
      if (!schedule.loaded && !schedule.loading) schedule.load();
    });
  }

  Future<void> _reload() async {
    await Future.wait([
      context.read<ProgressProvider>().refresh(),
      context.read<ScheduleProvider>().load(),
    ]);
  }

  Map<DateTime, DayMarkers> _markers(
    ProgressProvider progress,
    ScheduleProvider schedule,
  ) {
    final days = {...progress.trainedDays, ...schedule.scheduledDays};
    return {
      for (final day in days)
        day: () {
          final sessions = progress.sessionsOn(day);
          final planned = schedule.forDay(day);
          return DayMarkers(
            trained: sessions.isNotEmpty,
            scheduled: planned.length,
            scheduledDone: planned
                .where((p) => p.isCompletedBy(sessions))
                .length,
          );
        }(),
    };
  }

  Future<void> _openScheduleSheet() async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleSheet(initialDate: _selected),
    );
    if (created == null || created == 0 || !mounted) return;
    showAppMessage(
      context,
      created == 1
          ? 'Entrenamiento programado.'
          : 'Se programaron $created entrenamientos.',
      type: FeedbackType.success,
    );
  }

  /// Entrena un día programado: la rutina viaja como objeto a
  /// `/entrenamiento`, igual que desde Rutinas.
  Future<void> _train(ScheduledWorkout item) async {
    final workout = context.read<WorkoutProvider>();
    final uid = workout.userId;
    if (uid == null) return;
    final firestore = FirestoreService();
    try {
      final results = await Future.wait([
        firestore.getRoutines(uid),
        firestore.getExercises(uid),
      ]);
      if (!mounted) return;
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
        if (!mounted) return;
        if (replace != true) {
          context.go('/entrenamiento');
          return;
        }
      }
      context.go('/entrenamiento', extra: toStart);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, ProgressProvider.describeError(error));
    }
  }

  Future<void> _remove(ScheduledWorkout item) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.event_busy_rounded,
      title: '¿Quitar del calendario?',
      message: '"${item.title}" dejará de estar programado ese día.',
      confirmLabel: 'Quitar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ScheduleProvider>().remove(item.id);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, ProgressProvider.describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi calendario'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _month = DateTime(now.year, now.month);
                _selected = DateTime(now.year, now.month, now.day);
              });
            },
            icon: const Icon(Icons.today_rounded, size: 20),
            label: const Text('Hoy'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Etiqueta propia: las pestañas conviven en un IndexedStack y otro
        // FAB (Ejercicios) usa la etiqueta Hero por defecto.
        heroTag: 'fab-calendario',
        onPressed: _openScheduleSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.event_available_rounded),
        label: const Text('Programar'),
      ),
      // Se reconstruye con cada notifyListeners de ProgressProvider (nuevas
      // sesiones) y de ScheduleProvider (lo programado).
      body: Consumer2<ProgressProvider, ScheduleProvider>(
        builder: (context, progress, schedule, _) {
          final markers = _markers(progress, schedule);
          final calendar = Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
              child: MonthCalendar(
                month: _month,
                selectedDay: _selected,
                markers: markers,
                onMonthChanged: (month) => setState(() => _month = month),
                onDaySelected: (day) => setState(() {
                  _selected = day;
                  _month = DateTime(day.year, day.month);
                }),
              ),
            ),
          );
          final summary = _MonthSummary(
            month: _month,
            markers: markers,
            streak: progress.dayStreak,
          );
          final dayPanel = _DayPanel(
            day: _selected,
            sessions: progress.sessionsOn(_selected),
            scheduled: schedule.forDay(_selected),
            onTrain: _train,
            onRemove: _remove,
            onSchedule: _openScheduleSheet,
          );

          return RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    summary,
                                    const SizedBox(height: 16),
                                    calendar,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: dayPanel),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    MaxWidth(
                      maxWidth: Breakpoints.form + 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 14),
                          calendar,
                          const SizedBox(height: 18),
                          dayPanel,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.month,
    required this.markers,
    required this.streak,
  });

  final DateTime month;
  final Map<DateTime, DayMarkers> markers;
  final int streak;

  @override
  Widget build(BuildContext context) {
    var trained = 0;
    var scheduled = 0;
    var done = 0;
    for (final entry in markers.entries) {
      if (entry.key.year != month.year || entry.key.month != month.month) {
        continue;
      }
      if (entry.value.trained) trained++;
      scheduled += entry.value.scheduled;
      done += entry.value.scheduledDone;
    }
    return Row(
      children: [
        _SummaryTile(
          icon: Icons.check_circle_rounded,
          value: '$trained',
          label: 'Días entrenados',
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.event_available_rounded,
          value: scheduled == 0 ? '0' : '$done/$scheduled',
          label: 'Programados',
          color: AppColors.teal,
        ),
        const SizedBox(width: 10),
        _SummaryTile(
          icon: Icons.local_fire_department_rounded,
          value: '$streak',
          label: 'Racha (días)',
          color: AppColors.error,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle del día elegido: sesiones realizadas y entrenamientos
/// programados.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.sessions,
    required this.scheduled,
    required this.onTrain,
    required this.onRemove,
    required this.onSchedule,
  });

  final DateTime day;
  final List<WorkoutSession> sessions;
  final List<ScheduledWorkout> scheduled;
  final ValueChanged<ScheduledWorkout> onTrain;
  final ValueChanged<ScheduledWorkout> onRemove;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
    final title = Formatters.formatLongDate(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.isEmpty ? title : title[0].toUpperCase() + title.substring(1),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty && scheduled.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 34,
                  color: palette.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  isPast
                      ? 'No entrenaste este día.'
                      : 'Nada programado para este día.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: palette.textSecondary,
                  ),
                ),
                if (!isPast) ...[
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Programar entrenamiento',
                    icon: Icons.event_available_rounded,
                    variant: ButtonVariant.outline,
                    onPressed: onSchedule,
                  ),
                ],
              ],
            ),
          ),
        if (scheduled.isNotEmpty) ...[
          _label(context, 'Programado'),
          for (final item in scheduled)
            _ScheduledTile(
              item: item,
              done: item.isCompletedBy(sessions),
              missed: isPast && !item.isCompletedBy(sessions),
              onTrain: () => onTrain(item),
              onRemove: () => onRemove(item),
            ),
          const SizedBox(height: 8),
        ],
        if (sessions.isNotEmpty) ...[
          _label(context, 'Sesiones realizadas'),
          for (final session in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkoutCard(session: session),
            ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
        color: context.palette.textSecondary,
      ),
    ),
  );
}

class _ScheduledTile extends StatelessWidget {
  const _ScheduledTile({
    required this.item,
    required this.done,
    required this.missed,
    required this.onTrain,
    required this.onRemove,
  });

  final ScheduledWorkout item;
  final bool done;
  final bool missed;
  final VoidCallback onTrain;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color color;
    final String status;
    final IconData icon;
    if (done) {
      color = AppColors.success;
      status = 'Completado';
      icon = Icons.check_circle_rounded;
    } else if (missed) {
      color = AppColors.error;
      status = 'No realizado';
      icon = Icons.cancel_outlined;
    } else {
      color = AppColors.teal;
      status = 'Pendiente';
      icon = Icons.schedule_rounded;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    item.notes.isEmpty ? status : '$status · ${item.notes}',
                    style: TextStyle(fontSize: 12.5, color: color),
                  ),
                ],
              ),
            ),
            if (!done)
              TextButton(onPressed: onTrain, child: const Text('Entrenar')),
            IconButton(
              tooltip: 'Quitar del calendario',
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para programar un entrenamiento: rutina, día, fecha y repetición
/// semanal. Devuelve cuántos se programaron.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  final _notesController = TextEditingController();
  List<WorkoutRoutine> _routines = [];
  WorkoutRoutine? _routine;
  RoutineDay? _day;
  late DateTime _date = widget.initialDate;
  bool _repeat = false;
  int _weeks = 4;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<WorkoutProvider>().userId;
    if (uid == null) return;
    try {
      final routines = await FirestoreService().getRoutines(uid);
      if (!mounted) return;
      setState(() {
        _routines = routines;
        _routine = routines.isEmpty ? null : routines.first;
        _day = _routine?.days.isNotEmpty == true ? _routine!.days.first : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Fecha del entrenamiento',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final routine = _routine;
    if (routine == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await context.read<ScheduleProvider>().schedule(
        routine: routine,
        day: _day,
        date: _date,
        weeks: _repeat ? _weeks : 1,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final weekday = AppConstants.weekDays[_date.weekday - 1].toLowerCase();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Programar entrenamiento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_routines.isEmpty)
                Text(
                  'Primero crea una rutina para poder programarla.',
                  style: TextStyle(color: palette.textSecondary),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _routine?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rutina',
                    prefixIcon: Icon(Icons.list_alt_rounded),
                  ),
                  items: [
                    for (final r in _routines)
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (id) => setState(() {
                    _routine = _routines.firstWhere((r) => r.id == id);
                    _day = _routine!.days.isNotEmpty
                        ? _routine!.days.first
                        : null;
                  }),
                ),
                if ((_routine?.days.length ?? 0) > 1) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_routine!.id),
                    initialValue: _day?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Día de la rutina',
                      prefixIcon: Icon(Icons.calendar_view_week_rounded),
                    ),
                    items: [
                      for (final d in _routine!.days)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (id) =>
                        setState(() => _day = _routine!.dayById(id ?? '')),
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(Formatters.formatDate(_date)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _repeat,
                  onChanged: (v) => setState(() => _repeat = v),
                  title: Text('Repetir cada $weekday'),
                  subtitle: Text(
                    _repeat ? 'Durante $_weeks semanas' : 'Solo este día',
                  ),
                ),
                if (_repeat)
                  Row(
                    children: [
                      Text(
                        'Semanas',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      Expanded(
                        child: Slider(
                          value: _weeks.toDouble(),
                          min: 2,
                          max: 12,
                          divisions: 10,
                          label: '$_weeks',
                          onChanged: (v) => setState(() => _weeks = v.round()),
                        ),
                      ),
                      Text('$_weeks'),
                    ],
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 18),
                CustomButton(
                  label: 'Guardar en el calendario',
                  icon: Icons.event_available_rounded,
                  loading: _saving,
                  onPressed: _routine == null ? null : _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
