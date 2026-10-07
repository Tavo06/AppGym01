import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/nutrition_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/nutrition_progress_panel.dart';

/// Planes predeterminados (`/alimentacion/plantillas`). "Usar este plan"
/// crea una copia editable para el usuario.
class NutritionTemplatesScreen extends StatefulWidget {
  const NutritionTemplatesScreen({super.key});

  @override
  State<NutritionTemplatesScreen> createState() =>
      _NutritionTemplatesScreenState();
}

class _NutritionTemplatesScreenState extends State<NutritionTemplatesScreen> {
  String? _saving;

  Future<void> _use(NutritionTemplate template) async {
    final provider = context.read<NutritionProvider>();
    setState(() => _saving = template.id);
    try {
      await provider.ensureLoaded();
      final plan = await provider.useTemplate(template);
      if (!mounted) return;
      showAppMessage(
        context,
        'Plan creado correctamente.',
        type: FeedbackType.success,
      );
      // Se reemplaza esta pantalla por el plan recién creado.
      context.pushReplacement('/alimentacion/plan/${plan.id}');
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo crear el plan.');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // La plantilla que encaja con el objetivo del perfil va primero.
    final goal = context.watch<AuthProvider>().profile?.goal;
    final suggested = NutritionTemplate.forProfileGoal(goal);
    final templates = [
      ?suggested,
      for (final template in NutritionTemplate.all)
        if (template.id != suggested?.id) template,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Planes predeterminados')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Estas plantillas son ejemplos orientativos, no '
                            'recomendaciones médicas ni nutricionales '
                            'personalizadas. Al usar una se crea tu propia '
                            'copia, que puedes ajustar libremente.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 2 : 1;
                      final width =
                          (constraints.maxWidth - 16 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final template in templates)
                            SizedBox(
                              width: width,
                              child: _TemplateCard(
                                template: template,
                                suggestedFor: template.id == suggested?.id
                                    ? goal
                                    : null,
                                saving: _saving == template.id,
                                onUse: _saving == null
                                    ? () => _use(template)
                                    : null,
                              ),
                            ),
                        ],
                      );
                    },
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.saving,
    required this.onUse,
    this.suggestedFor,
  });

  final NutritionTemplate template;
  final bool saving;
  final VoidCallback? onUse;

  /// Objetivo del perfil para el que se sugiere esta plantilla.
  final String? suggestedFor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      shape: suggestedFor == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (suggestedFor != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _Macro(
                  'Sugerida para tu objetivo: $suggestedFor',
                  AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              template.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              template.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Macro(
                  '${Formatters.formatNumber(template.calories.round())} kcal',
                  AppColors.primary,
                ),
                _Macro('P ${template.protein.round()} g', MacroColors.protein),
                _Macro('C ${template.carbs.round()} g', MacroColors.carbs),
                _Macro('G ${template.fat.round()} g', MacroColors.fat),
              ],
            ),
            const SizedBox(height: 12),
            for (final meal in template.meals.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${meal.key.label}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: meal.value.map((f) => f.$1).join(', '),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onUse,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy_rounded),
              label: const Text('Usar este plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
