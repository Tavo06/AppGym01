import 'achievement_provider.dart';
import 'auth_provider.dart';
import 'nutrition_provider.dart';
import 'progress_provider.dart';
import 'schedule_provider.dart';
import 'workout_provider.dart';

/// Cada vez que cambia el usuario con sesión (cierre de sesión, otra
/// cuenta), descarta el entrenamiento, las estadísticas, el calendario, la
/// alimentación y los logros en memoria: el usuario B nunca debe ver datos
/// del usuario A.
///
/// Devuelve una función para desconectar el listener.
void Function() bindSessionCleanup({
  required AuthProvider auth,
  required WorkoutProvider workout,
  required ProgressProvider progress,
  ScheduleProvider? schedule,
  NutritionProvider? nutrition,
  AchievementProvider? achievements,
}) {
  var lastUid = auth.uid;
  void listener() {
    final uid = auth.uid;
    if (uid == lastUid) return;
    lastUid = uid;
    // Los logros primero: así los demás reset no los evalúan con la cuenta
    // anterior.
    achievements?.reset();
    workout.reset();
    progress.reset();
    schedule?.reset();
    nutrition?.reset();
  }

  auth.addListener(listener);
  return () => auth.removeListener(listener);
}
