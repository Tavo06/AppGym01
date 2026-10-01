import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../models/nutrition_model.dart';
import '../../providers/nutrition_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/responsive.dart';

/// Crear mi plan (`/alimentacion/plan/nuevo`) o editar sus datos generales
/// si llega un [plan] (por `extra`).
class NutritionPlanFormScreen extends StatefulWidget {
  const NutritionPlanFormScreen({super.key, this.plan});

  final NutritionPlan? plan;

  @override
  State<NutritionPlanFormScreen> createState() =>
      _NutritionPlanFormScreenState();
}

class _NutritionPlanFormScreenState extends State<NutritionPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String _goal = NutritionGoals.custom;
  bool _saving = false;

  bool get _editing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _name.text = plan.name;
      _goal = NutritionGoals.all.contains(plan.goal)
          ? plan.goal
          : NutritionGoals.custom;
      _calories.text = _num(plan.calories);
      _protein.text = _num(plan.protein);
      _carbs.text = _num(plan.carbs);
      _fat.text = _num(plan.fat);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  static double? _parse(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  String? _validateCalories(String? v) {
    final value = _parse(v);
    if (value == null) return 'Ingresa las calorías diarias.';
    if (value <= 0) return 'Las calorías deben ser mayores que 0.';
    return null;
  }

  String? _validateMacro(String? v) {
    final value = _parse(v);
    if (value == null) return 'Ingresa un número.';
    if (value < 0) return 'No puede ser negativo.';
    if (value > 2000) return 'Revisa este valor.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<NutritionProvider>();
    setState(() => _saving = true);
    try {
      await provider.ensureLoaded();
      final calories = _parse(_calories.text)!;
      final protein = _parse(_protein.text)!;
      final carbs = _parse(_carbs.text)!;
      final fat = _parse(_fat.text)!;
      final existing = widget.plan;
      if (existing == null) {
        final plan = await provider.createPlan(
          name: _name.text,
          goal: _goal,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
        if (!mounted) return;
        showAppMessage(
          context,
          'Plan creado correctamente.',
          type: FeedbackType.success,
        );
        // Tras crearlo se pasa a agregar sus comidas.
        context.pushReplacement('/alimentacion/plan/${plan.id}');
      } else {
        await provider.updatePlan(
          existing.copyWith(
            name: _name.text.trim(),
            goal: _goal,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
          ),
        );
        if (!mounted) return;
        showAppMessage(
          context,
          'Plan actualizado.',
          type: FeedbackType.success,
        );
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo guardar el plan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator,
  ) {
    return CustomTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar plan' : 'Crear mi plan')),
      body: FormScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section('Información del plan'),
              CustomTextField(
                controller: _name,
                label: 'Nombre del plan',
                hint: 'Ej: Mi plan de volumen',
                icon: Icons.restaurant_menu_rounded,
                validator: (v) => Validators.validateRequired(
                  v,
                  message: 'Ingresa el nombre del plan.',
                ),
              ),
              const SizedBox(height: 14),
              CustomDropdown(
                items: NutritionGoals.all,
                value: _goal,
                label: 'Objetivo',
                icon: Icons.flag_outlined,
                onChanged: (v) =>
                    setState(() => _goal = v ?? NutritionGoals.custom),
                validator: (_) => null,
              ),
              const SizedBox(height: 24),
              section('Objetivos diarios'),
              _numberField(
                _calories,
                'Calorías (kcal)',
                Icons.local_fire_department_outlined,
                _validateCalories,
              ),
              const SizedBox(height: 14),
              _numberField(
                _protein,
                'Proteínas (g)',
                Icons.egg_alt_outlined,
                _validateMacro,
              ),
              const SizedBox(height: 14),
              _numberField(
                _carbs,
                'Carbohidratos (g)',
                Icons.bakery_dining_outlined,
                _validateMacro,
              ),
              const SizedBox(height: 14),
              _numberField(
                _fat,
                'Grasas (g)',
                Icons.water_drop_outlined,
                _validateMacro,
              ),
              const SizedBox(height: 10),
              Text(
                'Define tus propios valores de referencia. No sustituyen el '
                'consejo de un profesional de la salud.',
                style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: _editing ? 'Guardar cambios' : 'Crear plan',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
