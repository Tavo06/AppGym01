import 'package:flutter/foundation.dart';

import '../models/routine_day_model.dart';
import '../models/routine_model.dart';
import '../models/scheduled_workout_model.dart';
import '../services/app_firebase.dart';
import '../services/firestore_service.dart';
import 'progress_provider.dart';

/// Estado del calendario personal: los entrenamientos programados del
/// usuario autenticado. Las sesiones realizadas vienen de
/// [ProgressProvider]; aquí solo se guarda lo planificado.
class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider({FirestoreService? firestore, this._currentUid})
    : _firestoreOverride = firestore;

  final FirestoreService? _firestoreOverride;
  final String? Function()? _currentUid;
  FirestoreService? _lazyFirestore;
  FirestoreService get _firestore =>
      _firestoreOverride ?? (_lazyFirestore ??= FirestoreService());

  List<ScheduledWorkout> _items = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  /// Se incrementa en cada `reset()` para descartar cargas de otra cuenta.
  int _generation = 0;

  List<ScheduledWorkout> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  String? get _uid =>
      _currentUid != null ? _currentUid() : AppFirebase.auth.currentUser?.uid;

  /// Entrenamientos programados para el día [day].
  List<ScheduledWorkout> forDay(DateTime day) => [
    for (final item in _items)
      if (_sameDay(item.date, day)) item,
  ];

  /// Días (a medianoche) con algo programado.
  Set<DateTime> get scheduledDays => {for (final item in _items) item.date};

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final items = await _firestore.getScheduledWorkouts(uid);
      if (generation != _generation) return;
      _items = items;
      _loaded = true;
    } catch (error) {
      if (generation != _generation) return;
      _error = ProgressProvider.describeError(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Programa [day] de [routine] el día [date] y, si [weeks] > 1, la misma
  /// sesión las semanas siguientes. Devuelve cuántos se crearon.
  Future<int> schedule({
    required WorkoutRoutine routine,
    required RoutineDay? day,
    required DateTime date,
    int weeks = 1,
    String notes = '',
  }) async {
    final uid = _uid;
    if (uid == null) return 0;
    final count = weeks < 1 ? 1 : weeks;
    final created = <ScheduledWorkout>[];
    var week = 0;
    // do-while: la primera fecha se programa siempre; las demás solo si se
    // pidió repetir semanalmente.
    do {
      created.add(
        ScheduledWorkout(
          id: _firestore.newDocId,
          date: DateTime(date.year, date.month, date.day + 7 * week),
          routineId: routine.id,
          routineName: routine.name,
          dayId: day?.id ?? '',
          dayName: routine.days.length > 1 ? (day?.name ?? '') : '',
          notes: notes,
          createdAt: DateTime.now(),
        ),
      );
      week++;
    } while (week < count);
    await _firestore.saveScheduledWorkouts(uid, created);
    _items = [..._items, ...created]..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    return created.length;
  }

  Future<void> remove(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.deleteScheduledWorkout(uid, id);
    _items = [
      for (final item in _items)
        if (item.id != id) item,
    ];
    notifyListeners();
  }

  /// Borra los datos en memoria al cerrar sesión.
  void reset() {
    _generation++;
    _items = [];
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
