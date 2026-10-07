import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/nutrition_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/schedule_provider.dart';
import 'month_calendar.dart';

/// Marcas de cada día con actividad (Calendario y "Hoy"): sesiones,
/// programados (y cuántos se cumplieron) y alimentación registrada (comida
/// anotada o meta de agua cumplida).
Map<DateTime, DayMarkers> dayMarkersFor({
  required ProgressProvider progress,
  required ScheduleProvider schedule,
  required NutritionProvider nutrition,
}) {
  final waterGoal = nutrition.waterGoal;
  final nutritionDays = {
    if (nutrition.loaded)
      for (final record in nutrition.loadedDays)
        if (!record.isEmpty || (waterGoal > 0 && record.waterMl >= waterGoal))
          record.date,
  };
  final days = {
    ...progress.trainedDays,
    ...schedule.scheduledDays,
    ...nutritionDays,
  };
  return {
    for (final day in days)
      day: () {
        final sessions = progress.sessionsOn(day);
        final planned = schedule.forDay(day);
        return DayMarkers(
          trained: sessions.isNotEmpty,
          scheduled: planned.length,
          scheduledDone: planned.where((p) => p.isCompletedBy(sessions)).length,
          nutrition: nutritionDays.contains(day),
        );
      }(),
  };
}

/// Semana (lunes a domingo) en una franja de 7 días con las mismas marcas
/// que el calendario mensual (entrenado, programado, completado y
/// alimentación). Se cambia de semana con las flechas o deslizando.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.week,
    required this.selectedDay,
    required this.onDaySelected,
    this.onWeekChanged,
    this.markers = const {},
    this.showLegend = false,
  });

  /// Muestra debajo qué significa cada marca.
  final bool showLegend;

  /// Cualquier día de la semana que se muestra.
  final DateTime week;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Recibe el lunes de la nueva semana. Sin él, la semana es fija (sin
  /// flechas ni deslizamiento).
  final ValueChanged<DateTime>? onWeekChanged;

  /// Marcas por día (claves a medianoche).
  final Map<DateTime, DayMarkers> markers;

  /// Lunes (a medianoche) de la semana de [date].
  static DateTime mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// "6 – 12 oct" o, si cambia de mes, "29 sept – 5 oct".
  static String rangeLabel(DateTime monday) {
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final end = DateFormat('d MMM', 'es').format(sunday);
    final start = monday.month == sunday.month
        ? '${monday.day}'
        : DateFormat('d MMM', 'es').format(monday);
    return '$start – $end';
  }

  void _shift(int weeks) {
    final monday = mondayOf(week);
    onWeekChanged?.call(
      DateTime(monday.year, monday.month, monday.day + 7 * weeks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final monday = mondayOf(week);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];

    return GestureDetector(
      // Deslizar a la izquierda: semana siguiente.
      onHorizontalDragEnd: onWeekChanged == null
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200) _shift(1);
              if (velocity > 200) _shift(-1);
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rangeLabel(monday),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (onWeekChanged != null) ...[
                IconButton(
                  tooltip: 'Semana anterior',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shift(-1),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shift(1),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _DayTile(
                    day: day,
                    selected: MonthCalendar.sameDay(day, selectedDay),
                    today: day == today,
                    markers: markers[day] ?? const DayMarkers(),
                    onTap: () => onDaySelected(day),
                  ),
                ),
            ],
          ),
          if (showLegend) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                const _Legend(color: AppColors.primary, label: 'Entrenado'),
                const _Legend(
                  color: AppColors.teal,
                  label: 'Programado',
                  ring: true,
                ),
                const _Legend(color: AppColors.success, label: 'Completado'),
                if (markers.values.any((m) => m.nutrition))
                  const _Legend(color: AppColors.violet, label: 'Alimentación'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.selected,
    required this.today,
    required this.markers,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final DayMarkers markers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final weekday = AppConstants.weekDays[day.weekday - 1];
    final Color background = selected
        ? AppColors.primary
        : markers.trained
        ? palette.primarySoft
        : palette.surfaceMuted;
    final Color foreground = selected
        ? AppColors.onPrimary
        : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$weekday ${day.day}',
        child: Material(
          color: background,
          shape: BeveledRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            side: today && !selected
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    // "Miércoles" → "X", como en los calendarios en español.
                    day.weekday == DateTime.wednesday ? 'X' : weekday[0],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.onPrimary.withValues(alpha: 0.8)
                          : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (markers.trained)
                            _dot(selected ? foreground : AppColors.primary),
                          if (markers.scheduledDone > 0)
                            _dot(selected ? foreground : AppColors.success),
                          if (markers.hasPending)
                            _dot(
                              selected ? foreground : AppColors.teal,
                              ring: true,
                            ),
                          if (markers.nutrition)
                            _dot(selected ? foreground : AppColors.violet),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, {bool ring = false}) => Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: ring ? Colors.transparent : color,
      border: ring ? Border.all(color: color, width: 1.4) : null,
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.ring = false});

  final Color color;
  final String label;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ring ? Colors.transparent : color,
            border: ring ? Border.all(color: color, width: 1.6) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
        ),
      ],
    );
  }
}
