import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/goal_model.dart';
import '../models/personal_record_model.dart';
import '../models/progress_model.dart';
import '../models/workout_model.dart';
import '../services/firestore_service.dart';
import '../services/app_firebase.dart';

/// Serie de pesos máximos de un ejercicio, en orden cronológico.
typedef ExerciseWeightSeries = ({
  String exerciseId,
  String exerciseName,
  List<DateTime> dates,
  List<double> weights,
});

/// Totales de un periodo (por ejemplo, una semana).
typedef PeriodTotals = ({int workouts, double volume, int sets});

/// Sesión guardada que llegó mientras se cargaban los datos.
typedef _PendingSession = ({
  WorkoutSession session,
  List<NewRecordInfo> records,
});

/// Estado global del progreso: historial, récords, progreso semanal,
/// estadísticas y metas. Lo escuchan los `Consumer<ProgressProvider>` de
/// Progreso e Inicio.
class ProgressProvider extends ChangeNotifier {
  ProgressProvider({FirestoreService? firestore})
    : _firestoreOverride = firestore;

  final FirestoreService? _firestoreOverride;
  FirestoreService? _lazyFirestore;
  FirestoreService get _firestore =>
      _firestoreOverride ?? (_lazyFirestore ??= FirestoreService());

  bool _loading = false;
  String? _error;
  ProgressModel? _progress;
  List<WorkoutSession> _workouts = [];
  List<PersonalRecord> _records = [];
  List<WeeklyProgress> _weekly = [];
  final List<_PendingSession> _pending = [];

  double _volumeGoal = AppConstants.defaultWeeklyVolumeGoal;
  int _setsGoal = AppConstants.defaultWeeklySetsGoal;
  int _workoutsGoal = AppConstants.defaultWeeklyWorkoutsGoal;
  String? _goalsUid;

  /// Se incrementa en cada `reset()`: una carga que empezó antes de un
  /// cierre de sesión no debe escribir sus datos al terminar.
  int _generation = 0;

  bool get loading => _loading;
  String? get error => _error;
  ProgressModel? get progress => _progress;

  /// Entrenamientos del más reciente al más antiguo.
  List<WorkoutSession> get workouts => _workouts;
  List<PersonalRecord> get records => _records;
  List<WeeklyProgress> get weekly => _weekly;

  bool get hasData => _progress != null;

  double get volumeGoal => _volumeGoal;
  int get setsGoal => _setsGoal;
  int get workoutsGoal => _workoutsGoal;

  Future<void> refresh({String? uid}) async {
    final effectiveUid = uid ?? AppFirebase.auth.currentUser?.uid;
    if (effectiveUid == null) return;

    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_goalsUid != effectiveUid) await _loadGoals(effectiveUid);
      final results = await Future.wait([
        _firestore.getWorkouts(effectiveUid),
        _firestore.getPersonalRecords(effectiveUid),
        _firestore.getWeeklyProgress(effectiveUid),
      ]);
      if (generation != _generation) return;
      _workouts = (results[0] as List).cast<WorkoutSession>();
      _records = (results[1] as List).cast<PersonalRecord>();
      _weekly = (results[2] as List).cast<WeeklyProgress>();
      // Sesiones guardadas durante la carga: si la lectura ya las incluía,
      // `_applySession` las ignora.
      for (final pending in _pending) {
        _applySession(pending.session, pending.records);
      }
      _pending.clear();
      _progress = _computeProgress();
    } catch (error) {
      if (generation != _generation) return;
      _error = describeError(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Registra en el estado global una sesión recién guardada en Firestore:
  /// actualiza el historial, el progreso semanal, los récords y las
  /// estadísticas, y avisa a los `Consumer` con `notifyListeners()`.
  ///
  /// No vuelve a leer Firestore: la sesión ya está en memoria. Solo si los
  /// datos nunca se cargaron se hace la carga completa (que la incluye).
  void agregarSesion(
    WorkoutSession session, {
    List<NewRecordInfo> newRecords = const [],
  }) {
    if (_loading || !hasData) {
      _pending.add((session: session, records: newRecords));
    }
    if (!hasData) {
      if (!_loading) {
        unawaited(refresh(uid: session.userId.isEmpty ? null : session.userId));
      }
      return;
    }
    _applySession(session, newRecords);
    _progress = _computeProgress();
    notifyListeners();
  }

  void _applySession(WorkoutSession session, List<NewRecordInfo> newRecords) {
    if (_workouts.any((w) => w.id == session.id)) return;

    // Historial (del más reciente al más antiguo).
    _workouts = [session, ..._workouts];

    // Progreso semanal acumulado, igual que el documento de Firestore.
    final finished = (session.finishedAt ?? session.startedAt).toLocal();
    final weekId = FirestoreService.weekIdOf(finished);
    final index = _weekly.indexWhere((w) => w.weekId == weekId);
    if (index >= 0) {
      _weekly[index].registerSession(
        sets: session.totalSets,
        reps: session.totalReps,
        volume: session.totalVolume,
      );
    } else {
      _weekly = [
        WeeklyProgress(
          id: weekId,
          userId: session.userId,
          weekId: weekId,
          weekStart: FirestoreService.weekStartOf(finished),
          workouts: 1,
          totalSets: session.totalSets,
          totalReps: session.totalReps,
          totalVolume: session.totalVolume,
          updatedAt: DateTime.now(),
        ),
        ..._weekly,
      ];
    }

    // Récords personales batidos en esta sesión.
    for (final info in newRecords) {
      PersonalRecord? previous;
      for (final r in _records) {
        if (r.exerciseId == info.exerciseId) previous = r;
      }
      final record = PersonalRecord(
        id: info.exerciseId,
        userId: session.userId,
        exerciseId: info.exerciseId,
        exerciseName: info.exerciseName,
        maxWeight: info.newWeight,
        reps: info.reps,
        bestVolume: info.newVolume,
        // La fecha es la de la mejor serie: un récord solo de volumen no la
        // cambia.
        date: info.isWeightRecord ? finished : (previous?.date ?? finished),
        updatedAt: DateTime.now(),
      );
      _records = [
        for (final r in _records)
          if (r.exerciseId != info.exerciseId) r,
        record,
      ]..sort(PersonalRecord.compareBest);
    }
  }

  /// Borra los datos en memoria al cerrar sesión, para que otra cuenta no
  /// vea las estadísticas del usuario anterior.
  void reset() {
    _generation++;
    _loading = false;
    _error = null;
    _progress = null;
    _workouts = [];
    _records = [];
    _weekly = [];
    _pending.clear();
    _volumeGoal = AppConstants.defaultWeeklyVolumeGoal;
    _setsGoal = AppConstants.defaultWeeklySetsGoal;
    _workoutsGoal = AppConstants.defaultWeeklyWorkoutsGoal;
    _goalsUid = null;
    notifyListeners();
  }

  static String describeError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No tienes permiso para leer estos datos.';
        case 'unavailable':
          return 'No hay conexión con el servidor. Revisa tu Internet.';
        default:
          return 'Error de Firebase (${error.code}).';
      }
    }
    return 'No se pudieron cargar tus datos.';
  }

  ProgressModel _computeProgress() {
    var totalVolume = 0.0;
    var totalSets = 0;
    var totalReps = 0;
    var totalExercises = 0;
    for (final workout in _workouts) {
      totalVolume += workout.totalVolume;
      totalSets += workout.totalSets;
      totalReps += workout.totalReps;
      totalExercises += workout.totalExercises;
    }

    final now = DateTime.now();
    final weekStart = FirestoreService.weekStartOf(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekVolume = List<double>.filled(7, 0);
    final weekWorkouts = List<int>.filled(7, 0);
    final weekSets = List<int>.filled(7, 0);

    for (final workout in _workouts) {
      final finished = (workout.finishedAt ?? workout.startedAt).toLocal();
      if (finished.isBefore(weekStart) || !finished.isBefore(weekEnd)) {
        continue;
      }
      final index = finished.weekday - DateTime.monday;
      weekVolume[index] += workout.totalVolume;
      weekWorkouts[index] += 1;
      weekSets[index] += workout.totalSets;
    }

    return ProgressModel(
      totalWorkouts: _workouts.length,
      totalVolume: totalVolume,
      totalSets: totalSets,
      totalReps: totalReps,
      totalExercises: totalExercises,
      recordCount: _records.length,
      weekly: weeklyAscending,
      weekVolumeByDay: weekVolume,
      weekWorkoutsByDay: weekWorkouts,
      weekSetsByDay: weekSets,
    );
  }

  /// Progreso por ejercicio, indexado por el ID del ejercicio.
  Map<String, ExerciseProgress> get progressByExercise {
    final byExercise = <String, _ExerciseAggregate>{};
    // Del más antiguo al más reciente, para saber cuál fue la primera y la
    // última sesión de cada ejercicio.
    for (final workout in _workouts.reversed) {
      for (final record in workout.exercises) {
        final aggregate = byExercise.putIfAbsent(
          record.exerciseId,
          _ExerciseAggregate.new,
        )..name = record.exerciseName;
        aggregate.workoutCount += 1;
        aggregate.totalVolume += record.volume;
        aggregate.totalReps += record.totalReps;

        var sessionMax = 0.0;
        for (final set in record.sets) {
          if (!set.completed) continue;
          aggregate.totalSets += 1;
          if (set.weight > sessionMax) sessionMax = set.weight;
          final better =
              set.weight > aggregate.bestWeight ||
              (set.weight == aggregate.bestWeight &&
                  set.repetitions > aggregate.bestReps);
          if (better) {
            aggregate.bestWeight = set.weight;
            aggregate.bestReps = set.repetitions;
          }
        }
        if (sessionMax > 0) {
          if (aggregate.firstWeight == 0) aggregate.firstWeight = sessionMax;
          aggregate.latestWeight = sessionMax;
        }
      }
    }
    return byExercise.map(
      (id, a) => MapEntry(
        id,
        ExerciseProgress(
          exerciseId: id,
          exerciseName: a.name,
          workoutCount: a.workoutCount,
          totalSets: a.totalSets,
          totalReps: a.totalReps,
          bestWeight: a.bestWeight,
          bestReps: a.bestReps,
          totalVolume: a.totalVolume,
          firstWeight: a.firstWeight,
          latestWeight: a.latestWeight,
        ),
      ),
    );
  }

  List<PersonalRecord> get topRecords =>
      _records.length > 5 ? _records.sublist(0, 5) : _records;

  /// Récord personal más reciente (por fecha de logro).
  PersonalRecord? get latestRecord {
    PersonalRecord? latest;
    for (final record in _records) {
      final date = record.date;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest.date!)) latest = record;
    }
    return latest;
  }

  WorkoutSession? get lastWorkout => _workouts.isEmpty ? null : _workouts.first;

  /// Semanas en orden cronológico, desde la más antigua con datos (como
  /// máximo [AppConstants.weeksInHistory]) hasta la actual. Las semanas sin
  /// entrenamientos aparecen con 0 para que los huecos se vean en el gráfico.
  List<WeeklyProgress> get weeklyAscending {
    final byId = {for (final week in _weekly) week.weekId: week};
    final currentStart = FirestoreService.weekStartOf(DateTime.now());
    var oldest = currentStart;
    for (final week in _weekly) {
      final start = FirestoreService.weekStartOf(week.weekStart.toLocal());
      if (start.isBefore(oldest)) oldest = start;
    }

    final weeks = <WeeklyProgress>[];
    var cursor = currentStart;
    // do-while: la semana actual se incluye siempre, aunque todavía no tenga
    // entrenamientos; después se retrocede semana a semana hasta la más
    // antigua registrada o hasta el límite del historial.
    do {
      final id = FirestoreService.weekIdOf(cursor);
      weeks.add(
        byId[id] ??
            WeeklyProgress(id: id, userId: '', weekId: id, weekStart: cursor),
      );
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    } while (!cursor.isBefore(oldest) &&
        weeks.length < AppConstants.weeksInHistory);
    return weeks.reversed.toList();
  }

  /// Totales de la semana actual (lunes a domingo).
  PeriodTotals get thisWeek {
    final start = FirestoreService.weekStartOf(DateTime.now());
    return totalsBetween(_workouts, start, start.add(const Duration(days: 7)));
  }

  /// Totales de la semana anterior, para comparar.
  PeriodTotals get lastWeek {
    final start = FirestoreService.weekStartOf(DateTime.now());
    return totalsBetween(
      _workouts,
      start.subtract(const Duration(days: 7)),
      start,
    );
  }

  /// Metas de la semana actual calculadas con los datos reales.
  List<WeeklyGoal> get weeklyGoals => buildWeeklyGoals(
    week: thisWeek,
    volumeGoal: _volumeGoal,
    setsGoal: _setsGoal,
    workoutsGoal: _workoutsGoal,
    now: DateTime.now(),
  );

  /// Cuántas metas de la semana ya se cumplieron.
  int get goalsReached => weeklyGoals.where((g) => g.isReached).length;

  /// Cambia las metas semanales y las guarda en el dispositivo.
  Future<void> updateGoals({
    required double volume,
    required int sets,
    required int workouts,
  }) async {
    if (volume <= 0 || sets <= 0 || workouts <= 0) return;
    _volumeGoal = volume;
    _setsGoal = sets;
    _workoutsGoal = workouts;
    notifyListeners();
    final uid = _goalsUid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('goal_volume_$uid', volume);
      await prefs.setInt('goal_sets_$uid', sets);
      await prefs.setInt('goal_workouts_$uid', workouts);
    } catch (_) {
      // Si no se puede guardar, las metas siguen aplicadas en esta sesión.
    }
  }

  Future<void> _loadGoals(String uid) async {
    _goalsUid = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      _volumeGoal =
          prefs.getDouble('goal_volume_$uid') ??
          AppConstants.defaultWeeklyVolumeGoal;
      _setsGoal =
          prefs.getInt('goal_sets_$uid') ?? AppConstants.defaultWeeklySetsGoal;
      _workoutsGoal =
          prefs.getInt('goal_workouts_$uid') ??
          AppConstants.defaultWeeklyWorkoutsGoal;
    } catch (_) {
      // Sin almacenamiento disponible se usan las metas por defecto.
    }
  }

  /// Días consecutivos con al menos un entrenamiento, terminando hoy o ayer.
  int get dayStreak => computeDayStreak(
    _workouts.map((w) => w.finishedAt ?? w.startedAt),
    DateTime.now(),
  );

  /// Tiempo total entrenado en el historial.
  Duration get totalDuration =>
      _workouts.fold(Duration.zero, (sum, w) => sum + w.duration);

  /// Tiempo entrenado en la semana actual (lunes a domingo).
  Duration get thisWeekDuration {
    final start = FirestoreService.weekStartOf(DateTime.now());
    return durationBetween(
      _workouts,
      start,
      start.add(const Duration(days: 7)),
    );
  }

  /// Sesiones terminadas el día [day] (fecha local).
  List<WorkoutSession> sessionsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return [
      for (final w in _workouts)
        if (_isBetween(_dateOf(w), start, end)) w,
    ];
  }

  /// Días (a medianoche, hora local) en los que hubo al menos una sesión.
  Set<DateTime> get trainedDays => {
    for (final w in _workouts)
      DateTime(_dateOf(w).year, _dateOf(w).month, _dateOf(w).day),
  };

  /// La sesión anterior más reciente comparable con [session]: la misma
  /// rutina y el mismo día (las sesiones antiguas no guardaban el día), o
  /// bien otro entrenamiento libre.
  WorkoutSession? previousComparable(WorkoutSession session) {
    final finished = _dateOf(session);
    for (final w in _workouts) {
      if (w.id == session.id || !_dateOf(w).isBefore(finished)) continue;
      if (w.routineId != session.routineId) continue;
      final sameDay =
          w.routineDayId == session.routineDayId ||
          w.routineDayId.isEmpty ||
          session.routineDayId.isEmpty;
      if (sameDay) return w;
    }
    return null;
  }

  /// Registro del ejercicio en la última sesión anterior a [before] que lo
  /// incluye (para comparar en el resumen).
  WorkoutExerciseRecord? previousRecordFor(
    String exerciseId, {
    required DateTime before,
    String? excludingSessionId,
  }) {
    for (final w in _workouts) {
      if (w.id == excludingSessionId || !_dateOf(w).isBefore(before)) {
        continue;
      }
      for (final record in w.exercises) {
        if (record.exerciseId == exerciseId) return record;
      }
    }
    return null;
  }

  /// Peso máximo de [exerciseId] por semana, de la más antigua a la más
  /// reciente (solo semanas en que se entrenó), como máximo [limit].
  List<({DateTime weekStart, double bestWeight})> weeklyBestWeight(
    String exerciseId, {
    int limit = 8,
  }) {
    final byWeek = <DateTime, double>{};
    for (final w in _workouts) {
      for (final record in w.exercises) {
        if (record.exerciseId != exerciseId) continue;
        final week = FirestoreService.weekStartOf(_dateOf(w));
        for (final set in record.sets) {
          if (!set.completed) continue;
          if (set.weight > (byWeek[week] ?? 0)) byWeek[week] = set.weight;
        }
      }
    }
    final weeks = byWeek.keys.toList()..sort();
    final recent = weeks.length > limit
        ? weeks.sublist(weeks.length - limit)
        : weeks;
    return [for (final w in recent) (weekStart: w, bestWeight: byWeek[w]!)];
  }

  static DateTime _dateOf(WorkoutSession w) =>
      (w.finishedAt ?? w.startedAt).toLocal();

  static bool _isBetween(DateTime date, DateTime from, DateTime to) =>
      !date.isBefore(from) && date.isBefore(to);

  @visibleForTesting
  static Duration durationBetween(
    List<WorkoutSession> workouts,
    DateTime from,
    DateTime to,
  ) {
    var total = Duration.zero;
    for (final workout in workouts) {
      if (_isBetween(_dateOf(workout), from, to)) total += workout.duration;
    }
    return total;
  }

  /// Series de peso máximo por ejercicio, en orden cronológico (del más
  /// antiguo al más reciente), para que la tendencia se lea de izquierda a
  /// derecha.
  List<ExerciseWeightSeries> exerciseWeightSeries() {
    final dates = <String, List<DateTime>>{};
    final weights = <String, List<double>>{};
    final names = <String, String>{};
    for (final workout in _workouts.reversed) {
      for (final record in workout.exercises) {
        final maxBySet = record.sets
            .where((s) => s.completed)
            .fold<double>(0, (max, s) => s.weight > max ? s.weight : max);
        if (maxBySet <= 0) continue;
        dates
            .putIfAbsent(record.exerciseId, () => [])
            .add(workout.finishedAt ?? workout.startedAt);
        weights.putIfAbsent(record.exerciseId, () => []).add(maxBySet);
        names[record.exerciseId] = record.exerciseName;
      }
    }
    return weights.keys
        .map(
          (id) => (
            exerciseId: id,
            exerciseName: names[id] ?? id,
            dates: dates[id]!,
            weights: weights[id]!,
          ),
        )
        .toList();
  }

  @visibleForTesting
  static List<WeeklyGoal> buildWeeklyGoals({
    required PeriodTotals week,
    required double volumeGoal,
    required int setsGoal,
    required int workoutsGoal,
    required DateTime now,
  }) {
    // Lunes = 1/7 de la semana transcurrida … domingo = 7/7.
    final fraction = now.weekday / DateTime.daysPerWeek;
    return [
      WeeklyGoal(
        title: 'Volumen semanal',
        unit: 'kg',
        target: volumeGoal,
        current: week.volume,
        expectedFraction: fraction,
      ),
      WeeklyGoal(
        title: 'Series semanales',
        unit: 'series',
        target: setsGoal.toDouble(),
        current: week.sets.toDouble(),
        expectedFraction: fraction,
      ),
      WeeklyGoal(
        title: 'Entrenamientos',
        unit: 'entrenamientos',
        target: workoutsGoal.toDouble(),
        current: week.workouts.toDouble(),
        expectedFraction: fraction,
      ),
    ];
  }

  @visibleForTesting
  static PeriodTotals totalsBetween(
    List<WorkoutSession> workouts,
    DateTime from,
    DateTime to,
  ) {
    var count = 0;
    var volume = 0.0;
    var sets = 0;
    for (final workout in workouts) {
      final date = (workout.finishedAt ?? workout.startedAt).toLocal();
      if (date.isBefore(from) || !date.isBefore(to)) continue;
      count++;
      volume += workout.totalVolume;
      sets += workout.totalSets;
    }
    return (workouts: count, volume: volume, sets: sets);
  }

  @visibleForTesting
  static int computeDayStreak(Iterable<DateTime> dates, DateTime now) {
    final days = dates.map((d) {
      final local = d.toLocal();
      return DateTime(local.year, local.month, local.day);
    }).toSet();
    if (days.isEmpty) return 0;
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }
}

class _ExerciseAggregate {
  String name = '';
  int workoutCount = 0;
  int totalSets = 0;
  int totalReps = 0;
  double bestWeight = 0;
  int bestReps = 0;
  double totalVolume = 0;
  double firstWeight = 0;
  double latestWeight = 0;
}
