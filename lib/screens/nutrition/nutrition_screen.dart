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
import '../../widgets/error_state.dart';
import '../../widgets/food_form_sheet.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/nutrition_progress_panel.dart';
import '../../widgets/progress_card.dart';

/// Alimentación (`/alimentacion`): plan activo, progreso de hoy, registro
/// diario, mis planes y progreso nutricional.
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

  Future<void> _activate(NutritionPlan plan) async {
    final provider = context.read<NutritionProvider>();
    final confirmed = await ConfirmationDialog.show(
      context,
      icon: Icons.check_circle_outline_rounded,
      title: '¿Usar "${plan.name}" como plan activo?',
      message:
          'Tu progreso diario se comparará con los objetivos de este plan.',
      confirmLabel: 'Activar',
    );
    if (confirmed != true || !mounted) return;
    try {
      await provider.setActivePlan(plan.id);
      if (!mounted) return;
      showAppMessage(context, 'Plan actualizado.', type: FeedbackType.success);
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo cambiar el plan activo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentación'),
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
          final header = _Header(
            onTemplates: () => context.push('/alimentacion/plantillas'),
            onCreate: () => context.push('/alimentacion/plan/nuevo'),
          );
          final activeCard = _ActivePlanCard(
            plan: active,
            consumed: nutrition.today.totals,
          );
          final todayCard = _TodayLog(
            record: nutrition.today,
            onAdd: _logFood,
            onRemove: _removeEntry,
          );
          final plansCard = _MyPlans(
            plans: nutrition.plans,
            onOpen: (plan) => context.push('/alimentacion/plan/${plan.id}'),
            onActivate: _activate,
          );
          final statsCard = _NutritionStatsCard(
            stats: nutrition.statsForLast(7),
            week: nutrition.thisWeek,
            target: active?.calories ?? 0,
          );

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
                        child: wide
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            activeCard,
                                            const SizedBox(height: 16),
                                            statsCard,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            todayCard,
                                            const SizedBox(height: 16),
                                            plansCard,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  const SizedBox(height: 16),
                                  activeCard,
                                  const SizedBox(height: 16),
                                  todayCard,
                                  const SizedBox(height: 16),
                                  plansCard,
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

class _Header extends StatelessWidget {
  const _Header({required this.onTemplates, required this.onCreate});

  final VoidCallback onTemplates;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Alimentación saludable',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Organiza tu alimentación y lleva un seguimiento de tus objetivos.',
          style: TextStyle(fontSize: 14, color: palette.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onTemplates,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Planes predeterminados'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
            ),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear mi plan'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
            ),
          ],
        ),
      ],
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

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.plan, required this.consumed});

  final NutritionPlan? plan;
  final NutritionTotals consumed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = this.plan;
    if (plan == null) {
      return _SectionCard(
        title: 'Mi plan activo',
        child: Row(
          children: [
            Icon(Icons.restaurant_menu_rounded, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Selecciona un plan o crea uno personalizado.',
                style: TextStyle(fontSize: 14, color: palette.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return _SectionCard(
      title: 'Mi plan activo',
      trailing: TextButton(
        onPressed: () => context.push('/alimentacion/plan/${plan.id}'),
        child: const Text('Ver plan'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(icon: Icons.flag_rounded, label: plan.goal),
              _Pill(
                icon: Icons.local_fire_department_rounded,
                label:
                    '${Formatters.formatNumber(plan.calories.round())} kcal/día',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'PROGRESO DE HOY',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          NutritionProgressPanel(consumed: consumed, targets: plan.targets),
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
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registro de hoy agrupado por comida.
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
    return _SectionCard(
      title: 'Hoy',
      subtitle: record.isEmpty
          ? 'Registra lo que comes para ver tu progreso.'
          : null,
      trailing: record.isEmpty
          ? null
          : Text(
              '${Formatters.formatNumber(record.totals.kcal.round())} kcal',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in MealType.values) ...[
            Builder(
              builder: (context) {
                final entries = record.entriesFor(type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              type.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w800,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          if (entries.isNotEmpty)
                            Text(
                              '${Formatters.formatNumber(record.totalsFor(type).kcal.round())} kcal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.textSecondary,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Registrar en ${type.label}',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onAdd(type),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: palette.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sin registrar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final entry in entries)
                          FoodRow(
                            food: entry.food,
                            leading: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            onDelete: () => onRemove(entry),
                          ),
                      Divider(color: palette.border, height: 14),
                    ],
                  ),
                );
              },
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => onAdd(MealType.breakfast),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar alimento'),
          ),
        ],
      ),
    );
  }
}

class _MyPlans extends StatelessWidget {
  const _MyPlans({
    required this.plans,
    required this.onOpen,
    required this.onActivate,
  });

  final List<NutritionPlan> plans;
  final ValueChanged<NutritionPlan> onOpen;
  final ValueChanged<NutritionPlan> onActivate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _SectionCard(
      title: 'Mis planes',
      subtitle: plans.isEmpty
          ? 'Todavía no tienes planes. Usa una plantilla o crea el tuyo.'
          : 'Toca un plan para editar sus comidas.',
      child: Column(
        children: [
          for (final plan in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: plan.active ? palette.primarySoft : palette.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => onOpen(plan),
                  leading: Icon(
                    plan.active
                        ? Icons.check_circle_rounded
                        : Icons.restaurant_menu_rounded,
                    color: plan.active
                        ? AppColors.primary
                        : palette.textSecondary,
                  ),
                  title: Text(
                    plan.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${plan.goal} · '
                    '${Formatters.formatNumber(plan.calories.round())} kcal · '
                    '${plan.meals.length} comidas',
                  ),
                  trailing: plan.active
                      ? const Text(
                          'Activo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : TextButton(
                          onPressed: () => onActivate(plan),
                          child: const Text('Activar'),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Progreso nutricional: promedios de los últimos 7 días y semana actual.
class _NutritionStatsCard extends StatelessWidget {
  const _NutritionStatsCard({
    required this.stats,
    required this.week,
    required this.target,
  });

  final NutritionStats stats;
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
      title: 'Progreso nutricional',
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
                icon: Icons.bakery_dining_outlined,
                label: 'Carbohidratos / día',
                value:
                    '${Formatters.formatNumber(stats.average.carbs.round())} g',
                color: MacroColors.carbs,
              ),
              ProgressCard(
                icon: Icons.water_drop_outlined,
                label: 'Grasas / día',
                value:
                    '${Formatters.formatNumber(stats.average.fat.round())} g',
                color: MacroColors.fat,
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
              'Objetivo del plan activo: '
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
