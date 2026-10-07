import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/personal_record_model.dart';
import '../../models/progress_model.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/responsive.dart';
import '../../widgets/weekly_goals_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String? _selectedExerciseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProgressProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso'),
        automaticallyImplyLeading: false,
        actions: [
          // Los logros forman parte de Progreso en la nueva navegación.
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.logros),
            icon: const Icon(Icons.emoji_events_rounded, size: 20),
            label: const Text('Logros'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Panel de estadísticas: se reconstruye cada vez que ProgressProvider
      // llama a notifyListeners() (por ejemplo, al guardar un entrenamiento).
      body: Consumer<ProgressProvider>(
        builder: (context, provider, _) =>
            _buildBody(provider, provider.progress),
      ),
    );
  }

  Widget _buildBody(ProgressProvider provider, ProgressModel? progress) {
    if (progress == null) {
      if (provider.error != null) {
        return ErrorState(
          message: provider.error!,
          onRetry: () => provider.refresh(),
        );
      }
      return const LoadingWidget(message: 'Calculando tu progreso...');
    }
    if (progress.totalWorkouts == 0) {
      return RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            EmptyState(
              icon: Icons.insights_rounded,
              title: 'Sin datos todavía',
              subtitle:
                  'Completa tu primer entrenamiento para ver tus '
                  'estadísticas, gráficos y récords.',
              actionLabel: 'Elegir rutina',
              onAction: () => context.go('/rutinas'),
            ),
          ],
        ),
      );
    }

    final series = provider.exerciseWeightSeries();
    ExerciseWeightSeries? selected;
    if (series.isNotEmpty) {
      selected = series.firstWhere(
        (s) => s.exerciseId == _selectedExerciseId,
        orElse: () => series.first,
      );
    }

    final byExercise = provider.progressByExercise;
    final charts = <Widget>[
      const WeeklyGoalsCard(),
      _WeeklyVolumeChart(
        progress: progress,
        thisWeek: provider.thisWeek,
        lastWeek: provider.lastWeek,
        weekDuration: provider.thisWeekDuration,
      ),
      _WeeksHistoryChart(weeks: provider.weeklyAscending),
      if (selected != null)
        _ExerciseTrendChart(
          series: selected,
          allSeries: series,
          stats: byExercise[selected.exerciseId],
          weekly: provider.weeklyBestWeight(selected.exerciseId),
          onChanged: (id) => setState(() => _selectedExerciseId = id),
        ),
      _PersonalRecords(records: provider.topRecords),
    ];

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.error != null) ...[
                  _InlineError(
                    message: provider.error!,
                    onRetry: provider.refresh,
                  ),
                  const SizedBox(height: 14),
                ],
                StatGrid(
                  children: [
                    ProgressCard(
                      icon: Icons.fitness_center_rounded,
                      label: 'Entrenamientos',
                      value: '${progress.totalWorkouts}',
                    ),
                    ProgressCard(
                      icon: Icons.scale_rounded,
                      label: 'Volumen total',
                      value: Formatters.formatVolume(progress.totalVolume),
                      color: AppColors.violet,
                    ),
                    ProgressCard(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Series',
                      value: '${progress.totalSets}',
                      color: AppColors.teal,
                    ),
                    ProgressCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'Récords',
                      value: '${progress.recordCount}',
                      color: AppColors.amber,
                    ),
                    ProgressCard(
                      icon: Icons.timer_outlined,
                      label: 'Tiempo entrenado',
                      value: Formatters.formatDuration(provider.totalDuration),
                    ),
                    ProgressCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Racha (días)',
                      value: '${provider.dayStreak}',
                      color: AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final chart in charts) ...[
                            chart,
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }
                    final half = (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final chart in charts)
                          SizedBox(width: half, child: chart),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No se pudo actualizar: $message',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
            if (header != null) ...[const SizedBox(height: 12), header!],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
        ),
      ),
    );
  }
}

BarTouchData _barTouch(
  BuildContext context,
  String Function(int x, double y) label,
) {
  final palette = context.palette;
  return BarTouchData(
    enabled: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => palette.secondaryContainer,
      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
        label(group.x, rod.toY),
        TextStyle(
          color: palette.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({
    required this.progress,
    required this.thisWeek,
    required this.lastWeek,
    this.weekDuration = Duration.zero,
  });

  final ProgressModel progress;
  final PeriodTotals thisWeek;
  final PeriodTotals lastWeek;
  final Duration weekDuration;

  @override
  Widget build(BuildContext context) {
    final hasData = progress.weekWorkoutsByDay.any((w) => w > 0);
    final palette = context.palette;

    Widget figure(String value, String label) => SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );

    return _ChartCard(
      title: 'Esta semana',
      subtitle: 'Volumen (kg) por día · lunes a domingo',
      child: !hasData
          ? const _EmptyChart('Aún no registraste entrenamientos esta semana.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Totales acumulados de la semana.
                Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    figure('${thisWeek.workouts}', 'Entrenamientos'),
                    figure('${thisWeek.sets}', 'Series'),
                    figure(Formatters.formatVolume(thisWeek.volume), 'Volumen'),
                    figure(Formatters.formatDuration(weekDuration), 'Tiempo'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildChart(context),
                const SizedBox(height: 14),
                _WeekBreakdown(
                  progress: progress,
                  thisWeek: thisWeek,
                  lastWeek: lastWeek,
                ),
              ],
            ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final palette = context.palette;
    final days = progress.weekVolumeByDay;
    final workouts = progress.weekWorkoutsByDay;
    final maxVolume = days.fold<double>(0, (m, v) => v > m ? v : m);
    final today = DateTime.now().weekday - 1;
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxVolume <= 0 ? 1 : maxVolume * 1.15,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barGroups: List.generate(7, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: days[index],
                  color: index == today
                      ? AppColors.primary
                      : AppColors.primaryLight,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVolume <= 0 ? 1 : maxVolume * 1.15,
                    color: palette.surfaceMuted,
                  ),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= 7) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      AppConstants.weekDays[index].substring(0, 1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: index == today
                            ? AppColors.primary
                            : palette.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: _barTouch(
            context,
            (x, y) =>
                '${AppConstants.weekDays[x]}\n'
                '${Formatters.formatNumber(y)} kg · '
                '${workouts[x]} entren.',
          ),
        ),
      ),
    );
  }
}

/// Progreso semanal acumulado: series y volumen de cada día, total de la
/// semana y comparación con la semana anterior.
class _WeekBreakdown extends StatelessWidget {
  const _WeekBreakdown({
    required this.progress,
    required this.thisWeek,
    required this.lastWeek,
  });

  final ProgressModel progress;
  final PeriodTotals thisWeek;
  final PeriodTotals lastWeek;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sets = progress.weekSetsByDay;
    final volume = progress.weekVolumeByDay;
    final today = DateTime.now().weekday - 1;

    var totalSets = 0;
    var totalVolume = 0.0;
    final rows = <Widget>[];
    for (var day = 0; day < 7; day++) {
      totalSets += sets[day];
      totalVolume += volume[day];
      // Solo se listan los días con series y el día de hoy.
      if (sets[day] == 0 && day != today) continue;
      rows.add(
        _BreakdownRow(
          label: AppConstants.weekDays[day],
          sets: sets[day],
          volume: volume[day],
          highlight: day == today,
        ),
      );
    }

    final setsDiff = thisWeek.sets - lastWeek.sets;
    final String comparison;
    if (lastWeek.sets == 0) {
      comparison = 'La semana pasada no registraste series.';
    } else if (setsDiff > 0) {
      comparison = '$setsDiff series más que la semana pasada.';
    } else if (setsDiff < 0) {
      comparison = '${-setsDiff} series menos que la semana pasada.';
    } else {
      comparison = 'Mismas series que la semana pasada.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: palette.border, height: 1),
        const SizedBox(height: 8),
        ...rows,
        Divider(color: palette.border, height: 16),
        _BreakdownRow(
          label: 'Total',
          sets: totalSets,
          volume: totalVolume,
          bold: true,
        ),
        const SizedBox(height: 6),
        Text(
          comparison,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: setsDiff >= 0 ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.sets,
    required this.volume,
    this.highlight = false,
    this.bold = false,
  });

  final String label;
  final int sets;
  final double volume;
  final bool highlight;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: bold || highlight ? FontWeight.w800 : FontWeight.w500,
      color: highlight ? AppColors.primary : palette.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          SizedBox(
            width: 80,
            child: Text(
              sets == 1 ? '1 serie' : '$sets series',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              Formatters.formatVolume(volume),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeksHistoryChart extends StatelessWidget {
  const _WeeksHistoryChart({required this.weeks});

  /// Semanas en orden cronológico (de la más antigua a la actual).
  final List<WeeklyProgress> weeks;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxVolume = weeks.fold<double>(
      0,
      (m, w) => w.totalVolume > m ? w.totalVolume : m,
    );

    return _ChartCard(
      title: 'Últimas semanas',
      subtitle: 'Volumen semanal (kg) · de la más antigua a la actual',
      child: weeks.length < 2
          ? const _EmptyChart(
              'Entrena al menos dos semanas distintas para comparar tu '
              'evolución.',
            )
          : SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxVolume <= 0 ? 1 : maxVolume * 1.15,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: List.generate(weeks.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: weeks[index].totalVolume,
                          color: index == weeks.length - 1
                              ? AppColors.primary
                              : palette.secondary.withValues(alpha: 0.55),
                          width: weeks.length > 8 ? 12 : 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= weeks.length) {
                            return const SizedBox.shrink();
                          }
                          final start = weeks[index].weekStart.toLocal();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${start.day}/${start.month}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: palette.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: _barTouch(context, (x, y) {
                    final week = weeks[x];
                    return 'Semana del '
                        '${Formatters.formatDate(week.weekStart)}\n'
                        '${Formatters.formatNumber(y)} kg · '
                        '${week.workouts} entren.';
                  }),
                ),
              ),
            ),
    );
  }
}

class _ExerciseTrendChart extends StatelessWidget {
  const _ExerciseTrendChart({
    required this.series,
    required this.allSeries,
    required this.onChanged,
    this.stats,
    this.weekly = const [],
  });

  final ExerciseWeightSeries series;
  final List<ExerciseWeightSeries> allSeries;
  final ValueChanged<String?> onChanged;

  /// Progreso acumulado del ejercicio elegido (de `progressByExercise`).
  final ExerciseProgress? stats;

  /// Peso máximo por semana (de la más antigua a la más reciente).
  final List<({DateTime weekStart, double bestWeight})> weekly;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final weights = series.weights;
    final maxWeight = weights.fold<double>(0, (m, v) => v > m ? v : m);
    final spots = List.generate(
      weights.length,
      (index) => FlSpot(index.toDouble(), weights[index]),
    );
    final first = weights.first;
    final last = weights.last;
    final change = last - first;

    return _ChartCard(
      title: 'Progreso por ejercicio',
      subtitle: 'Peso máximo por sesión · de la más antigua a la más reciente',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            // La clave fuerza a reflejar la selección actual.
            key: ValueKey(series.exerciseId),
            initialValue: series.exerciseId,
            isExpanded: true,
            items: [
              for (final s in allSeries)
                DropdownMenuItem<String>(
                  value: s.exerciseId,
                  child: Text(s.exerciseName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: 'Ejercicio',
              prefixIcon: Icon(Icons.fitness_center_rounded),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          if (stats != null) ...[
            const SizedBox(height: 12),
            _ExerciseStats(stats: stats!),
          ],
          if (weekly.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WeeklyBestTable(weekly: weekly),
          ],
        ],
      ),
      child: spots.length < 2
          ? const _EmptyChart(
              'Registra este ejercicio en al menos 2 entrenamientos para ver '
              'la tendencia.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change == 0
                      ? 'Sin cambios desde tu primera sesión.'
                      : '${change > 0 ? '+' : ''}'
                            '${Formatters.formatWeight(change)} kg desde tu '
                            'primera sesión',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: change >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxWeight * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: palette.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${value.round()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              final isEdge =
                                  index == 0 || index == spots.length - 1;
                              if (!isEdge || value != index.toDouble()) {
                                return const SizedBox.shrink();
                              }
                              final date = series.dates[index].toLocal();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => palette.secondaryContainer,
                          getTooltipItems: (spots) => spots
                              .map(
                                (spot) => LineTooltipItem(
                                  '${Formatters.formatDate(series.dates[spot.x.toInt()])}\n'
                                  '${Formatters.formatWeight(spot.y)} kg',
                                  TextStyle(
                                    color: palette.onSecondaryContainer,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          preventCurveOverShooting: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                  strokeColor: palette.surface,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Peso máximo de cada semana entrenada ("Semana del 5/10 — 60 kg") con
/// la variación respecto de la semana anterior.
class _WeeklyBestTable extends StatelessWidget {
  const _WeeklyBestTable({required this.weekly});

  final List<({DateTime weekStart, double bestWeight})> weekly;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = weekly.length - 1; i >= 0; i--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Semana del ${weekly[i].weekStart.day}/'
                      '${weekly[i].weekStart.month}',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  if (i > 0)
                    Builder(
                      builder: (context) {
                        final diff =
                            weekly[i].bestWeight - weekly[i - 1].bestWeight;
                        if (diff == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            '${diff > 0 ? '+' : ''}'
                            '${Formatters.formatWeight(diff)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: diff > 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        );
                      },
                    ),
                  Text(
                    '${Formatters.formatWeight(weekly[i].bestWeight)} kg',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
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

/// Resumen numérico del progreso de un ejercicio.
class _ExerciseStats extends StatelessWidget {
  const _ExerciseStats({required this.stats});

  final ExerciseProgress stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = stats.progressPercent;
    final percentLabel = percent == 0
        ? 'Sin cambios'
        : '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(1)} %';

    Widget item(String value, String label, [Color? color]) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          item(
            '${Formatters.formatWeight(stats.bestWeight)} × ${stats.bestReps}',
            'Mejor marca',
            AppColors.primary,
          ),
          item('${stats.workoutCount}', 'Sesiones'),
          item('${stats.totalSets}', 'Series'),
          item(
            percentLabel,
            'Progreso',
            percent >= 0 ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _PersonalRecords extends StatelessWidget {
  const _PersonalRecords({required this.records});

  final List<PersonalRecord> records;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _ChartCard(
      title: 'Récords personales',
      subtitle: 'Mejor marca por ejercicio: peso × repeticiones',
      child: records.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no tienes récords. Registra series con peso para '
                'conseguir el primero.',
                style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
              ),
            )
          : Column(
              children: [
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 20,
                            color: AppColors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.exerciseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              if (record.date != null)
                                Text(
                                  'Logrado el '
                                  '${Formatters.formatDate(record.date!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              if (record.bestVolume > 0)
                                Text(
                                  'Mejor volumen en una sesión: '
                                  '${Formatters.formatVolume(record.bestVolume)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${Formatters.formatWeight(record.maxWeight)} kg '
                          '× ${record.reps}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.palette.primaryText,
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
