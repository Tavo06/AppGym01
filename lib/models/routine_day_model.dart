import '../core/constants/app_constants.dart';

/// Plan de un ejercicio dentro de un día de rutina: series × repeticiones,
/// peso objetivo, descanso y notas.
///
/// Encapsulado e inmutable: los cambios se hacen con [copyWith].
class RoutineExercise {
  RoutineExercise({
    required this._exerciseId,
    int sets = defaultSets,
    int reps = defaultReps,
    double weight = 0,
    int restSeconds = AppConstants.defaultRestSeconds,
    this._notes = '',
  }) : _sets = sets < 1 ? 1 : sets,
       _reps = reps < 1 ? 1 : reps,
       _weight = weight < 0 ? 0 : weight,
       _restSeconds = restSeconds < 0 ? 0 : restSeconds;

  static const int defaultSets = 3;
  static const int defaultReps = 10;

  final String _exerciseId;
  final int _sets;
  final int _reps;
  final double _weight;
  final int _restSeconds;
  final String _notes;

  String get exerciseId => _exerciseId;
  int get sets => _sets;
  int get reps => _reps;
  double get weight => _weight;
  int get restSeconds => _restSeconds;
  String get notes => _notes;

  /// Volumen planificado: series × repeticiones × peso.
  double get plannedVolume => _sets * _reps * _weight;

  RoutineExercise copyWith({
    int? sets,
    int? reps,
    double? weight,
    int? restSeconds,
    String? notes,
  }) {
    return RoutineExercise(
      exerciseId: _exerciseId,
      sets: sets ?? _sets,
      reps: reps ?? _reps,
      weight: weight ?? _weight,
      restSeconds: restSeconds ?? _restSeconds,
      notes: notes ?? _notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'exerciseId': _exerciseId,
    'sets': _sets,
    'reps': _reps,
    'weight': _weight,
    'restSeconds': _restSeconds,
    'notes': _notes,
  };

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      sets: map['sets'] as int? ?? defaultSets,
      reps: map['reps'] as int? ?? defaultReps,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      restSeconds:
          map['restSeconds'] as int? ?? AppConstants.defaultRestSeconds,
      notes: map['notes'] as String? ?? '',
    );
  }
}

/// Un día de una rutina ("Día 1", "Pierna"…) con sus ejercicios en orden.
class RoutineDay {
  RoutineDay({
    required this._id,
    required this._name,
    List<RoutineExercise> exercises = const [],
  }) : _exercises = List.unmodifiable(exercises);

  /// Día único para rutinas guardadas antes de existir los días: solo
  /// tenían la lista de IDs de ejercicios.
  factory RoutineDay.fromExerciseIds(List<String> ids) => RoutineDay(
    id: legacyDayId,
    name: 'Día 1',
    exercises: [for (final id in ids) RoutineExercise(exerciseId: id)],
  );

  static const String legacyDayId = 'dia-1';

  final String _id;
  final String _name;
  final List<RoutineExercise> _exercises;

  String get id => _id;
  String get name => _name;
  List<RoutineExercise> get exercises => _exercises;

  List<String> get exerciseIds => [for (final e in _exercises) e.exerciseId];

  /// Series planificadas en el día.
  int get totalSets => _exercises.fold(0, (sum, e) => sum + e.sets);

  /// Plan del ejercicio [exerciseId] en este día, si está.
  RoutineExercise? planFor(String exerciseId) {
    for (final exercise in _exercises) {
      if (exercise.exerciseId == exerciseId) return exercise;
    }
    return null;
  }

  RoutineDay copyWith({String? name, List<RoutineExercise>? exercises}) {
    return RoutineDay(
      id: _id,
      name: name ?? _name,
      exercises: exercises ?? _exercises,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': _id,
    'name': _name,
    'exercises': [for (final e in _exercises) e.toMap()],
  };

  factory RoutineDay.fromMap(Map<String, dynamic> map, int index) {
    return RoutineDay(
      id: map['id'] as String? ?? 'dia-${index + 1}',
      name: map['name'] as String? ?? 'Día ${index + 1}',
      exercises: [
        for (final e in map['exercises'] as List<dynamic>? ?? const [])
          RoutineExercise.fromMap(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}
