import '../core/utils/firestore_utils.dart';

/// Mejor marca de un ejercicio: peso × repeticiones y mejor volumen en una
/// sesión.
///
/// Encapsulado: campos privados de solo lectura. Un récord nuevo reemplaza
/// al anterior; no se modifica.
class PersonalRecord {
  PersonalRecord({
    required this._id,
    required this._userId,
    required this._exerciseId,
    required this._exerciseName,
    this._maxWeight = 0,
    this._reps = 0,
    this._bestVolume = 0,
    this._date,
    this._updatedAt,
  });

  final String _id;
  final String _userId;
  final String _exerciseId;
  final String _exerciseName;
  final double _maxWeight;
  final int _reps;

  /// Mayor volumen (peso × repeticiones sumado) del ejercicio en una sesión.
  final double _bestVolume;
  final DateTime? _date;
  final DateTime? _updatedAt;

  String get id => _id;
  String get userId => _userId;
  String get exerciseId => _exerciseId;
  String get exerciseName => _exerciseName;
  double get maxWeight => _maxWeight;
  int get reps => _reps;
  double get bestVolume => _bestVolume;
  DateTime? get date => _date;
  DateTime? get updatedAt => _updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': _userId,
      'exerciseId': _exerciseId,
      'exerciseName': _exerciseName,
      'maxWeight': _maxWeight,
      'reps': _reps,
      'bestVolume': _bestVolume,
      'date': _date ?? DateTime.now(),
      'updatedAt': _updatedAt ?? DateTime.now(),
    };
  }

  factory PersonalRecord.fromMap(String id, Map<String, dynamic> map) {
    return PersonalRecord(
      id: id,
      userId: map['userId'] as String? ?? '',
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      maxWeight: (map['maxWeight'] as num?)?.toDouble() ?? 0,
      reps: map['reps'] as int? ?? 0,
      bestVolume: (map['bestVolume'] as num?)?.toDouble() ?? 0,
      date: firestoreDateFrom(map['date']),
      updatedAt: firestoreDateFrom(map['updatedAt']),
    );
  }

  /// Indica si una marca ([weight] kg × [reps] repeticiones) supera este
  /// récord: más peso, o el mismo peso con más repeticiones.
  /// Ejemplo: 80 kg × 8 supera a 80 kg × 6, pero 79 kg × 12 no supera 80 × 6.
  bool isBetterThan(double weight, [int reps = 0]) {
    if (weight > _maxWeight) return true;
    if (weight == _maxWeight && reps > _reps) return true;
    return false;
  }

  /// Orden de "mejor a peor": más peso primero y, a igual peso, más reps.
  static int compareBest(PersonalRecord a, PersonalRecord b) {
    final byWeight = b._maxWeight.compareTo(a._maxWeight);
    return byWeight != 0 ? byWeight : b._reps.compareTo(a._reps);
  }
}
