import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/personal_record_model.dart';
import '../../models/progress_model.dart';
import '../../models/workout_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/free_workout_sheet.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/responsive.dart';
import '../../widgets/weekly_goals_card.dart';
import '../../widgets/workout_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _repeating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProgressProvider>().refresh();
    });
  }

  Future<void> _refresh() => context.read<ProgressProvider>().refresh();

  Future<void> _startFreeWorkout() async {
    final started = await showFreeWorkoutSheet(context);
    if (started && mounted) context.go('/entrenamiento');
  }

  Future<void> _repeatRoutine(String routineId, String dayId) async {
    final workout = context.read<WorkoutProvider>();
    if (workout.active) {
      context.go('/entrenamiento');
      return;
    }
    setState(() => _repeating = true);
    try {
      final error = await workout.repeatRoutine(routineId, dayId: dayId);
      if (!mounted) return;
      if (error == null) {
        context.go('/entrenamiento');
      } else {
        showAppMessage(context, error);
      }
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, ProgressProvider.describeError(error));
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final progressProvider = context.watch<ProgressProvider>();
    final workout = context.watch<WorkoutProvider>();
    final progress = progressProvider.progress;

    final sections = <Widget>[
      _Header(
        name: _firstName(auth.displayName),
        goal: auth.profile?.goal,
        level: auth.profile?.level,
        onAvatarTap: () => context.go('/profile'),
      ),
      if (workout.active)
        _ActiveWorkoutBanner(
          name: workout.routineName,
          sets: workout.totalCompletedSets,
          onContinue: () => context.go('/entrenamiento'),
        ),
    ];

    if (progress == null) {
      sections.add(
        progressProvider.error != null
            ? _LoadError(message: progressProvider.error!, onRetry: _refresh)
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
      );
    } else if (progress.totalWorkouts == 0) {
      sections.add(_WelcomeCard(onFreeWorkout: _startFreeWorkout));
    } else {
      if (progressProvider.error != null) {
        sections.add(
          _LoadError(message: progressProvider.error!, onRetry: _refresh),
        );
      }
      sections.add(
        _WeekSummary(
          progress: progress,
          thisWeek: progressProvider.thisWeek,
          lastWeek: progressProvider.lastWeek,
          streak: progressProvider.dayStreak,
        ),
      );
      sections.add(const WeeklyGoalsCard());
    }

    sections.add(_QuickActions(onFreeWorkout: _startFreeWorkout));

    if (progress != null && progress.totalWorkouts > 0) {
      final last = progressProvider.lastWorkout;
      final record = progressProvider.latestRecord;
      sections.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              if (last != null)
                _LastWorkoutCard(
                  session: last,
                  busy: _repeating,
                  onRepeat: last.routineId.isEmpty
                      ? null
                      : () => _repeatRoutine(last.routineId, last.routineDayId),
                ),
              if (record != null) _LatestRecordCard(record: record),
            ];
            if (constraints.maxWidth < 700 || cards.length < 2) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ],
                ),
              ),
            );
          },
        ),
      );
      sections.add(const SectionHeader(title: 'Tu historial'));
      sections.add(
        StatGrid(
          children: [
            ProgressCard(
              icon: Icons.fitness_center_rounded,
              value: '${progress.totalWorkouts}',
              label: 'Entrenamientos',
              onTap: () => context.go('/progreso'),
            ),
            ProgressCard(
              icon: Icons.scale_rounded,
              value: Formatters.formatVolume(progress.totalVolume),
              label: 'Volumen total',
              color: AppColors.violet,
              onTap: () => context.go('/progreso'),
            ),
            ProgressCard(
              icon: Icons.format_list_numbered_rounded,
              value: '${progress.totalSets}',
              label: 'Series',
              color: AppColors.teal,
              onTap: () => context.go('/progreso'),
            ),
            ProgressCard(
              icon: Icons.emoji_events_rounded,
              value: '${progress.recordCount}',
              label: 'Récords',
              color: AppColors.amber,
              onTap: () => context.go('/progreso'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        // Se abre desde Rutinas (con botón atrás); si se llegó con `go`, se
        // ofrece volver a la pantalla principal.
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                tooltip: 'Ir a rutinas',
                icon: const Icon(Icons.list_alt_rounded),
                onPressed: () => context.go('/rutinas'),
              ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in sections) ...[
                      section,
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'atleta';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.goal,
    required this.level,
    required this.onAvatarTap,
  });

  final String name;
  final String? goal;
  final String? level;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final date = Formatters.formatLongDate(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date[0].toUpperCase() + date.substring(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hola, $name',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              if (goal != null || level != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (goal != null)
                      _Pill(icon: Icons.flag_rounded, label: goal!),
                    if (level != null)
                      _Pill(icon: Icons.trending_up_rounded, label: level!),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: onAvatarTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: palette.primarySoft,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({
    required this.name,
    required this.sets,
    required this.onContinue,
  });

  final String name;
  final int sets;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.timer_rounded,
                color: AppColors.onPrimary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrenamiento en curso',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$name · $sets ${sets == 1 ? 'serie' : 'series'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Continuar',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.palette.textPrimary),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onFreeWorkout});

  final VoidCallback onFreeWorkout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: palette.primarySoft,
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empieza a entrenar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aún no tienes entrenamientos. Así empiezas:',
              style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
            ),
            step(1, 'Crea tus ejercicios (press banca, sentadilla...).'),
            step(2, 'Agrúpalos en una rutina o entrena en modo libre.'),
            step(3, 'Registra tus series y mira tu progreso crecer.'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/ejercicio/crear'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear ejercicio'),
                ),
                OutlinedButton.icon(
                  onPressed: onFreeWorkout,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Entrenamiento libre'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.progress,
    required this.thisWeek,
    required this.lastWeek,
    required this.streak,
  });

  final ProgressModel progress;
  final PeriodTotals thisWeek;
  final PeriodTotals lastWeek;
  final int streak;

  String? get _volumeComparison {
    if (lastWeek.volume <= 0) {
      return thisWeek.volume > 0 ? 'Semana pasada: sin volumen' : null;
    }
    final change = (thisWeek.volume - lastWeek.volume) / lastWeek.volume * 100;
    final rounded = change.round();
    if (rounded == 0) return 'Igual que la semana pasada';
    return '${rounded > 0 ? '+' : ''}$rounded% vs. semana pasada';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = progress.weekVolumeByDay;
    final workouts = progress.weekWorkoutsByDay;
    final maxVolume = days.fold<double>(0, (m, v) => v > m ? v : m);
    final today = DateTime.now().weekday - 1;
    final comparison = _volumeComparison;
    final better = thisWeek.volume >= lastWeek.volume;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Esta semana',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Racha: $streak ${streak == 1 ? 'día' : 'días'}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _WeekFigure(
                  value: '${thisWeek.workouts}',
                  label: thisWeek.workouts == 1
                      ? 'entrenamiento'
                      : 'entrenamientos',
                ),
                _WeekFigure(
                  value: Formatters.formatVolume(thisWeek.volume),
                  label: 'volumen',
                ),
                _WeekFigure(value: '${thisWeek.sets}', label: 'series'),
              ],
            ),
            if (comparison != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    better
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                    color: better ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      comparison,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: better ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 86,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final value = days[index];
                  final ratio = maxVolume <= 0 ? 0.0 : value / maxVolume;
                  final trained = workouts[index] > 0;
                  return Expanded(
                    child: Tooltip(
                      message: trained
                          ? '${AppConstants.weekDays[index]}: '
                                '${Formatters.formatVolume(value)}'
                          : AppConstants.weekDays[index],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: trained
                                    ? ratio.clamp(0.12, 1.0)
                                    : 0.12,
                                child: Container(
                                  width: 22,
                                  decoration: BoxDecoration(
                                    color: trained
                                        ? (index == today
                                              ? AppColors.primary
                                              : AppColors.primaryLight)
                                        : palette.surfaceMuted,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppConstants.weekDays[index].substring(0, 1),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: index == today
                                  ? AppColors.primary
                                  : palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekFigure extends StatelessWidget {
  const _WeekFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onFreeWorkout});

  final VoidCallback onFreeWorkout;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.play_circle_fill_rounded,
        label: 'Iniciar rutina',
        color: AppColors.primary,
        onTap: () => context.go('/rutinas'),
      ),
      _QuickAction(
        icon: Icons.bolt_rounded,
        label: 'Entrenamiento libre',
        color: AppColors.violet,
        onTap: onFreeWorkout,
      ),
      _QuickAction(
        icon: Icons.fitness_center_rounded,
        label: 'Mis ejercicios',
        color: AppColors.teal,
        onTap: () => context.go('/ejercicio'),
      ),
      _QuickAction(
        icon: Icons.insights_rounded,
        label: 'Ver progreso',
        color: AppColors.amber,
        onTap: () => context.go('/progreso'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Accesos rápidos'),
        StatGrid(minTileWidth: 140, children: actions),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  const _LastWorkoutCard({
    required this.session,
    required this.busy,
    required this.onRepeat,
  });

  final WorkoutSession session;
  final bool busy;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Último entrenamiento',
          actionLabel: onRepeat == null || busy ? null : 'Repetir',
          onAction: onRepeat,
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        WorkoutCard(session: session),
      ],
    );
  }
}

class _LatestRecordCard extends StatelessWidget {
  const _LatestRecordCard({required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Récord más reciente'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${record.reps} reps · '
                        '${Formatters.formatRelativeDay(record.date!)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${Formatters.formatWeight(record.maxWeight)} kg',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
