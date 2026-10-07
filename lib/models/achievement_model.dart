import '../core/utils/firestore_utils.dart';
import 'nutrition_model.dart';
import 'personal_record_model.dart';
import 'scheduled_workout_model.dart';
import 'workout_model.dart';

/// Grupo en que se muestra un logro.
enum AchievementCategory {
  consistency('Constancia'),
  strength('Fuerza'),
  volume('Volumen'),
  planning('Planificación'),
  nutrition('Alimentación'),
  hydration('Hidratación');

  const AchievementCategory(this.label);

  final String label;
}

/// Dificultad de un logro.
enum AchievementTier {
  bronze('Bronce'),
  silver('Plata'),
  gold('Oro');

  const AchievementTier(this.label);

  final String label;
}

/// De dónde salen los datos de una métrica. Cada fuente se carga por
/// separado (la alimentación, por ejemplo, solo al abrir su pestaña).
enum AchievementSource { training, schedule, nutrition }

/// Valor que mide un logro.
enum AchievementMetric {
  workouts(AchievementSource.training),
  bestDayStreak(AchievementSource.training),
  bestWeekStreak(AchievementSource.training),
  distinctExercises(AchievementSource.training),
  trainingHours(AchievementSource.training),
  records(AchievementSource.training),
  totalVolume(AchievementSource.training),
  bestSessionVolume(AchievementSource.training),
  scheduledDone(AchievementSource.schedule),
  nutritionPlans(AchievementSource.nutrition),
  foodDayStreak(AchievementSource.nutrition),
  calorieDaysOnTarget(AchievementSource.nutrition),
  waterDaysOnGoal(AchievementSource.nutrition),
  waterDayStreak(AchievementSource.nutrition);

  const AchievementMetric(this.source);

  final AchievementSource source;
}

/// Valores de las métricas calculados con los datos del usuario. Las
/// métricas de una fuente que todavía no se cargó no tienen valor: sus
/// logros no se evalúan (ni se dan por perdidos) hasta que llegue.
class AchievementStats {
  AchievementStats(Map<AchievementMetric, num> values)
    : _values = Map.unmodifiable(values);

  static final AchievementStats empty = AchievementStats(const {});

  final Map<AchievementMetric, num> _values;

  /// Valor de [metric], o `null` si su fuente no está cargada.
  num? valueOf(AchievementMetric metric) => _values[metric];

  /// Fuentes con datos.
  Set<AchievementSource> get sources => {
    for (final metric in _values.keys) metric.source,
  };

  /// Calcula las métricas. Una fuente `null` es una fuente sin cargar.
  ///
  /// - [workouts] y [records]: historial completo y récords.
  /// - [scheduled]: entrenamientos programados del calendario.
  /// - [nutritionDays] y [nutritionPlans]: días de consumo cargados y planes.
  /// - [calorieTarget]: kcal del plan activo (0 si no hay plan activo).
  /// - [waterGoal]: meta diaria de agua en ml.
  factory AchievementStats.compute({
    required DateTime now,
    List<WorkoutSession>? workouts,
    List<PersonalRecord>? records,
    List<ScheduledWorkout>? scheduled,
    List<DailyNutritionRecord>? nutritionDays,
    List<NutritionPlan>? nutritionPlans,
    double calorieTarget = 0,
    int waterGoal = 0,
  }) {
    final values = <AchievementMetric, num>{};

    if (workouts != null && records != null) {
      final trainedDays = {for (final w in workouts) dayOf(sessionDate(w))};
      var hours = Duration.zero;
      var bestSession = 0.0;
      var totalVolume = 0.0;
      final exercises = <String>{};
      for (final w in workouts) {
        hours += w.duration;
        totalVolume += w.totalVolume;
        if (w.totalVolume > bestSession) bestSession = w.totalVolume;
        for (final e in w.exercises) {
          if (e.sets.isNotEmpty) exercises.add(e.exerciseId);
        }
      }
      values
        ..[AchievementMetric.workouts] = workouts.length
        ..[AchievementMetric.bestDayStreak] = longestDayStreak(trainedDays)
        ..[AchievementMetric.bestWeekStreak] = longestWeekStreak(trainedDays)
        ..[AchievementMetric.distinctExercises] = exercises.length
        ..[AchievementMetric.trainingHours] = hours.inMinutes / 60
        ..[AchievementMetric.records] = records.length
        ..[AchievementMetric.totalVolume] = totalVolume
        ..[AchievementMetric.bestSessionVolume] = bestSession;

      // Los programados necesitan también las sesiones para saber si se
      // cumplieron.
      if (scheduled != null) {
        values[AchievementMetric.scheduledDone] = countScheduledDone(
          scheduled,
          workouts,
          now,
        );
      }
    }

    if (nutritionDays != null && nutritionPlans != null) {
      final foodDays = {
        for (final d in nutritionDays)
          if (!d.isEmpty) d.date,
      };
      final waterDays = {
        for (final d in nutritionDays)
          if (waterGoal > 0 && d.waterMl >= waterGoal) d.date,
      };
      var onTarget = 0;
      if (calorieTarget > 0) {
        for (final d in nutritionDays) {
          if (d.isEmpty) continue;
          final ratio = d.totals.kcal / calorieTarget;
          if (ratio >= 0.9 && ratio <= 1.1) onTarget++;
        }
      }
      values
        ..[AchievementMetric.nutritionPlans] = nutritionPlans.length
        ..[AchievementMetric.foodDayStreak] = longestDayStreak(foodDays)
        ..[AchievementMetric.calorieDaysOnTarget] = onTarget
        ..[AchievementMetric.waterDaysOnGoal] = waterDays.length
        ..[AchievementMetric.waterDayStreak] = longestDayStreak(waterDays);
    }

    return AchievementStats(values);
  }

  static DateTime sessionDate(WorkoutSession w) =>
      (w.finishedAt ?? w.startedAt).toLocal();

  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Racha más larga de días consecutivos en [days] (en cualquier momento,
  /// no solo la actual).
  static int longestDayStreak(Iterable<DateTime> days) {
    final set = {for (final d in days) dayOf(d)};
    var best = 0;
    for (final day in set) {
      // Solo se cuenta desde el primer día de cada racha.
      if (set.contains(DateTime(day.year, day.month, day.day - 1))) continue;
      var length = 1;
      var next = DateTime(day.year, day.month, day.day + 1);
      while (set.contains(next)) {
        length++;
        next = DateTime(next.year, next.month, next.day + 1);
      }
      if (length > best) best = length;
    }
    return best;
  }

  /// Racha más larga de semanas seguidas (lunes a domingo) con al menos un
  /// día en [days].
  static int longestWeekStreak(Iterable<DateTime> days) {
    final mondays = {
      for (final d in days) DateTime(d.year, d.month, d.day - (d.weekday - 1)),
    };
    var best = 0;
    for (final monday in mondays) {
      final previous = DateTime(monday.year, monday.month, monday.day - 7);
      if (mondays.contains(previous)) continue;
      var length = 1;
      var next = DateTime(monday.year, monday.month, monday.day + 7);
      while (mondays.contains(next)) {
        length++;
        next = DateTime(next.year, next.month, next.day + 7);
      }
      if (length > best) best = length;
    }
    return best;
  }

  /// Programados hasta hoy que se completaron con una sesión ese mismo día.
  static int countScheduledDone(
    Iterable<ScheduledWorkout> scheduled,
    Iterable<WorkoutSession> workouts,
    DateTime now,
  ) {
    final byDay = <DateTime, List<WorkoutSession>>{};
    for (final w in workouts) {
      byDay.putIfAbsent(dayOf(sessionDate(w)), () => []).add(w);
    }
    final today = dayOf(now);
    var done = 0;
    for (final item in scheduled) {
      if (item.date.isAfter(today)) continue;
      if (item.isCompletedBy(byDay[item.date] ?? const [])) done++;
    }
    return done;
  }
}

/// Logro conseguido por el usuario (`users/{uid}/achievements/{id}`). La
/// definición (título, meta…) está en el catálogo; aquí solo se guarda
/// cuándo se consiguió.
///
/// Encapsulado: campos privados de solo lectura.
class UnlockedAchievement {
  UnlockedAchievement({required this._id, required this._unlockedAt});

  final String _id;
  final DateTime _unlockedAt;

  String get id => _id;
  DateTime get unlockedAt => _unlockedAt;

  Map<String, dynamic> toMap() => {'unlockedAt': _unlockedAt};

  factory UnlockedAchievement.fromMap(String id, Map<String, dynamic> map) =>
      UnlockedAchievement(
        id: id,
        unlockedAt: firestoreDateFrom(map['unlockedAt']) ?? DateTime.now(),
      );
}
