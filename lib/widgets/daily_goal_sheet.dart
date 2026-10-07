import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/nutrition_catalog.dart';
import '../core/theme/app_theme.dart';
import '../models/nutrition_model.dart';
import 'custom_button.dart';

/// Objetivo diario elegido en [showDailyGoalSheet].
typedef DailyGoal = ({
  String goal,
  double calories,
  double protein,
  double carbs,
  double fat,
  String templateId,
});

/// Hoja "Tu objetivo diario": un punto de partida (las plantillas de
/// siempre o personalizado) y las kcal y la proteína, editables. Sin plan
/// actual, se preselecciona la plantilla que encaja con [profileGoal].
Future<DailyGoal?> showDailyGoalSheet(
  BuildContext context, {
  NutritionPlan? current,
  String? profileGoal,
}) {
  return showModalBottomSheet<DailyGoal>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _DailyGoalSheet(current: current, profileGoal: profileGoal),
  );
}

class _DailyGoalSheet extends StatefulWidget {
  const _DailyGoalSheet({this.current, this.profileGoal});

  final NutritionPlan? current;
  final String? profileGoal;

  @override
  State<_DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends State<_DailyGoalSheet> {
  static const double _minKcal = 800;
  static const double _maxKcal = 6000;
  static const double _maxProtein = 400;

  /// Plantilla elegida; `null` = personalizado.
  NutritionTemplate? _template;
  NutritionTemplate? _suggested;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _suggested = NutritionTemplate.forProfileGoal(widget.profileGoal);
    _template = current != null
        ? NutritionTemplate.byId(current.templateId)
        : _suggested;
    final kcal = current?.calories ?? _template?.calories ?? 2000;
    final protein = current?.protein ?? _template?.protein ?? 120;
    _kcal = TextEditingController(text: '${kcal.round()}');
    _protein = TextEditingController(text: '${protein.round()}');
  }

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    super.dispose();
  }

  void _choose(NutritionTemplate? template) {
    setState(() {
      _template = template;
      _error = null;
      if (template != null) {
        _kcal.text = '${template.calories.round()}';
        _protein.text = '${template.protein.round()}';
      }
    });
  }

  void _save() {
    final kcal = double.tryParse(_kcal.text.trim());
    final protein = double.tryParse(_protein.text.trim());
    if (kcal == null || kcal < _minKcal || kcal > _maxKcal) {
      setState(
        () => _error =
            'Las calorías deben estar entre ${_minKcal.round()} y '
            '${_maxKcal.round()}.',
      );
      return;
    }
    if (protein == null || protein < 0 || protein > _maxProtein) {
      setState(
        () => _error =
            'La proteína debe estar entre 0 y ${_maxProtein.round()} g.',
      );
      return;
    }
    final template = _template;
    Navigator.of(context).pop<DailyGoal>((
      goal: template?.goal ?? NutritionGoals.custom,
      calories: kcal,
      protein: protein,
      // Carbohidratos y grasas no se editan aquí: los de la plantilla o los
      // que ya tuviera el plan.
      carbs: template?.carbs ?? widget.current?.carbs ?? 0,
      fat: template?.fat ?? widget.current?.fat ?? 0,
      templateId: template?.id ?? '',
    ));
  }

  Widget _field(TextEditingController controller, String label, String unit) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: unit),
      onChanged: (_) => setState(() => _error = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final suggested = _suggested;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tu objetivo diario',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige un punto de partida y ajústalo. Son valores orientativos, '
              'no una recomendación médica.',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in NutritionTemplate.all)
                  ChoiceChip(
                    label: Text(template.goal),
                    selected: _template?.id == template.id,
                    onSelected: (_) => _choose(template),
                  ),
                ChoiceChip(
                  label: const Text(NutritionGoals.custom),
                  selected: _template == null,
                  onSelected: (_) => _choose(null),
                ),
              ],
            ),
            if (suggested != null && widget.profileGoal != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sugerido para tu objetivo (${widget.profileGoal}): '
                      '${suggested.goal}.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _field(_kcal, 'Calorías', 'kcal')),
                const SizedBox(width: 12),
                Expanded(child: _field(_protein, 'Proteína', 'g')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            CustomButton(
              label: 'Guardar objetivo',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
