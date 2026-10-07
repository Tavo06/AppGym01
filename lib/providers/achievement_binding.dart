import 'dart:async';

import '../models/achievement_model.dart';
import 'achievement_provider.dart';
import 'auth_provider.dart';
import 'nutrition_provider.dart';
import 'progress_provider.dart';
import 'schedule_provider.dart';

/// Enlaza los logros con los módulos de los que salen sus métricas: cada
/// vez que cambian el progreso, el calendario o la alimentación se
/// recalculan las métricas y se pasan a [achievements]. Una fuente que aún
/// no se cargó no aporta métricas (sus logros esperan).
///
/// Al iniciar sesión carga el progreso y los logros guardados aunque el
/// usuario no abra Progreso: así se conoce el punto de partida antes de su
/// próximo entrenamiento y ese logro sí se anuncia.
///
/// Devuelve una función para desconectar los listeners.
void Function() bindAchievements({
  required AchievementProvider achievements,
  required AuthProvider auth,
  required ProgressProvider progress,
  ScheduleProvider? schedule,
  NutritionProvider? nutrition,
}) {
  var bound = true;

  void update() {
    final hasTraining = progress.hasData;
    final hasNutrition = nutrition != null && nutrition.loaded;
    achievements.updateStats(
      AchievementStats.compute(
        now: DateTime.now(),
        workouts: hasTraining ? progress.workouts : null,
        records: hasTraining ? progress.records : null,
        scheduled: schedule != null && schedule.loaded ? schedule.items : null,
        nutritionDays: hasNutrition ? nutrition.loadedDays : null,
        nutritionPlans: hasNutrition ? nutrition.plans : null,
        calorieTarget: nutrition?.activePlan?.calories ?? 0,
        waterGoal: nutrition?.waterGoal ?? 0,
      ),
    );
  }

  void loadForSession() {
    if (!bound || auth.uid == null) return;
    if (!progress.hasData && !progress.loading && progress.error == null) {
      progress.refresh();
    }
    achievements.ensureLoaded();
  }

  // En una microtarea: el aviso de AuthProvider puede llegar durante la
  // construcción de un widget, y las cargas avisan a sus listeners.
  void onAuth() => scheduleMicrotask(loadForSession);

  auth.addListener(onAuth);
  progress.addListener(update);
  schedule?.addListener(update);
  nutrition?.addListener(update);
  update();
  onAuth();
  return () {
    bound = false;
    auth.removeListener(onAuth);
    progress.removeListener(update);
    schedule?.removeListener(update);
    nutrition?.removeListener(update);
  };
}
