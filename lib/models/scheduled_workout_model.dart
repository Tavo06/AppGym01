import '../core/utils/firestore_utils.dart';
import 'workout_model.dart';

/// Entrenamiento programado en el calendario personal: una rutina (y uno
/// de sus días) para una fecha.
///
/// Encapsulado: campos privados de solo lectura.
class ScheduledWorkout {
  ScheduledWorkout({
    required this._id,
    required DateTime date,
    required this._routineId,
    required this._routineName,
    this._dayId = '',
    this._dayName = '',
    this._notes = '',
    this._createdAt,
  }) : _date = DateTime(date.year, date.month, date.day);

  final String _id;

  /// Fecha (sin hora) en que se planea entrenar.
  final DateTime _date;
  final String _routineId;
  final String _routineName;
  final String _dayId;
  final String _dayName;
  final String _notes;
  final DateTime? _createdAt;

  String get id => _id;
  DateTime get date => _date;
  String get routineId => _routineId;
  String get routineName => _routineName;
  String get dayId => _dayId;
  String get dayName => _dayName;
  String get notes => _notes;
  DateTime? get createdAt => _createdAt;

  /// Nombre que se muestra: "Rutina · Día".
  String get title =>
      _dayName.isEmpty ? _routineName : '$_routineName · $_dayName';

  /// Se considera hecho si ese día hay una sesión de la misma rutina (y del
  /// mismo día de rutina, cuando la sesión lo guarda).
  bool isCompletedBy(Iterable<WorkoutSession> sessionsOfDay) {
    for (final session in sessionsOfDay) {
      if (session.routineId != _routineId) continue;
      if (_dayId.isEmpty ||
          session.routineDayId.isEmpty ||
          session.routineDayId == _dayId) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toMap() => {
    'date': _date,
    'routineId': _routineId,
    'routineName': _routineName,
    'dayId': _dayId,
    'dayName': _dayName,
    'notes': _notes,
    'createdAt': _createdAt ?? DateTime.now(),
  };

  factory ScheduledWorkout.fromMap(String id, Map<String, dynamic> map) {
    return ScheduledWorkout(
      id: id,
      date: firestoreDateFrom(map['date']) ?? DateTime.now(),
      routineId: map['routineId'] as String? ?? '',
      routineName: map['routineName'] as String? ?? '',
      dayId: map['dayId'] as String? ?? '',
      dayName: map['dayName'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: firestoreDateFrom(map['createdAt']),
    );
  }
}
