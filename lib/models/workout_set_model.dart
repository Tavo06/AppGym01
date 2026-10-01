import '../core/utils/firestore_utils.dart';

/// Una serie registrada: peso × repeticiones.
///
/// Encapsulada: campos privados de solo lectura. Para cambiarla se crea una
/// copia con [copyWith] o [renumbered].
class WorkoutSet {
  WorkoutSet({
    required this._setNumber,
    required this._weight,
    required this._repetitions,
    this._restSeconds = 0,
    this._completed = true,
    this._createdAt,
  });

  final int _setNumber;
  final double _weight;
  final int _repetitions;
  final int _restSeconds;
  final bool _completed;
  final DateTime? _createdAt;

  int get setNumber => _setNumber;
  double get weight => _weight;
  int get repetitions => _repetitions;
  int get restSeconds => _restSeconds;
  bool get completed => _completed;
  DateTime? get createdAt => _createdAt;

  /// Volumen de la serie: peso × repeticiones.
  double get volume => _weight * _repetitions;

  /// Una serie supera a otra si tiene más peso o, con el mismo peso, más
  /// repeticiones. Se usa para elegir la mejor serie de cada ejercicio.
  bool outperforms(WorkoutSet other) =>
      _weight > other._weight ||
      (_weight == other._weight && _repetitions > other._repetitions);

  /// Copia con otro número de serie (al quitar una serie se renumeran).
  WorkoutSet renumbered(int setNumber) => WorkoutSet(
    setNumber: setNumber,
    weight: _weight,
    repetitions: _repetitions,
    restSeconds: _restSeconds,
    completed: _completed,
    createdAt: _createdAt,
  );

  Map<String, dynamic> toMap() {
    return {
      'setNumber': _setNumber,
      'weight': _weight,
      'repetitions': _repetitions,
      'restSeconds': _restSeconds,
      'completed': _completed,
      'createdAt': _createdAt ?? DateTime.now(),
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      setNumber: map['setNumber'] as int? ?? 1,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      repetitions: map['repetitions'] as int? ?? 0,
      restSeconds: map['restSeconds'] as int? ?? 0,
      completed: map['completed'] as bool? ?? true,
      createdAt: firestoreDateFrom(map['createdAt']),
    );
  }

  WorkoutSet copyWith({
    double? weight,
    int? repetitions,
    int? restSeconds,
    bool? completed,
  }) {
    return WorkoutSet(
      setNumber: _setNumber,
      weight: weight ?? _weight,
      repetitions: repetitions ?? _repetitions,
      restSeconds: restSeconds ?? _restSeconds,
      completed: completed ?? _completed,
      createdAt: _createdAt,
    );
  }
}
