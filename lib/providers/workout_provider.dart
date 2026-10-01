import 'package:flutter/foundation.dart';

import '../models/exercise_model.dart';
import '../models/routine_day_model.dart';
import '../models/routine_model.dart';
import '../models/workout_model.dart';
import '../models/workout_set_model.dart';
import '../services/firestore_service.dart';
import '../services/app_firebase.dart';

class WorkoutProvider extends ChangeNotifier {
  /// Los parámetros permiten inyectar dependencias en las pruebas; en la app
  /// se usan Firestore y el usuario actual de Firebase Auth.
  WorkoutProvider({FirestoreService? firestore, this._currentUid})
    : _firestoreOverride = firestore;

  final FirestoreService? _firestoreOverride;
  final String? Function()? _currentUid;
  FirestoreService? _lazyFirestore;
  FirestoreService get _firestore =>
      _firestoreOverride ?? (_lazyFirestore ??= FirestoreService());

  WorkoutRoutine? _routine;
  List<ExerciseModel> _exercises = [];
  final Map<String, List<WorkoutSet>> _setsByExercise = {};
  DateTime? _startedAt;
  bool _saving = false;

  WorkoutSession? _lastSession;
  List<NewRecordInfo> _lastNewRecords = [];

  WorkoutRoutine? get routine => _routine;
  bool get active => _routine != null && _startedAt != null;
  bool get saving => _saving;
  String? get userId =>
      _currentUid != null ? _currentUid() : AppFirebase.auth.currentUser?.uid;
  DateTime? get startedAt => _startedAt;
  String get routineName => _routine?.name ?? freeWorkoutName;
  List<ExerciseModel> get exercises => List.unmodifiable(_exercises);

  WorkoutSession? get lastSession => _lastSession;
  List<NewRecordInfo> get lastNewRecords => _lastNewRecords;

  List<WorkoutSet> setsFor(String exerciseId) =>
      List.unmodifiable(_setsByExercise[exerciseId] ?? const []);

  int seriesFor(String exerciseId) => _setsByExercise[exerciseId]?.length ?? 0;

  double volumeFor(String exerciseId) {
    final sets = _setsByExercise[exerciseId] ?? const <WorkoutSet>[];
    return sets.fold(0, (sum, s) => sum + (s.completed ? s.volume : 0));
  }

  int repsFor(String exerciseId) {
    final sets = _setsByExercise[exerciseId] ?? const <WorkoutSet>[];
    return sets.fold(0, (sum, s) => sum + (s.completed ? s.repetitions : 0));
  }

  double get totalVolume => _setsByExercise.values.fold(
    0,
    (sum, sets) =>
        sum + sets.fold(0, (s, set) => s + (set.completed ? set.volume : 0)),
  );

  int get totalSets =>
      _setsByExercise.values.fold(0, (sum, sets) => sum + sets.length);

  int get totalCompletedSets => _setsByExercise.values.fold(
    0,
    (sum, sets) => sum + sets.where((s) => s.completed).length,
  );

  int get totalReps => _setsByExercise.values.fold(
    0,
    (sum, sets) =>
        sum +
        sets.fold(0, (s, set) => s + (set.completed ? set.repetitions : 0)),
  );

  int get totalExercises =>
      _setsByExercise.values.where((sets) => sets.isNotEmpty).length;

  /// Inicia un entrenamiento. Devuelve `false` si la rutina no tiene
  /// ejercicios válidos: en ese caso no se modifica el estado, para no
  /// dejar un entrenamiento fantasma activo.
  bool startWorkout({
    required WorkoutRoutine routine,
    required List<ExerciseModel> allExercises,
  }) {
    if (routine.exercises.isEmpty) return false;
    final resolved = routine.exercises
        .map((id) => _exerciseOrNull(allExercises, id))
        .whereType<ExerciseModel>()
        .toList();
    if (resolved.isEmpty) return false;

    _routine = routine;
    _exercises = resolved;
    _setsByExercise.clear();
    for (final exercise in resolved) {
      _setsByExercise[exercise.id] = [];
    }
    _startedAt = DateTime.now();
    _lastSession = null;
    _lastNewRecords = [];
    notifyListeners();
    return true;
  }

  /// Inicia un entrenamiento libre con los ejercicios elegidos, sin rutina.
  /// Se guarda con el nombre "Entrenamiento libre" y `routineId` vacío.
  bool startFreeWorkout(List<ExerciseModel> exercises) {
    if (exercises.isEmpty) return false;
    _routine = WorkoutRoutine(
      id: '',
      userId: userId ?? '',
      name: freeWorkoutName,
      exercises: exercises.map((e) => e.id).toList(),
    );
    _exercises = List.of(exercises);
    _setsByExercise.clear();
    for (final exercise in exercises) {
      _setsByExercise[exercise.id] = [];
    }
    _startedAt = DateTime.now();
    _lastSession = null;
    _lastNewRecords = [];
    notifyListeners();
    return true;
  }

  static const String freeWorkoutName = 'Entrenamiento libre';

  /// Ejercicios del usuario actual (para el entrenamiento libre).
  Future<List<ExerciseModel>> loadExercises() async {
    final uid = userId;
    if (uid == null) return [];
    return _firestore.getExercises(uid);
  }

  /// Vuelve a iniciar una rutina guardada a partir de su id. Devuelve un
  /// mensaje de error, o `null` si el entrenamiento comenzó.
  ///
  /// Si se indica [dayId] (el día que se entrenó la última vez) se repite
  /// ese día; las rutinas de un solo día se entrenan completas.
  Future<String?> repeatRoutine(String routineId, {String dayId = ''}) async {
    final uid = userId;
    if (uid == null) return 'No hay una sesión activa.';
    final results = await Future.wait([
      _firestore.getRoutines(uid),
      _firestore.getExercises(uid),
    ]);
    final routines = (results[0] as List).cast<WorkoutRoutine>();
    final exercises = (results[1] as List).cast<ExerciseModel>();
    WorkoutRoutine? routine;
    for (final r in routines) {
      if (r.id == routineId) routine = r;
    }
    if (routine == null) return 'Esa rutina ya no existe.';
    final day =
        routine.dayById(dayId) ??
        (routine.days.length == 1 ? routine.days.first : null);
    final toStart = day == null
        ? routine
        : routine.withExercises(exercises).forDay(day);
    final started = startWorkout(routine: toStart, allExercises: exercises);
    return started
        ? null
        : 'Los ejercicios de esa rutina ya no existen. Edítala para '
              'elegir otros.';
  }

  bool get isFreeWorkout => active && (_routine?.id.isEmpty ?? false);

  /// Plan del ejercicio en la rutina (series, repeticiones, peso, descanso
  /// y notas). Los entrenamientos libres no tienen plan.
  RoutineExercise? plannedFor(String exerciseId) {
    final routine = _routine;
    if (routine == null || routine.id.isEmpty) return null;
    return routine.planFor(exerciseId);
  }

  /// Día de la rutina que se está entrenando (vacío si es libre o si la
  /// rutina se entrena completa con varios días).
  String get routineDayId {
    final routine = _routine;
    if (routine == null || routine.id.isEmpty) return '';
    return routine.days.length == 1 ? routine.days.first.id : '';
  }

  /// Un ejercicio está completo cuando se registraron las series planeadas
  /// (sin plan, cuando tiene al menos una serie).
  bool isExerciseDone(String exerciseId) {
    final done = (_setsByExercise[exerciseId] ?? const <WorkoutSet>[])
        .where((s) => s.completed)
        .length;
    final plan = plannedFor(exerciseId);
    return plan == null ? done > 0 : done >= plan.sets;
  }

  /// Ejercicios completos según su plan.
  int get completedExercises =>
      _exercises.where((e) => isExerciseDone(e.id)).length;

  ExerciseModel? _exerciseOrNull(List<ExerciseModel> source, String id) {
    for (final exercise in source) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  void addSet(
    String exerciseId, {
    required double weight,
    required int repetitions,
    int restSeconds = 0,
  }) {
    final sets = _setsByExercise[exerciseId];
    if (sets == null) return;
    sets.add(
      WorkoutSet(
        setNumber: sets.length + 1,
        weight: weight,
        repetitions: repetitions,
        restSeconds: restSeconds,
      ),
    );
    notifyListeners();
  }

  void removeSet(String exerciseId, int index) {
    final sets = _setsByExercise[exerciseId];
    if (sets == null || index < 0 || index >= sets.length) return;
    sets.removeAt(index);
    for (var i = 0; i < sets.length; i++) {
      sets[i] = sets[i].renumbered(i + 1);
    }
    notifyListeners();
  }

  void removeLastSet(String exerciseId) {
    final sets = _setsByExercise[exerciseId];
    if (sets == null || sets.isEmpty) return;
    sets.removeLast();
    for (var i = 0; i < sets.length; i++) {
      sets[i] = sets[i].renumbered(i + 1);
    }
    notifyListeners();
  }

  WorkoutSession _buildSession({String notes = ''}) {
    final finishedAt = DateTime.now();
    final exercises = _exercises
        .map(
          (exercise) => WorkoutExerciseRecord(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            // Copia defensiva: compartir la lista viva del provider
            // haría que el resumen mostrara cambios posteriores.
            sets: List<WorkoutSet>.from(
              _setsByExercise[exercise.id] ?? const [],
            ),
          ),
        )
        .where((record) => record.sets.isNotEmpty)
        .toList();

    return WorkoutSession(
      id: _firestore.newDocId,
      userId: userId ?? '',
      routineId: _routine?.id ?? '',
      routineName: _routine?.name ?? freeWorkoutName,
      routineDayId: routineDayId,
      startedAt: _startedAt ?? finishedAt,
      finishedAt: finishedAt,
      duration: finishedAt.difference(_startedAt ?? finishedAt),
      totalVolume: totalVolume,
      totalSets: totalCompletedSets,
      totalReps: totalReps,
      totalExercises: exercises.length,
      notes: notes,
      exercises: exercises,
    );
  }

  Future<WorkoutSaveResult?> finishWorkout({String notes = ''}) async {
    final uid = userId;
    if (uid == null) return null;
    if (totalCompletedSets == 0) return null;

    _saving = true;
    notifyListeners();
    try {
      final session = _buildSession(notes: notes);
      final result = await _firestore.saveWorkout(uid, session);
      _lastSession = session;
      _lastNewRecords = result.newRecords;
      return result;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Descarta el entrenamiento en curso conservando la sesión ya guardada,
  /// para que la pantalla de resumen siga teniendo datos que mostrar.
  void clearActiveWorkout() {
    _routine = null;
    _exercises = [];
    _setsByExercise.clear();
    _startedAt = null;
    notifyListeners();
  }

  void reset() {
    _routine = null;
    _exercises = [];
    _setsByExercise.clear();
    _startedAt = null;
    _lastSession = null;
    _lastNewRecords = [];
    notifyListeners();
  }
}
