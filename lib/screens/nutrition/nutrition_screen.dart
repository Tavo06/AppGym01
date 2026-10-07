import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/nutrition_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/nutrition_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/daily_goal_sheet.dart';
import '../../widgets/error_state.dart';
import '../../widgets/food_form_sheet.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/nutrition_progress_panel.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/water_tracker_card.dart';

/// Comida (`/alimentacion`): objetivo diario (kcal y proteína), agua,
/// registro de hoy por comida y progreso de la semana.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NutritionProvider>().ensureLoaded();
    });
  }

  Future<void> _logFood([MealType meal = MealType.breakfast]) async {
    final provider = context.read<NutritionProvider>();
    final result = await showFoodFormSheet(
      context,
      meal: meal,
      chooseMeal: true,
      title: 'Registrar alimento',
      submitLabel: 'Registrar',
    );
    if (result == null || !mounted) return;
    try {
      await provider.logFood(result.meal, result.food);
      if (!mounted) return;
      showAppMessage(context, 'Alimento agregado.', type: FeedbackType.success);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo registrar el alimento.');
    }
  }

  Future<void> _removeEntry(FoodEntry entry) async {
    final provider = context.read<NutritionProvider>();
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Eliminar registro?',
      message: '"${entry.food.name}" dejará de contar en tu consumo de hoy.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await provider.removeEntry(entry.id);
      if (!mounted) return;
      showAppMessage(
        context,
        'Registro eliminado.',
        type: FeedbackType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo eliminar el registro.');
    }
  }

  /// Define o cambia el objetivo diario (kcal y proteína).
  Future<void> _editGoal() async {
    final provider = context.read<NutritionProvider>();
    final result = await showDailyGoalSheet(
      context,
      current: provider.activePlan,
      profileGoal: context.read<AuthProvider>().profile?.goal,
    );
    if (result == null || !mounted) return;
    try {
      await provider.setDailyGoal(
        goal: result.goal,
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        templateId: result.templateId,
      );
      if (!mounted) return;
      showAppMessage(context, 'Objetivo guardado.', type: FeedbackType.success);
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo guardar el objetivo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comida'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Etiqueta propia: hay varios FAB en el IndexedStack de pestañas.
        heroTag: 'fab-alimentacion',
        onPressed: _logFood,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar alimento'),
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          if (!nutrition.loaded) {
            if (nutrition.error != null) {
              return ErrorState(
                message: nutrition.error!,
                onRetry: nutrition.load,
              );
            }
            // Sin datos, sin carga en curso y sin error (p. ej. una carga
            // anterior quedó interrumpida): se vuelve a pedir en lugar de
            // quedarse cargando para siempre.
            if (!nutrition.loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) nutrition.ensureLoaded();
              });
            }
            return const LoadingWidget(message: 'Cargando tu alimentación...');
          }
          final active = nutrition.activePlan;
          final goalCard = _GoalCard(
            plan: active,
            consumed: nutrition.today.totals,
            onEdit: _editGoal,
          );
          final todayCard = _TodayLog(
            record: nutrition.today,
            onAdd: _logFood,
            onRemove: _removeEntry,
          );
          final statsCard = _NutritionStatsCard(
            stats: nutrition.statsForLast(7),
            water: nutrition.waterStatsForLast(7),
            week: nutrition.thisWeek,
            target: active?.calories ?? 0,
          );
          const waterCard = WaterTrackerCard();

          return RefreshIndicator(
            onRefresh: nutrition.load,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    wide ? 24 : 16,
                    8,
                    wide ? 24 : 16,
                    96,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        // Orden: primero las comidas (lo que más se usa);
                        // después el objetivo, el agua y la semana.
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: todayCard),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        goalCard,
                                        const SizedBox(height: 16),
                                        waterCard,
                                        const SizedBox(height: 16),
                                        statsCard,
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  todayCard,
                                  const SizedBox(height: 22),
                                  goalCard,
                                  const SizedBox(height: 16),
                                  waterCard,
                                  const SizedBox(height: 16),
                                  statsCard,
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

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
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Objetivo diario: anillo de calorías, lo que queda y la proteína. Sin
/// objetivo, invita a definirlo (con la sugerencia del perfil).
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.plan,
    required this.consumed,
    required this.onEdit,
  });

  final NutritionPlan? plan;
  final NutritionTotals consumed;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = this.plan;
    if (plan == null || plan.calories <= 0) {
      final goal = context.watch<AuthProvider>().profile?.goal;
      final suggested = NutritionTemplate.forProfileGoal(goal);
      return _SectionCard(
        title: 'Define tu objetivo diario',
        subtitle: 'Cuántas calorías y cuánta proteína quieres comer al día.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (suggested != null) ...[
              Text(
                'Para tu objetivo ($goal) te sugerimos empezar con '
                '"${suggested.goal}".',
                style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
              ),
              const SizedBox(height: 14),
            ],
            CustomButton(
              label: 'Definir objetivo',
              icon: Icons.flag_rounded,
              onPressed: onEdit,
            ),
          ],
        ),
      );
    }

    final remaining = plan.calories - consumed.kcal;
    final over = remaining < 0;
    return _SectionCard(
      title: 'Objetivo de hoy',
      trailing: IconButton(
        tooltip: 'Editar objetivo',
        icon: const Icon(Icons.tune_rounded),
        onPressed: onEdit,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: NutritionProvider.progress(
                      consumed.kcal,
                      plan.calories,
                    ),
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: over ? AppColors.error : AppColors.primary,
                    backgroundColor: palette.surfaceMuted,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatNumber(consumed.kcal.round()),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      'de ${Formatters.formatNumber(plan.calories.round())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Pill(icon: Icons.flag_rounded, label: plan.goal),
                const SizedBox(height: 10),
                Text(
                  over
                      ? 'Te pasaste por '
                            '${Formatters.formatNumber((-remaining).round())} '
                            'kcal'
                      : 'Te quedan '
                            '${Formatters.formatNumber(remaining.round())} kcal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: over ? AppColors.error : palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Proteína ${Formatters.formatNumber(consumed.protein.round())}'
                  ' / ${Formatters.formatNumber(plan.protein.round())} g',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: NutritionProvider.progress(
                      consumed.protein,
                      plan.protein,
                    ),
                    minHeight: 8,
                    color: MacroColors.protein,
                    backgroundColor: palette.surfaceMuted,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.palette.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          // Flexible: objetivos largos se recortan en pantallas estrechas.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.palette.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comidas de hoy: una tarjeta por comida (desayuno, almuerzo y cena) con su
/// color, sus alimentos y "Añadir". Los registros de comidas antiguas
/// (media mañana, merienda, snack) se muestran en la más cercana.
class _TodayLog extends StatelessWidget {
  const _TodayLog({
    required this.record,
    required this.onAdd,
    required this.onRemove,
  });

  final DailyNutritionRecord record;
  final ValueChanged<MealType> onAdd;
  final ValueChanged<FoodEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Tus comidas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Text(
              record.isEmpty
                  ? 'Nada registrado'
                  : '${Formatters.formatNumber(record.totals.kcal.round())} '
                        'kcal hoy',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: record.isEmpty
                    ? palette.textSecondary
                    : palette.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final meal in MealType.daily) ...[
          _MealCard(
            meal: meal,
            entries: record.entriesInGroup(meal),
            kcal: record.totalsInGroup(meal).kcal,
            onAdd: () => onAdd(meal),
            onRemove: onRemove,
          ),
          if (meal != MealType.daily.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Aspecto de cada comida: icono, color y franja del día.
({IconData icon, Color color, String moment}) _mealStyle(MealType meal) =>
    switch (meal) {
      MealType.breakfast => (
        icon: Icons.wb_twilight_rounded,
        color: AppColors.amber,
        moment: 'Mañana',
      ),
      MealType.lunch => (
        icon: Icons.lunch_dining_rounded,
        color: AppColors.primary,
        moment: 'Mediodía',
      ),
      _ => (
        icon: Icons.nights_stay_rounded,
        color: AppColors.violet,
        moment: 'Noche',
      ),
    };

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.entries,
    required this.kcal,
    required this.onAdd,
    required this.onRemove,
  });

  final MealType meal;
  final List<FoodEntry> entries;
  final double kcal;
  final VoidCallback onAdd;
  final ValueChanged<FoodEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = _mealStyle(meal);
    final done = entries.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Franja de color de la comida.
            Container(width: 6, color: style.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: ShapeDecoration(
                            color: style.color.withValues(alpha: 0.15),
                            shape: AppShapes.small,
                          ),
                          child: Icon(style.icon, color: style.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                done
                                    ? '${style.moment} · '
                                          '${Formatters.formatNumber(kcal.round())} kcal'
                                    : '${style.moment} · sin registrar',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: onAdd,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: AppShapes.small,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Añadir',
                            semanticsLabel: 'Registrar en ${meal.label}',
                          ),
                        ),
                      ],
                    ),
                    if (done) ...[
                      const SizedBox(height: 6),
                      for (final entry in entries)
                        FoodRow(
                          food: entry.food,
                          leading: Icon(
                            Icons.check_circle_rounded,
                            color: style.color,
                          ),
                          onDelete: () => onRemove(entry),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progreso nutricional: promedios de los últimos 7 días y semana actual.
class _NutritionStatsCard extends StatelessWidget {
  const _NutritionStatsCard({
    required this.stats,
    required this.water,
    required this.week,
    required this.target,
  });

  final NutritionStats stats;
  final WaterStats water;
  final List<DailyNutritionRecord> week;
  final double target;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxKcal = week.fold<double>(
      target,
      (m, r) => r.totals.kcal > m ? r.totals.kcal : m,
    );
    final today = DateTime.now();
    return _SectionCard(
      title: 'Tu semana',
      subtitle: 'Promedios de los últimos 7 días con registros',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatGrid(
            minTileWidth: 130,
            children: [
              ProgressCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Calorías / día',
                value: Formatters.formatNumber(stats.average.kcal.round()),
              ),
              ProgressCard(
                icon: Icons.egg_alt_outlined,
                label: 'Proteínas / día',
                value:
                    '${Formatters.formatNumber(stats.average.protein.round())} g',
                color: MacroColors.protein,
              ),
              ProgressCard(
                icon: Icons.event_available_rounded,
                label: 'Días registrados',
                value: '${stats.daysRegistered}',
                color: palette.secondary,
              ),
              ProgressCard(
                icon: Icons.task_alt_rounded,
                label: 'Cumplimiento',
                value: target <= 0 ? '–' : '${stats.compliancePercent} %',
                color: AppColors.success,
              ),
              ProgressCard(
                icon: Icons.water_drop_rounded,
                label: 'Agua / día',
                value: water.daysRegistered == 0
                    ? '–'
                    : Formatters.formatWater(water.averageMl),
                color: WaterTrackerCard.color,
              ),
              ProgressCard(
                icon: Icons.local_drink_outlined,
                label: 'Meta de agua',
                value: '${water.daysOnGoal} / 7 días',
                color: WaterTrackerCard.color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ESTA SEMANA',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < week.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      AppConstants.weekDays[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _isToday(week[i].date, today)
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: _isToday(week[i].date, today)
                            ? AppColors.primary
                            : palette.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: maxKcal <= 0
                            ? 0
                            : (week[i].totals.kcal / maxKcal).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: AppColors.primary,
                        backgroundColor: palette.surfaceMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      week[i].isEmpty
                          ? '–'
                          : '${Formatters.formatNumber(week[i].totals.kcal.round())} kcal',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (target > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Tu objetivo: '
              '${Formatters.formatNumber(target.round())} kcal/día. '
              'Un día cuenta como cumplido si está entre el 90 % y el 110 %.',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  static bool _isToday(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
