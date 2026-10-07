import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/nutrition_model.dart';
import '../providers/nutrition_provider.dart';
import 'water_tracker_card.dart';

/// Calorías y agua de un día frente al plan activo y la meta de agua (en el
/// Calendario y en la tarjeta "Hoy" del Panel).
class DayNutritionSummary extends StatelessWidget {
  const DayNutritionSummary({
    super.key,
    required this.record,
    required this.calorieTarget,
    required this.waterGoal,
    this.onAddWater,
  });

  final DailyNutritionRecord record;

  /// kcal del plan activo (0 si no hay): sin objetivo no se muestra barra.
  final double calorieTarget;
  final int waterGoal;

  /// Si se indica, aparece un botón para sumar un vaso de agua.
  final VoidCallback? onAddWater;

  @override
  Widget build(BuildContext context) {
    final kcal = record.totals.kcal;
    final glass = AppConstants.waterPresets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.primary,
          label: calorieTarget > 0
              ? '${Formatters.formatNumber(kcal.round())} / '
                    '${Formatters.formatNumber(calorieTarget.round())} kcal'
              : '${Formatters.formatNumber(kcal.round())} kcal',
          progress: calorieTarget > 0
              ? NutritionProvider.progress(kcal, calorieTarget)
              : null,
        ),
        const SizedBox(height: 10),
        _Line(
          icon: Icons.water_drop_rounded,
          color: WaterTrackerCard.color,
          label:
              '${Formatters.formatWater(record.waterMl)} / '
              '${Formatters.formatWater(waterGoal)} de agua',
          progress: NutritionProvider.progress(
            record.waterMl.toDouble(),
            waterGoal.toDouble(),
          ),
          trailing: onAddWater == null
              ? null
              : IconButton(
                  tooltip: 'Sumar ${Formatters.formatWater(glass)}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: WaterTrackerCard.color,
                  ),
                  onPressed: onAddWater,
                ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.label,
    this.progress,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: color,
                    backgroundColor: palette.surfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
