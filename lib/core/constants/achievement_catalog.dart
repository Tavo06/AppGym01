import 'package:flutter/material.dart';

import '../../models/achievement_model.dart';
import '../utils/formatters.dart';

/// Definición de un logro: se consigue cuando [metric] llega a [target].
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.tier,
    required this.metric,
    required this.target,
  });

  /// Identificador estable: es el ID del documento en Firestore. No cambiar.
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final AchievementTier tier;
  final AchievementMetric metric;
  final num target;

  /// `null` si la fuente de la métrica todavía no está cargada.
  num? currentValue(AchievementStats stats) => stats.valueOf(metric);

  bool isReachedBy(AchievementStats stats) {
    final value = currentValue(stats);
    return value != null && value >= target;
  }

  /// Avance de 0 a 1 (sin pasar de 1), o `null` sin datos.
  double? progressOf(AchievementStats stats) {
    final value = currentValue(stats);
    if (value == null) return null;
    final ratio = value / target;
    return ratio > 1 ? 1 : ratio.toDouble();
  }

  /// Valor legible de la métrica: "12", "10.000 kg", "4 h".
  String format(num value) => switch (metric) {
    AchievementMetric.totalVolume || AchievementMetric.bestSessionVolume =>
      Formatters.formatVolume(value.toDouble()),
    AchievementMetric.trainingHours => '${value.floor()} h',
    _ => Formatters.formatNumber(value.floor()),
  };
}

/// Catálogo de logros. Todos se calculan con datos que la app ya guarda.
abstract final class AchievementCatalog {
  static const List<AchievementDefinition> all = [
    // ------------------------------------------------------- constancia
    AchievementDefinition(
      id: 'workouts-1',
      title: 'Primer paso',
      description: 'Completa tu primer entrenamiento.',
      icon: Icons.flag_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.workouts,
      target: 1,
    ),
    AchievementDefinition(
      id: 'workouts-10',
      title: 'Tomando ritmo',
      description: 'Completa 10 entrenamientos.',
      icon: Icons.fitness_center_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.workouts,
      target: 10,
    ),
    AchievementDefinition(
      id: 'workouts-50',
      title: 'Constante',
      description: 'Completa 50 entrenamientos.',
      icon: Icons.fitness_center_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.silver,
      metric: AchievementMetric.workouts,
      target: 50,
    ),
    AchievementDefinition(
      id: 'workouts-100',
      title: 'Club de los 100',
      description: 'Completa 100 entrenamientos.',
      icon: Icons.military_tech_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.gold,
      metric: AchievementMetric.workouts,
      target: 100,
    ),
    AchievementDefinition(
      id: 'day-streak-3',
      title: 'En marcha',
      description: 'Entrena 3 días seguidos.',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.bestDayStreak,
      target: 3,
    ),
    AchievementDefinition(
      id: 'day-streak-7',
      title: 'Semana imparable',
      description: 'Entrena 7 días seguidos.',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.gold,
      metric: AchievementMetric.bestDayStreak,
      target: 7,
    ),
    AchievementDefinition(
      id: 'week-streak-4',
      title: 'Un mes activo',
      description: 'Entrena al menos una vez por semana 4 semanas seguidas.',
      icon: Icons.date_range_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.bestWeekStreak,
      target: 4,
    ),
    AchievementDefinition(
      id: 'week-streak-12',
      title: 'Hábito formado',
      description: 'Entrena al menos una vez por semana 12 semanas seguidas.',
      icon: Icons.date_range_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.silver,
      metric: AchievementMetric.bestWeekStreak,
      target: 12,
    ),
    AchievementDefinition(
      id: 'week-streak-26',
      title: 'Medio año sin fallar',
      description: 'Entrena al menos una vez por semana 26 semanas seguidas.',
      icon: Icons.event_available_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.gold,
      metric: AchievementMetric.bestWeekStreak,
      target: 26,
    ),
    AchievementDefinition(
      id: 'exercises-10',
      title: 'Explorador',
      description: 'Entrena 10 ejercicios distintos.',
      icon: Icons.explore_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.distinctExercises,
      target: 10,
    ),
    AchievementDefinition(
      id: 'hours-10',
      title: '10 horas de hierro',
      description: 'Acumula 10 horas de entrenamiento.',
      icon: Icons.timer_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.trainingHours,
      target: 10,
    ),
    AchievementDefinition(
      id: 'hours-50',
      title: '50 horas de hierro',
      description: 'Acumula 50 horas de entrenamiento.',
      icon: Icons.timer_rounded,
      category: AchievementCategory.consistency,
      tier: AchievementTier.silver,
      metric: AchievementMetric.trainingHours,
      target: 50,
    ),
    // ----------------------------------------------------------- fuerza
    AchievementDefinition(
      id: 'records-1',
      title: 'Primer récord',
      description: 'Consigue tu primer récord personal.',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.strength,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.records,
      target: 1,
    ),
    AchievementDefinition(
      id: 'records-10',
      title: 'Coleccionista de récords',
      description: 'Ten récords personales en 10 ejercicios.',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.strength,
      tier: AchievementTier.silver,
      metric: AchievementMetric.records,
      target: 10,
    ),
    AchievementDefinition(
      id: 'records-25',
      title: 'Leyenda del gimnasio',
      description: 'Ten récords personales en 25 ejercicios.',
      icon: Icons.workspace_premium_rounded,
      category: AchievementCategory.strength,
      tier: AchievementTier.gold,
      metric: AchievementMetric.records,
      target: 25,
    ),
    // ---------------------------------------------------------- volumen
    AchievementDefinition(
      id: 'session-volume-5000',
      title: 'Sesión pesada',
      description: 'Levanta 5.000 kg en un solo entrenamiento.',
      icon: Icons.scale_rounded,
      category: AchievementCategory.volume,
      tier: AchievementTier.silver,
      metric: AchievementMetric.bestSessionVolume,
      target: 5000,
    ),
    AchievementDefinition(
      id: 'volume-10000',
      title: '10 toneladas',
      description: 'Acumula 10.000 kg levantados.',
      icon: Icons.scale_rounded,
      category: AchievementCategory.volume,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.totalVolume,
      target: 10000,
    ),
    AchievementDefinition(
      id: 'volume-100000',
      title: '100 toneladas',
      description: 'Acumula 100.000 kg levantados.',
      icon: Icons.scale_rounded,
      category: AchievementCategory.volume,
      tier: AchievementTier.silver,
      metric: AchievementMetric.totalVolume,
      target: 100000,
    ),
    AchievementDefinition(
      id: 'volume-1000000',
      title: 'Mil toneladas',
      description: 'Acumula 1.000.000 kg levantados.',
      icon: Icons.landscape_rounded,
      category: AchievementCategory.volume,
      tier: AchievementTier.gold,
      metric: AchievementMetric.totalVolume,
      target: 1000000,
    ),
    // --------------------------------------------------- planificación
    AchievementDefinition(
      id: 'scheduled-1',
      title: 'Lo planeé y lo hice',
      description: 'Cumple un entrenamiento programado en el calendario.',
      icon: Icons.event_available_rounded,
      category: AchievementCategory.planning,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.scheduledDone,
      target: 1,
    ),
    AchievementDefinition(
      id: 'scheduled-10',
      title: 'Agenda cumplida',
      description: 'Cumple 10 entrenamientos programados.',
      icon: Icons.calendar_month_rounded,
      category: AchievementCategory.planning,
      tier: AchievementTier.silver,
      metric: AchievementMetric.scheduledDone,
      target: 10,
    ),
    // ----------------------------------------------------- alimentación
    AchievementDefinition(
      id: 'nutrition-plan-1',
      title: 'Objetivo fijado',
      description: 'Define tu objetivo diario de comida.',
      icon: Icons.restaurant_menu_rounded,
      category: AchievementCategory.nutrition,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.nutritionPlans,
      target: 1,
    ),
    AchievementDefinition(
      id: 'food-streak-7',
      title: 'Una semana anotada',
      description: 'Registra lo que comes 7 días seguidos.',
      icon: Icons.edit_note_rounded,
      category: AchievementCategory.nutrition,
      tier: AchievementTier.silver,
      metric: AchievementMetric.foodDayStreak,
      target: 7,
    ),
    AchievementDefinition(
      id: 'calories-on-target-5',
      title: 'En el objetivo',
      description:
          'Termina 5 días con tus calorías dentro del ±10 % de tu '
          'objetivo diario.',
      icon: Icons.track_changes_rounded,
      category: AchievementCategory.nutrition,
      tier: AchievementTier.silver,
      metric: AchievementMetric.calorieDaysOnTarget,
      target: 5,
    ),
    AchievementDefinition(
      id: 'calories-on-target-20',
      title: 'Precisión total',
      description:
          'Termina 20 días con tus calorías dentro del ±10 % de tu '
          'objetivo diario.',
      icon: Icons.track_changes_rounded,
      category: AchievementCategory.nutrition,
      tier: AchievementTier.gold,
      metric: AchievementMetric.calorieDaysOnTarget,
      target: 20,
    ),
    // ----------------------------------------------------- hidratación
    AchievementDefinition(
      id: 'water-goal-1',
      title: 'Primer vaso lleno',
      description: 'Cumple tu meta diaria de agua por primera vez.',
      icon: Icons.water_drop_rounded,
      category: AchievementCategory.hydration,
      tier: AchievementTier.bronze,
      metric: AchievementMetric.waterDaysOnGoal,
      target: 1,
    ),
    AchievementDefinition(
      id: 'water-streak-7',
      title: 'Bien hidratado',
      description: 'Cumple tu meta de agua 7 días seguidos.',
      icon: Icons.water_drop_rounded,
      category: AchievementCategory.hydration,
      tier: AchievementTier.silver,
      metric: AchievementMetric.waterDayStreak,
      target: 7,
    ),
    AchievementDefinition(
      id: 'water-streak-21',
      title: 'Hábito de agua',
      description: 'Cumple tu meta de agua 21 días seguidos.',
      icon: Icons.waves_rounded,
      category: AchievementCategory.hydration,
      tier: AchievementTier.gold,
      metric: AchievementMetric.waterDayStreak,
      target: 21,
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final definition in all) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static List<AchievementDefinition> ofCategory(AchievementCategory category) =>
      [
        for (final definition in all)
          if (definition.category == category) definition,
      ];
}
