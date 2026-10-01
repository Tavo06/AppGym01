import '../core/utils/firestore_utils.dart';
import 'exercise_model.dart';
import 'routine_day_model.dart';

/// Rutina de entrenamiento (el papel de `Rutina` en la especificación).
///
/// Se organiza en días ([RoutineDay]); cada día tiene sus ejercicios con su
/// plan (series, repeticiones, peso, descanso y notas). [exercises] sigue
/// existiendo: son los IDs de todos los ejercicios, sin repetir y en orden,
/// para compatibilidad con las rutinas antiguas (que solo tenían esa lista).
///
/// En memoria la rutina se relaciona con los objetos [ExerciseModel]
/// completos mediante [withExercises].
///
/// Encapsulada: campos privados de solo lectura y listas inmutables. Los
/// cambios se hacen creando copias ([copyWith], [withoutExercise]).
class WorkoutRoutine {
  WorkoutRoutine({
    required this._id,
    required this._userId,
    required this._name,
    this._description = '',
    this._goal = '',
    List<String> exercises = const [],
    List<RoutineDay> days = const [],
    this._createdAt,
    this._updatedAt,
    List<ExerciseModel> exerciseDetails = const [],
  }) : _days = List.unmodifiable(_resolveDays(days, exercises)),
       _exercises = List.unmodifiable(
         days.isNotEmpty ? _idsOf(days) : exercises,
       ),
       _exerciseDetails = List.unmodifiable(exerciseDetails);

  final String _id;
  final String _userId;
  final String _name;
  final String _description;
  final String _goal;
  final List<String> _exercises;
  final List<RoutineDay> _days;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  /// Ejercicios resueltos, en el orden de la rutina. No se serializa.
  final List<ExerciseModel> _exerciseDetails;

  static List<RoutineDay> _resolveDays(
    List<RoutineDay> days,
    List<String> exercises,
  ) {
    if (days.isNotEmpty) return days;
    if (exercises.isEmpty) return const [];
    return [RoutineDay.fromExerciseIds(exercises)];
  }

  /// IDs de todos los días, sin repetir y en orden de aparición.
  static List<String> _idsOf(List<RoutineDay> days) {
    final ids = <String>[];
    for (final day in days) {
      for (final id in day.exerciseIds) {
        if (!ids.contains(id)) ids.add(id);
      }
    }
    return ids;
  }

  String get id => _id;
  String get userId => _userId;
  String get name => _name;
  String get description => _description;
  String get goal => _goal;

  /// IDs de los ejercicios, en orden (lista de solo lectura).
  List<String> get exercises => _exercises;

  /// Días de la rutina (lista de solo lectura).
  List<RoutineDay> get days => _days;
  DateTime? get createdAt => _createdAt;
  DateTime? get updatedAt => _updatedAt;

  List<ExerciseModel> get exerciseDetails => _exerciseDetails;

  /// Grupos musculares que trabaja la rutina, sin repetir.
  Set<String> get muscleGroups =>
      _exerciseDetails.map((e) => e.muscleGroup).toSet();

  /// Series planificadas en toda la rutina.
  int get totalSets => _days.fold(0, (sum, d) => sum + d.totalSets);

  /// Plan del ejercicio (el primero que aparezca en los días).
  RoutineExercise? planFor(String exerciseId) {
    for (final day in _days) {
      final plan = day.planFor(exerciseId);
      if (plan != null) return plan;
    }
    return null;
  }

  RoutineDay? dayById(String dayId) {
    for (final day in _days) {
      if (day.id == dayId) return day;
    }
    return null;
  }

  /// Devuelve una copia relacionada con sus ejercicios completos. Los IDs que
  /// ya no existen en [catalog] (ejercicios borrados) se omiten.
  WorkoutRoutine withExercises(List<ExerciseModel> catalog) {
    final byId = {for (final e in catalog) e.id: e};
    return _copy(
      exerciseDetails: [
        for (final exerciseId in _exercises)
          if (byId[exerciseId] != null) byId[exerciseId]!,
      ],
    );
  }

  /// Rutina de un solo día, lista para entrenar. Conserva el ID de la
  /// rutina; si tiene varios días, el nombre indica cuál se entrena.
  WorkoutRoutine forDay(RoutineDay day) {
    final ids = day.exerciseIds.toSet();
    return WorkoutRoutine(
      id: _id,
      userId: _userId,
      name: _days.length > 1 ? '$_name · ${day.name}' : _name,
      description: _description,
      goal: _goal,
      days: [day],
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      exerciseDetails: [
        for (final id in day.exerciseIds)
          for (final e in _exerciseDetails)
            if (e.id == id && ids.contains(id)) e,
      ],
    );
  }

  /// Copia de la rutina sin el ejercicio [exerciseId] (al borrarlo del
  /// catálogo). Se quita de todos los días.
  WorkoutRoutine withoutExercise(String exerciseId) => copyWith(
    days: [
      for (final day in _days)
        day.copyWith(
          exercises: [
            for (final e in day.exercises)
              if (e.exerciseId != exerciseId) e,
          ],
        ),
    ],
  );

  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'userId': _userId,
      'name': _name,
      'description': _description,
      'goal': _goal,
      'exercises': _exercises,
      'days': [for (final day in _days) day.toMap()],
      'createdAt': _createdAt ?? now,
      'updatedAt': _updatedAt ?? now,
    };
  }

  factory WorkoutRoutine.fromMap(String id, Map<String, dynamic> map) {
    final rawDays = map['days'] as List<dynamic>? ?? const [];
    return WorkoutRoutine(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      goal: map['goal'] as String? ?? '',
      exercises: (map['exercises'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      days: [
        for (var i = 0; i < rawDays.length; i++)
          RoutineDay.fromMap(Map<String, dynamic>.from(rawDays[i] as Map), i),
      ],
      createdAt: firestoreDateFrom(map['createdAt']),
      updatedAt: firestoreDateFrom(map['updatedAt']),
    );
  }

  /// [exercises] (solo IDs) se mantiene por compatibilidad: con un único
  /// día, reemplaza sus ejercicios conservando el plan de los que siguen.
  /// [days] tiene prioridad si se pasan ambos.
  WorkoutRoutine copyWith({
    String? name,
    String? description,
    String? goal,
    List<String>? exercises,
    List<RoutineDay>? days,
  }) {
    var newDays = days;
    if (newDays == null && exercises != null) {
      newDays = _daysFromIds(exercises);
    }
    return WorkoutRoutine(
      id: _id,
      userId: _userId,
      name: name ?? _name,
      description: description ?? _description,
      goal: goal ?? _goal,
      days: newDays ?? _days,
      exercises: newDays == null ? _exercises : const [],
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      // Si cambian los ejercicios, los detalles anteriores ya no
      // corresponden.
      exerciseDetails: newDays == null ? _exerciseDetails : const [],
    );
  }

  List<RoutineDay> _daysFromIds(List<String> ids) {
    if (ids.isEmpty) return const [];
    if (_days.length > 1) {
      // Varios días: se quitan los IDs eliminados y los nuevos van al último.
      final kept = <RoutineDay>[
        for (final day in _days)
          day.copyWith(
            exercises: [
              for (final e in day.exercises)
                if (ids.contains(e.exerciseId)) e,
            ],
          ),
      ];
      final present = _idsOf(kept).toSet();
      final added = [
        for (final id in ids)
          if (!present.contains(id)) RoutineExercise(exerciseId: id),
      ];
      final last = kept.last;
      kept[kept.length - 1] = last.copyWith(
        exercises: [...last.exercises, ...added],
      );
      return kept;
    }
    final base = _days.isEmpty
        ? RoutineDay.fromExerciseIds(const [])
        : _days.first;
    return [
      base.copyWith(
        exercises: [
          for (final id in ids)
            base.planFor(id) ?? RoutineExercise(exerciseId: id),
        ],
      ),
    ];
  }

  WorkoutRoutine _copy({List<ExerciseModel>? exerciseDetails}) {
    return WorkoutRoutine(
      id: _id,
      userId: _userId,
      name: _name,
      description: _description,
      goal: _goal,
      days: _days,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      exerciseDetails: exerciseDetails ?? _exerciseDetails,
    );
  }
}
