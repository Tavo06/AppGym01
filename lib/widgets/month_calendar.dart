import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

/// Marcas de un día del calendario.
class DayMarkers {
  const DayMarkers({
    this.trained = false,
    this.scheduled = 0,
    this.scheduledDone = 0,
  });

  /// Hubo al menos una sesión ese día.
  final bool trained;

  /// Entrenamientos programados ese día y cuántos se completaron.
  final int scheduled;
  final int scheduledDone;

  bool get hasPending => scheduled > scheduledDone;
}

/// Calendario mensual (lunes a domingo) con indicadores por día.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onMonthChanged,
    this.markers = const {},
  });

  /// Cualquier fecha del mes que se muestra.
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  /// Marcas por día (claves a medianoche).
  final Map<DateTime, DayMarkers> markers;

  static const List<String> monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Huecos antes del día 1 (lunes = 0).
    final leading = first.weekday - DateTime.monday;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final name in AppConstants.weekDays)
              Expanded(
                child: Center(
                  child: Text(
                    // L M X J V S D (miércoles con X, como es habitual).
                    name == 'Miércoles' ? 'X' : name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final dayNumber = row * 7 + col - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const AspectRatio(aspectRatio: 1);
                      }
                      final date = DateTime(month.year, month.month, dayNumber);
                      return _DayCell(
                        date: date,
                        selected: sameDay(date, selectedDay),
                        today: sameDay(date, today),
                        markers: markers[date] ?? const DayMarkers(),
                        onTap: () => onDaySelected(date),
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: const [
            _Legend(color: AppColors.primary, label: 'Entrenado'),
            _Legend(color: AppColors.teal, label: 'Programado', ring: true),
            _Legend(color: AppColors.success, label: 'Completado'),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.markers,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final DayMarkers markers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color background;
    if (selected) {
      background = AppColors.primary;
    } else if (markers.trained) {
      background = palette.primarySoft;
    } else {
      background = Colors.transparent;
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: today && !selected
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: today || selected || markers.trained
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: selected ? AppColors.onPrimary : palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (markers.trained)
                        _Dot(
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.primary,
                        ),
                      if (markers.scheduledDone > 0)
                        _Dot(
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.success,
                        ),
                      if (markers.hasPending)
                        _Dot(
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.teal,
                          ring: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.ring = false});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? Colors.transparent : color,
        border: ring ? Border.all(color: color, width: 1.6) : null,
      ),
    );
  }
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
        _Dot(color: color, ring: ring),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
        ),
      ],
    );
  }
}
