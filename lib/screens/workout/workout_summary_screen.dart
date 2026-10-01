import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/workout_model.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/custom_button.dart';

/// Resumen de la sesión recién guardada (`/entrenamiento/resumen`).
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, this.result});

  /// Resultado que envía la pantalla de entrenamiento al finalizar.
  final WorkoutSaveResult? result;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    // Si se abrió sin `extra` (por ejemplo, al recargar en la web), se usa la
    // última sesión que conserva el provider.
    final session = result?.session ?? provider.lastSession;
    final newRecords = result?.newRecords ?? provider.lastNewRecords;

    if (session == null) {
      // Antes esta rama no tenía ninguna acción, dejando al usuario sin
      // salida (por ejemplo al volver atrás desde esta misma pantalla).
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No hay un entrenamiento reciente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Volver a rutinas',
                    icon: Icons.list_alt_rounded,
                    onPressed: () => context.go('/rutinas'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    /// Devuelve la sesión completada a Rutinas. Las estadísticas ya se
    /// actualizaron al guardar (ProgressProvider.agregarSesion), así que no
    /// hace falta volver a leer Firestore.
    void returnSession() {
      // Se navega antes de limpiar el estado: `reset()` dispara
      // `notifyListeners()` de forma sincrónica y esta pantalla podía
      // reconstruirse un frame con `session == null`.
      context.go('/rutinas', extra: session);
      provider.reset();
    }

    // El botón atrás del sistema también devuelve la sesión a Rutinas.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) returnSession();
      },
      child: _buildScaffold(context, session, newRecords, returnSession),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WorkoutSession session,
    List<NewRecordInfo> newRecords,
    VoidCallback returnSession,
  ) {
    return Scaffold(
      body: SafeArea(
        child: FormScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: context.palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Entrenamiento guardado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.routineName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _buildStatsGrid(context, session),
              const SizedBox(height: 20),
              // Comparación con sesiones anteriores: el ProgressProvider ya
              // recibió esta sesión con agregarSesion().
              Consumer<ProgressProvider>(
                builder: (context, progress, _) =>
                    _SessionComparison(session: session, progress: progress),
              ),
              const SizedBox(height: 20),
              _ExercisesDone(session: session),
              // Alimentación de hoy (opcional): solo aparece si el usuario
              // usa ese módulo; el entrenamiento no depende de él.
              const _TodayNutritionCard(),
              if (newRecords.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildNewRecords(context, newRecords),
              ],
              const SizedBox(height: 32),
              CustomButton(
                label: 'Volver a rutinas',
                icon: Icons.list_alt_rounded,
                onPressed: returnSession,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, WorkoutSession session) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Alto fijo en vez de proporción: con `childAspectRatio` las
      // celdas se desbordaban en pantallas anchas o con texto ampliado.
      childAspectRatio: 1,
      children: [
        _SummaryStat(
          icon: Icons.timer_outlined,
          label: 'DURACIÓN',
          value: Formatters.formatDuration(session.duration),
          color: AppColors.primary,
        ),
        _SummaryStat(
          icon: Icons.scale_outlined,
          label: 'VOLUMEN',
          value: '${Formatters.formatNumber(session.totalVolume)} kg',
          color: context.palette.secondary,
        ),
        _SummaryStat(
          icon: Icons.format_list_numbered_rounded,
          label: 'SERIES',
          value: '${session.totalSets}',
          color: AppColors.teal,
        ),
        _SummaryStat(
          icon: Icons.repeat_rounded,
          label: 'REPETICIONES',
          value: '${session.totalReps}',
          color: AppColors.amber,
        ),
      ],
    );
  }

  Widget _buildNewRecords(BuildContext context, List<NewRecordInfo> records) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Nuevos récords personales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...records.map(
          (record) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.palette.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  record.exerciseName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (record.isWeightRecord)
                  Text(
                    record.isFirst
                        ? 'Primer récord: '
                              '${Formatters.formatWeight(record.newWeight)} kg '
                              '× ${record.reps}'
                        : '${record.isRepsRecord ? 'Más repeticiones' : 'Más peso'}: '
                              '${Formatters.formatWeight(record.previousWeight)} kg '
                              '× ${record.previousReps} → '
                              '${Formatters.formatWeight(record.newWeight)} kg '
                              '× ${record.reps}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                if (record.isVolumeRecord && !record.isFirst)
                  Text(
                    'Mejor volumen: '
                    '${Formatters.formatVolume(record.previousVolume)} → '
                    '${Formatters.formatVolume(record.newVolume)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.violet,
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

/// Compara la sesión con la anterior equivalente (misma rutina y día).
class _SessionComparison extends StatelessWidget {
  const _SessionComparison({required this.session, required this.progress});

  final WorkoutSession session;
  final ProgressProvider progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final previous = progress.previousComparable(session);

    Widget line(IconData icon, String label, num diff, String formatted) {
      final Color color;
      if (diff > 0) {
        color = AppColors.success;
      } else if (diff < 0) {
        color = AppColors.error;
      } else {
        color = palette.textSecondary;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
              ),
            ),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    String signed(num value, String Function(num) format) =>
        value > 0 ? '+${format(value)}' : format(value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparado con tu sesión anterior',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          if (previous == null)
            Text(
              'Es la primera vez que registras este entrenamiento. ¡La '
              'próxima vez verás aquí tu evolución!',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            )
          else ...[
            Text(
              Formatters.formatRelativeDay(
                previous.finishedAt ?? previous.startedAt,
              ),
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            line(
              Icons.scale_outlined,
              'Volumen',
              session.totalVolume - previous.totalVolume,
              signed(
                session.totalVolume - previous.totalVolume,
                (v) => Formatters.formatVolume(v.toDouble()),
              ),
            ),
            line(
              Icons.format_list_numbered_rounded,
              'Series',
              session.totalSets - previous.totalSets,
              signed(session.totalSets - previous.totalSets, (v) => '$v'),
            ),
            line(
              Icons.repeat_rounded,
              'Repeticiones',
              session.totalReps - previous.totalReps,
              signed(session.totalReps - previous.totalReps, (v) => '$v'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ejercicios realizados con sus series, mejor serie y volumen, y la
/// diferencia de volumen con la última vez que se hizo cada uno.
class _ExercisesDone extends StatelessWidget {
  const _ExercisesDone({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // watch: si las estadísticas aún se estaban cargando, se actualiza.
    final progress = context.watch<ProgressProvider>();
    final finished = session.finishedAt ?? session.startedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ejercicios realizados',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final record in session.exercises)
          Builder(
            builder: (context) {
              final completed = record.sets.where((s) => s.completed).toList();
              final best = completed.isEmpty
                  ? null
                  : completed.reduce((a, b) => b.outperforms(a) ? b : a);
              final previous = progress.previousRecordFor(
                record.exerciseId,
                before: finished,
                excludingSessionId: session.id,
              );
              final diff = previous == null
                  ? null
                  : record.volume - previous.volume;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.surfaceMuted),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.exerciseName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${completed.length} series',
                              '${record.totalReps} reps',
                              if (best != null && best.weight > 0)
                                'mejor ${Formatters.formatWeight(best.weight)} kg × ${best.repetitions}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatVolume(record.volume),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (diff != null && diff != 0)
                          Text(
                            '${diff > 0 ? '+' : ''}${Formatters.formatVolume(diff)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: diff > 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.surfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.6,
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alimentación de hoy en el resumen: calorías y proteínas consumidas frente
/// al plan activo. Se oculta si el usuario no usa el módulo de alimentación.
class _TodayNutritionCard extends StatefulWidget {
  const _TodayNutritionCard();

  @override
  State<_TodayNutritionCard> createState() => _TodayNutritionCardState();
}

class _TodayNutritionCardState extends State<_TodayNutritionCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NutritionProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionProvider>(
      builder: (context, nutrition, _) {
        final plan = nutrition.activePlan;
        final today = nutrition.today.totals;
        if (!nutrition.loaded || (plan == null && today.kcal == 0)) {
          return const SizedBox.shrink();
        }
        final palette = context.palette;
        String line(double value, double? target, String unit) =>
            target == null || target <= 0
            ? '${Formatters.formatNumber(value.round())} $unit'
            : '${Formatters.formatNumber(value.round())} / '
                  '${Formatters.formatNumber(target.round())} $unit';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.surfaceMuted),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alimentación de hoy',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Calorías: ${line(today.kcal, plan?.calories, 'kcal')}',
                style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
              ),
              Text(
                'Proteínas: ${line(today.protein, plan?.protein, 'g')}',
                style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
              ),
              if (plan != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: NutritionProvider.progress(
                      today.kcal,
                      plan.calories,
                    ),
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: palette.surfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
