import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/nutrition_model.dart';
import '../providers/nutrition_provider.dart';

/// Colores de los macronutrientes (de la paleta de la app).
abstract final class MacroColors {
  static const Color protein = AppColors.violet;
  static const Color carbs = AppColors.amber;
  static const Color fat = AppColors.teal;
}

/// Consumo frente a objetivos: barra de calorías y tres indicadores de
/// macronutrientes (proteínas, carbohidratos y grasas).
class NutritionProgressPanel extends StatelessWidget {
  const NutritionProgressPanel({
    super.key,
    required this.consumed,
    required this.targets,
    this.consumedLabel = 'consumidas',
  });

  final NutritionTotals consumed;
  final NutritionTotals targets;
  final String consumedLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ratio = NutritionProvider.progress(consumed.kcal, targets.kcal);
    final percent = targets.kcal <= 0
        ? 0
        : (consumed.kcal / targets.kcal * 100).round();
    final over = targets.kcal > 0 && consumed.kcal > targets.kcal * 1.1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: Formatters.formatNumber(consumed.kcal.round()),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' / ${Formatters.formatNumber(targets.kcal.round())} '
                          'kcal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              '$percent %',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: over ? AppColors.error : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: over ? AppColors.error : AppColors.primary,
            backgroundColor: palette.surfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          targets.kcal <= 0
              ? 'Calorías $consumedLabel'
              : consumed.kcal >= targets.kcal
              ? 'Objetivo de calorías alcanzado'
              : 'Faltan '
                    '${Formatters.formatNumber((targets.kcal - consumed.kcal).round())} '
                    'kcal',
          style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MacroRing(
                label: 'Proteínas',
                value: consumed.protein,
                target: targets.protein,
                color: MacroColors.protein,
              ),
            ),
            Expanded(
              child: MacroRing(
                label: 'Carbohidratos',
                value: consumed.carbs,
                target: targets.carbs,
                color: MacroColors.carbs,
              ),
            ),
            Expanded(
              child: MacroRing(
                label: 'Grasas',
                value: consumed.fat,
                target: targets.fat,
                color: MacroColors.fat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Indicador circular de un macronutriente: "120 / 160 g".
class MacroRing extends StatelessWidget {
  const MacroRing({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: NutritionProvider.progress(value, target),
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: palette.surfaceMuted,
                ),
              ),
              Text(
                target <= 0
                    ? '–'
                    : '${(value / target * 100).round().clamp(0, 999)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        Text(
          '${Formatters.formatNumber(value.round())} / '
          '${Formatters.formatNumber(target.round())} g',
          style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// Línea compacta "520 kcal · P 30 g · C 60 g · G 15 g".
class MacroSummaryText extends StatelessWidget {
  const MacroSummaryText(this.totals, {super.key, this.style});

  final NutritionTotals totals;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${Formatters.formatNumber(totals.kcal.round())} kcal · '
      'P ${Formatters.formatNumber(totals.protein.round())} g · '
      'C ${Formatters.formatNumber(totals.carbs.round())} g · '
      'G ${Formatters.formatNumber(totals.fat.round())} g',
      style:
          style ??
          TextStyle(fontSize: 12.5, color: context.palette.textSecondary),
    );
  }
}
