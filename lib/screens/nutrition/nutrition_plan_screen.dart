import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/nutrition_model.dart';
import '../../providers/nutrition_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/food_form_sheet.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/nutrition_progress_panel.dart';

/// Detalle y edición de un plan (`/alimentacion/plan/:id`): objetivos,
/// comidas y alimentos.
class NutritionPlanScreen extends StatefulWidget {
  const NutritionPlanScreen({super.key, required this.planId});

  final String planId;

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NutritionProvider>().ensureLoaded();
    });
  }

  NutritionProvider get _provider => context.read<NutritionProvider>();

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      showAppMessage(context, success, type: FeedbackType.success);
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo guardar el cambio.');
    }
  }

  Future<void> _editMeal(NutritionPlan plan, [NutritionMeal? meal]) async {
    final result = await showDialog<NutritionMeal>(
      context: context,
      builder: (_) => _MealDialog(meal: meal),
    );
    if (result == null || !mounted) return;
    await _run(
      () => _provider.saveMeal(plan.id, result),
      meal == null ? 'Comida agregada.' : 'Plan actualizado.',
    );
  }

  Future<void> _deleteMeal(NutritionPlan plan, NutritionMeal meal) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar "${meal.name}"?',
      message: 'Se quitarán también sus ${meal.foods.length} alimentos.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _provider.deleteMeal(plan.id, meal.id),
      'Comida eliminada.',
    );
  }

  Future<void> _editFood(
    NutritionPlan plan,
    NutritionMeal meal, [
    FoodItem? food,
  ]) async {
    final result = await showFoodFormSheet(
      context,
      initial: food,
      meal: meal.type,
    );
    if (result == null || !mounted) return;
    await _run(
      () => _provider.saveFood(plan.id, meal.id, result.food),
      food == null ? 'Alimento agregado.' : 'Plan actualizado.',
    );
  }

  Future<void> _deleteFood(
    NutritionPlan plan,
    NutritionMeal meal,
    FoodItem food,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar "${food.name}"?',
      message: 'Se quitará de ${meal.name}.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _provider.deleteFood(plan.id, meal.id, food.id),
      'Alimento eliminado.',
    );
  }

  Future<void> _deletePlan(NutritionPlan plan) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_forever_outlined,
      title: '¿Eliminar "${plan.name}"?',
      message:
          'Se eliminarán el plan y sus comidas. Tus registros diarios se '
          'conservan.',
      confirmLabel: 'Eliminar plan',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await _provider.deletePlan(plan.id);
      if (!mounted) return;
      showAppMessage(context, 'Plan eliminado.', type: FeedbackType.success);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo eliminar el plan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionProvider>(
      builder: (context, nutrition, _) {
        final plan = nutrition.planById(widget.planId);
        if (plan == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Plan')),
            body: nutrition.loaded
                ? const EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'No se encontró el plan',
                    subtitle: 'Puede que se haya eliminado.',
                  )
                : nutrition.error != null
                ? ErrorState(message: nutrition.error!, onRetry: nutrition.load)
                : const LoadingWidget(message: 'Cargando plan...'),
          );
        }
        final summary = _PlanSummary(
          plan: plan,
          onActivate: plan.active
              ? null
              : () => _run(
                  () => _provider.setActivePlan(plan.id),
                  'Plan actualizado.',
                ),
        );
        final meals = _MealsList(
          plan: plan,
          onAddMeal: () => _editMeal(plan),
          onEditMeal: (meal) => _editMeal(plan, meal),
          onDeleteMeal: (meal) => _deleteMeal(plan, meal),
          onAddFood: (meal) => _editFood(plan, meal),
          onEditFood: (meal, food) => _editFood(plan, meal, food),
          onDeleteFood: (meal, food) => _deleteFood(plan, meal, food),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(plan.name),
            actions: [
              IconButton(
                tooltip: 'Editar datos del plan',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/alimentacion/plan/nuevo', extra: plan),
              ),
              IconButton(
                tooltip: 'Eliminar plan',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _deletePlan(plan),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16,
                  8,
                  wide ? 24 : 16,
                  28,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 400, child: summary),
                                const SizedBox(width: 20),
                                Expanded(child: meals),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                summary,
                                const SizedBox(height: 16),
                                meals,
                              ],
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, required this.onActivate});

  final NutritionPlan plan;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.goal,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (plan.active)
                  Chip(
                    avatar: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                    label: const Text('Plan activo'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: onActivate,
                    child: const Text('Usar como plan activo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Objetivos diarios',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            MacroSummaryText(
              plan.targets,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LO PLANIFICADO EN TUS COMIDAS',
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            NutritionProgressPanel(
              consumed: plan.plannedTotals,
              targets: plan.targets,
              consumedLabel: 'planificadas',
            ),
          ],
        ),
      ),
    );
  }
}

class _MealsList extends StatelessWidget {
  const _MealsList({
    required this.plan,
    required this.onAddMeal,
    required this.onEditMeal,
    required this.onDeleteMeal,
    required this.onAddFood,
    required this.onEditFood,
    required this.onDeleteFood,
  });

  final NutritionPlan plan;
  final VoidCallback onAddMeal;
  final ValueChanged<NutritionMeal> onEditMeal;
  final ValueChanged<NutritionMeal> onDeleteMeal;
  final ValueChanged<NutritionMeal> onAddFood;
  final void Function(NutritionMeal, FoodItem) onEditFood;
  final void Function(NutritionMeal, FoodItem) onDeleteFood;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comidas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onAddMeal,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar comida'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (plan.meals.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Aún no hay comidas. Agrega el desayuno, el almuerzo o la '
              'comida que quieras planificar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
        for (final meal in plan.meals)
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              [
                                if (meal.name != meal.type.label)
                                  meal.type.label,
                                if (meal.time.isNotEmpty) meal.time,
                                '${meal.foods.length} alimentos',
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Opciones de la comida',
                        onSelected: (value) {
                          if (value == 'edit') onEditMeal(meal);
                          if (value == 'delete') onDeleteMeal(meal);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar comida'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar comida',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  for (final food in meal.foods)
                    FoodRow(
                      food: food,
                      onEdit: () => onEditFood(meal, food),
                      onDelete: () => onDeleteFood(meal, food),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total: '
                            '${Formatters.formatNumber(meal.totals.kcal.round())} kcal · '
                            'P ${meal.totals.protein.round()} · '
                            'C ${meal.totals.carbs.round()} · '
                            'G ${meal.totals.fat.round()}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => onAddFood(meal),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Alimento'),
                        ),
                      ],
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

/// Diálogo para crear o editar una comida: categoría, nombre y horario.
class _MealDialog extends StatefulWidget {
  const _MealDialog({this.meal});

  final NutritionMeal? meal;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  late MealType _type = widget.meal?.type ?? MealType.breakfast;
  late final TextEditingController _name = TextEditingController(
    text: widget.meal?.name ?? '',
  );
  late final TextEditingController _time = TextEditingController(
    text: widget.meal?.time ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  void _save() {
    final existing = widget.meal;
    final name = _name.text.trim();
    final meal = existing == null
        ? NutritionMeal(type: _type, name: name, time: _time.text)
        : existing.copyWith(
            type: _type,
            name: name.isEmpty ? _type.label : name,
            time: _time.text,
          );
    Navigator.of(context).pop(meal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.meal == null ? 'Agregar comida' : 'Editar comida'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<MealType>(
              initialValue: _type,
              // Ocupa el ancho del diálogo: en móvil "Media mañana" no cabía.
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final type in MealType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: _type.label,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _time,
              readOnly: true,
              onTap: _pickTime,
              decoration: InputDecoration(
                labelText: 'Horario (opcional)',
                prefixIcon: const Icon(Icons.schedule_rounded),
                suffixIcon: _time.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Quitar horario',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_time.clear),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.meal == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}
