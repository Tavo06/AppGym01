import 'auth_provider.dart';
import 'nutrition_provider.dart';
import 'progress_provider.dart';
import 'schedule_provider.dart';
import 'workout_provider.dart';

/// Cada vez que cambia el usuario con sesión (cierre de sesión, otra
/// cuenta), descarta el entrenamiento, las estadísticas, el calendario y la
/// alimentación en memoria: el usuario B nunca debe ver datos del usuario A.
///
/// Devuelve una función para desconectar el listener.
void Function() bindSessionCleanup({
  required AuthProvider auth,
  required WorkoutProvider workout,
  required ProgressProvider progress,
  ScheduleProvider? schedule,
  NutritionProvider? nutrition,
}) {
  var lastUid = auth.uid;
  void listener() {
    final uid = auth.uid;
    if (uid == lastUid) return;
    lastUid = uid;
    workout.reset();
    progress.reset();
    schedule?.reset();
    nutrition?.reset();
  }

  auth.addListener(listener);
  return () => auth.removeListener(listener);
}
