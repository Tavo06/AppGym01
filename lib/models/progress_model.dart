import '../core/utils/firestore_utils.dart';

/// Totales acumulados de una semana (lunes a domingo).
///
/// Encapsulado: los totales son privados y solo cambian a través de
/// [registerSession], que valida los valores.
class WeeklyProgress {
  WeeklyProgress({
    required this._id,
    required this._userId,
    required this._weekId,
    DateTime? weekStart,
    this._workouts = 0,
    this._totalSets = 0,
    this._totalReps = 0,
    this._totalVolume = 0,
    this._updatedAt,
  }) : _weekStart = weekStart ?? DateTime.now();

  final String _id;
  final String _userId;
  final String _weekId;
  final DateTime _weekStart;
  int _workouts;
  int _totalSets;
  int _totalReps;
  double _totalVolume;
  DateTime? _updatedAt;

  String get id => _id;
  String get userId => _userId;
  String get weekId => _weekId;
  DateTime get weekStart => _weekStart;
  int get workouts => _workouts;
  int get totalSets => _totalSets;
  int get totalReps => _totalReps;
  double get totalVolume => _totalVolume;
  DateTime? get updatedAt => _updatedAt;

  /// Suma un entrenamiento a la semana. Los valores negativos se rechazan.
  void registerSession({
    required int sets,
    required int reps,
    required double volume,
  }) {
    if (sets < 0 || reps < 0 || volume < 0) {
      throw ArgumentError('Los totales de una sesión no pueden ser negativos.');
    }
    _workouts += 1;
    _totalSets += sets;
    _totalReps += reps;
    _totalVolume += volume;
    _updatedAt = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': _userId,
      'weekId': _weekId,
      'weekStart': _weekStart,
      'workouts': _workouts,
      'totalSets': _totalSets,
      'totalReps': _totalReps,
      'totalVolume': _totalVolume,
      'updatedAt': _updatedAt ?? DateTime.now(),
    };
  }

  factory WeeklyProgress.fromMap(String id, Map<String, dynamic> map) {
    return WeeklyProgress(
      id: id,
      userId: map['userId'] as String? ?? '',
      weekId: map['weekId'] as String? ?? '',
      weekStart: firestoreDateFrom(map['weekStart']) ?? DateTime.now(),
      workouts: map['workouts'] as int? ?? 0,
      totalSets: map['totalSets'] as int? ?? 0,
      totalReps: map['totalReps'] as int? ?? 0,
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0,
      updatedAt: firestoreDateFrom(map['updatedAt']),
    );
  }
}

/// Estadísticas generales calculadas por `ProgressProvider` (inmutables).
class ProgressModel {
  ProgressModel({
    this._totalWorkouts = 0,
    this._totalVolume = 0,
    this._totalSets = 0,
    this._totalReps = 0,
    this._totalExercises = 0,
    this._recordCount = 0,
    List<WeeklyProgress> weekly = const [],
    List<double> weekVolumeByDay = const [],
    List<int> weekWorkoutsByDay = const [],
    List<int> weekSetsByDay = const [],
  }) : _weekly = List.unmodifiable(weekly),
       _weekVolumeByDay = List.unmodifiable(weekVolumeByDay),
       _weekWorkoutsByDay = List.unmodifiable(weekWorkoutsByDay),
       _weekSetsByDay = List.unmodifiable(weekSetsByDay);

  final int _totalWorkouts;
  final double _totalVolume;
  final int _totalSets;
  final int _totalReps;
  final int _totalExercises;
  final int _recordCount;
  final List<WeeklyProgress> _weekly;
  final List<double> _weekVolumeByDay;
  final List<int> _weekWorkoutsByDay;
  final List<int> _weekSetsByDay;

  int get totalWorkouts => _totalWorkouts;
  double get totalVolume => _totalVolume;
  int get totalSets => _totalSets;
  int get totalReps => _totalReps;
  int get totalExercises => _totalExercises;
  int get recordCount => _recordCount;
  List<WeeklyProgress> get weekly => _weekly;

  /// Valores de la semana actual por día (índice 0 = lunes).
  List<double> get weekVolumeByDay => _weekVolumeByDay;
  List<int> get weekWorkoutsByDay => _weekWorkoutsByDay;
  List<int> get weekSetsByDay => _weekSetsByDay;
}

/// Progreso acumulado de un ejercicio en todo el historial (inmutable).
class ExerciseProgress {
  const ExerciseProgress({
    required this._exerciseId,
    required this._exerciseName,
    this._workoutCount = 0,
    this._totalSets = 0,
    this._totalReps = 0,
    this._bestWeight = 0,
    this._bestReps = 0,
    this._totalVolume = 0,
    this._firstWeight = 0,
    this._latestWeight = 0,
  });

  final String _exerciseId;
  final String _exerciseName;
  final int _workoutCount;
  final int _totalSets;
  final int _totalReps;
  final double _bestWeight;
  final int _bestReps;
  final double _totalVolume;
  final double _firstWeight;
  final double _latestWeight;

  String get exerciseId => _exerciseId;
  String get exerciseName => _exerciseName;
  int get workoutCount => _workoutCount;
  int get totalSets => _totalSets;
  int get totalReps => _totalReps;

  /// Mejor serie: más peso y, a igual peso, más repeticiones.
  double get bestWeight => _bestWeight;
  int get bestReps => _bestReps;
  double get totalVolume => _totalVolume;

  /// Peso máximo de la primera y de la última sesión con este ejercicio.
  double get firstWeight => _firstWeight;
  double get latestWeight => _latestWeight;

  /// Variación del peso máximo entre la primera y la última sesión, en %.
  double get progressPercent {
    if (_firstWeight <= 0) return 0;
    return (_latestWeight - _firstWeight) / _firstWeight * 100;
  }
}
