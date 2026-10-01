import '../core/utils/firestore_utils.dart';
import 'workout_set_model.dart';

/// Series de un ejercicio dentro de una sesión.
///
/// Encapsulado: campos privados y lista de series inmutable.
class WorkoutExerciseRecord {
  WorkoutExerciseRecord({
    required this._exerciseId,
    required this._exerciseName,
    required List<WorkoutSet> sets,
  }) : _sets = List.unmodifiable(sets);

  final String _exerciseId;
  final String _exerciseName;
  final List<WorkoutSet> _sets;

  String get exerciseId => _exerciseId;
  String get exerciseName => _exerciseName;
  List<WorkoutSet> get sets => _sets;

  /// Volumen del ejercicio: suma de peso × repeticiones de las series
  /// completadas.
  double get volume =>
      _sets.fold(0, (sum, s) => sum + (s.completed ? s.volume : 0));

  int get totalReps =>
      _sets.fold(0, (sum, s) => sum + (s.completed ? s.repetitions : 0));

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': _exerciseId,
      'exerciseName': _exerciseName,
      'sets': _sets.map((s) => s.toMap()).toList(),
    };
  }

  factory WorkoutExerciseRecord.fromMap(Map<String, dynamic> map) {
    return WorkoutExerciseRecord(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      sets: (map['sets'] as List<dynamic>? ?? [])
          .map((e) => WorkoutSet.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Sesión de entrenamiento completada (el papel de `RegistroEntrenamiento`).
///
/// Encapsulada: campos privados de solo lectura y lista de ejercicios
/// inmutable. Una sesión guardada no se modifica.
class WorkoutSession {
  WorkoutSession({
    required this._id,
    required this._userId,
    this._routineId = '',
    this._routineName = 'Entrenamiento libre',
    this._routineDayId = '',
    required this._startedAt,
    this._finishedAt,
    this._duration = Duration.zero,
    this._totalVolume = 0,
    this._totalSets = 0,
    this._totalReps = 0,
    this._totalExercises = 0,
    this._notes = '',
    List<WorkoutExerciseRecord> exercises = const [],
  }) : _exercises = List.unmodifiable(exercises);

  final String _id;
  final String _userId;
  final String _routineId;
  final String _routineName;

  /// Día de la rutina que se entrenó (vacío en libres o en sesiones
  /// antiguas).
  final String _routineDayId;
  final DateTime _startedAt;
  final DateTime? _finishedAt;
  final Duration _duration;
  final double _totalVolume;
  final int _totalSets;
  final int _totalReps;
  final int _totalExercises;
  final String _notes;
  final List<WorkoutExerciseRecord> _exercises;

  String get id => _id;
  String get userId => _userId;
  String get routineId => _routineId;
  String get routineName => _routineName;
  String get routineDayId => _routineDayId;
  DateTime get startedAt => _startedAt;
  DateTime? get finishedAt => _finishedAt;
  Duration get duration => _duration;
  double get totalVolume => _totalVolume;
  int get totalSets => _totalSets;
  int get totalReps => _totalReps;
  int get totalExercises => _totalExercises;
  String get notes => _notes;
  List<WorkoutExerciseRecord> get exercises => _exercises;

  Map<String, dynamic> toMap() {
    return {
      'userId': _userId,
      'routineId': _routineId,
      'routineName': _routineName,
      'routineDayId': _routineDayId,
      'startedAt': _startedAt,
      'finishedAt': _finishedAt ?? DateTime.now(),
      'durationSeconds': _duration.inSeconds,
      'totalVolume': _totalVolume,
      'totalSets': _totalSets,
      'totalReps': _totalReps,
      'totalExercises': _totalExercises,
      'notes': _notes,
      'exercises': _exercises.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkoutSession.fromMap(String id, Map<String, dynamic> map) {
    final started = firestoreDateFrom(map['startedAt']) ?? DateTime.now();
    final finished = firestoreDateFrom(map['finishedAt']);
    return WorkoutSession(
      id: id,
      userId: map['userId'] as String? ?? '',
      routineId: map['routineId'] as String? ?? '',
      routineName: map['routineName'] as String? ?? 'Entrenamiento libre',
      routineDayId: map['routineDayId'] as String? ?? '',
      startedAt: started,
      finishedAt: finished,
      duration: Duration(seconds: map['durationSeconds'] as int? ?? 0),
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0,
      totalSets: map['totalSets'] as int? ?? 0,
      totalReps: map['totalReps'] as int? ?? 0,
      totalExercises: map['totalExercises'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      exercises: (map['exercises'] as List<dynamic>? ?? [])
          .map((e) => WorkoutExerciseRecord.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
