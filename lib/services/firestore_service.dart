import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/exercise_model.dart';
import '../models/personal_record_model.dart';
import '../models/progress_model.dart';
import '../models/routine_model.dart';
import '../models/scheduled_workout_model.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import '../models/workout_set_model.dart';
import 'app_firebase.dart';

class NewRecordInfo {
  const NewRecordInfo({
    required this.exerciseId,
    required this.exerciseName,
    required this.previousWeight,
    required this.newWeight,
    required this.reps,
    this.previousReps = 0,
    this.isWeightRecord = true,
    this.isVolumeRecord = false,
    this.newVolume = 0,
    this.previousVolume = 0,
  });

  final String exerciseId;
  final String exerciseName;
  final double previousWeight;
  final double newWeight;
  final int reps;
  final int previousReps;

  /// Mejoró la mejor serie: más peso, o el mismo peso con más repeticiones.
  final bool isWeightRecord;

  /// Mejoró el volumen del ejercicio en una sesión.
  final bool isVolumeRecord;
  final double newVolume;
  final double previousVolume;

  /// `true` si el ejercicio no tenía ningún récord previo.
  bool get isFirst => previousWeight <= 0;

  /// Récord por repeticiones: mismo peso que antes, más repeticiones.
  bool get isRepsRecord =>
      isWeightRecord && !isFirst && newWeight == previousWeight;
}

class WorkoutSaveResult {
  const WorkoutSaveResult({
    required this.workoutId,
    this.session,
    this.newRecords = const [],
  });

  final String workoutId;

  /// La sesión completada tal como se guardó en Firestore.
  final WorkoutSession? session;
  final List<NewRecordInfo> newRecords;
}

class FirestoreService {
  final FirebaseFirestore _db = AppFirebase.firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.collectionUsers).doc(uid);

  CollectionReference<Map<String, dynamic>> _routinesRef(String uid) =>
      _userRef(uid).collection(AppConstants.subRoutines);

  CollectionReference<Map<String, dynamic>> _exercisesRef(String uid) =>
      _userRef(uid).collection(AppConstants.subExercises);

  CollectionReference<Map<String, dynamic>> _workoutsRef(String uid) =>
      _userRef(uid).collection(AppConstants.subWorkouts);

  CollectionReference<Map<String, dynamic>> _recordsRef(String uid) =>
      _userRef(uid).collection(AppConstants.subPersonalRecords);

  CollectionReference<Map<String, dynamic>> _weeklyRef(String uid) =>
      _userRef(uid).collection(AppConstants.subWeeklyProgress);

  CollectionReference<Map<String, dynamic>> _scheduledRef(String uid) =>
      _userRef(uid).collection(AppConstants.subScheduledWorkouts);

  String get newDocId => _db.collection('_generator').doc().id;

  static String weekIdOf(DateTime date) {
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final week1 = DateTime(thursday.year, 1, 4);
    final week1Thursday = week1.add(
      Duration(days: 3 - ((week1.weekday + 6) % 7)),
    );
    final week = 1 + (thursday.difference(week1Thursday).inDays ~/ 7);
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static DateTime weekStartOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final daysFromMonday = (day.weekday - DateTime.monday) % 7;
    return day.subtract(Duration(days: daysFromMonday));
  }

  Future<void> createUserProfile(UserModel user) async {
    await _db.runTransaction((tx) async {
      tx.set(_userRef(user.uid), user.toMap());
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _userRef(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return UserModel.fromMap(doc.id, data);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now();
    await _userRef(uid).set(data, SetOptions(merge: true));
  }

  Future<List<ExerciseModel>> getExercises(String uid) async {
    final snap = await _exercisesRef(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ExerciseModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> saveExercise(String uid, ExerciseModel exercise) async {
    await _exercisesRef(uid).doc(exercise.id).set(exercise.toMap());
  }

  Future<void> deleteExercise(String uid, String exerciseId) async {
    final routines = await getRoutines(uid);
    final batch = _db.batch();
    batch.delete(_exercisesRef(uid).doc(exerciseId));
    for (final routine in routines) {
      if (!routine.exercises.contains(exerciseId)) continue;
      batch.set(
        _routinesRef(uid).doc(routine.id),
        routine.withoutExercise(exerciseId).toMap(),
      );
    }
    await batch.commit();
  }

  Future<List<WorkoutRoutine>> getRoutines(String uid) async {
    final snap = await _routinesRef(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => WorkoutRoutine.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> saveRoutine(String uid, WorkoutRoutine routine) async {
    await _routinesRef(uid).doc(routine.id).set(routine.toMap());
  }

  Future<void> deleteRoutine(String uid, String routineId) async {
    await _routinesRef(uid).doc(routineId).delete();
  }

  Future<List<WorkoutSession>> getWorkouts(String uid) async {
    final snap = await _workoutsRef(uid)
        .orderBy('finishedAt', descending: true)
        .limit(200)
        .get();
    return snap.docs
        .map((d) => WorkoutSession.fromMap(d.id, d.data()))
        .toList();
  }

  Future<WorkoutSaveResult> saveWorkout(
    String uid,
    WorkoutSession session,
  ) async {
    final workoutRef = _workoutsRef(uid).doc(session.id);
    final finishedAt = session.finishedAt ?? DateTime.now();
    final weekId = weekIdOf(finishedAt);
    final weekStart = weekStartOf(finishedAt);
    final weeklyRef = _weeklyRef(uid).doc(weekId);

    // Mejor serie (más peso y, a igual peso, más repeticiones) de cada
    // ejercicio con al menos una serie completada de peso mayor a cero.
    // También se guarda el volumen del ejercicio para el récord de volumen.
    final candidates =
        <
          ({
            String exerciseId,
            String exerciseName,
            double weight,
            int reps,
            double volume,
          })
        >[];
    for (final exercise in session.exercises) {
      WorkoutSet? best;
      for (final set in exercise.sets) {
        if (!set.completed) continue;
        if (best == null || set.outperforms(best)) best = set;
      }
      if (best == null || best.weight <= 0) continue;
      candidates.add((
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
        weight: best.weight,
        reps: best.repetitions,
        volume: exercise.volume,
      ));
    }

    // Firestore exige que TODAS las lecturas ocurran antes de CUALQUIER
    // escritura dentro de una transacción. Por eso los documentos de
    // récords se leen primero y los `set`/`update` se aplican después.
    final newRecords = await _db.runTransaction((tx) async {
      final weeklyDoc = await tx.get(weeklyRef);

      final previousRecords = <PersonalRecord>[];
      // Récords guardados antes de existir `bestVolume`: su volumen previo
      // es desconocido, así que no se anuncia un récord de volumen falso.
      final volumeKnown = <bool>[];
      for (final candidate in candidates) {
        final recordDoc = await tx.get(
          _recordsRef(uid).doc(candidate.exerciseId),
        );
        final data = recordDoc.data();
        volumeKnown.add(data == null || data.containsKey('bestVolume'));
        // Sin documento, el récord previo es 0 kg × 0: cualquier marca lo supera.
        previousRecords.add(
          data == null
              ? PersonalRecord(
                  id: candidate.exerciseId,
                  userId: uid,
                  exerciseId: candidate.exerciseId,
                  exerciseName: candidate.exerciseName,
                )
              : PersonalRecord.fromMap(recordDoc.id, data),
        );
      }

      tx.set(workoutRef, session.toMap());

      if (weeklyDoc.exists) {
        tx.update(weeklyRef, {
          'workouts': FieldValue.increment(1),
          'totalSets': FieldValue.increment(session.totalSets),
          'totalReps': FieldValue.increment(session.totalReps),
          'totalVolume': FieldValue.increment(session.totalVolume),
          'updatedAt': DateTime.now(),
        });
      } else {
        tx.set(weeklyRef, {
          'userId': uid,
          'weekId': weekId,
          'weekStart': weekStart,
          'workouts': 1,
          'totalSets': session.totalSets,
          'totalReps': session.totalReps,
          'totalVolume': session.totalVolume,
          'updatedAt': DateTime.now(),
        });
      }

      final records = <NewRecordInfo>[];
      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        final previous = previousRecords[index];
        final weightRecord = previous.isBetterThan(
          candidate.weight,
          candidate.reps,
        );
        final volumeRecord = candidate.volume > previous.bestVolume;
        if (!weightRecord && !volumeRecord) continue;

        // Se conserva lo mejor de cada marca: la mejor serie y el mejor
        // volumen pueden venir de sesiones distintas.
        tx.set(
          _recordsRef(uid).doc(candidate.exerciseId),
          PersonalRecord(
            id: candidate.exerciseId,
            userId: uid,
            exerciseId: candidate.exerciseId,
            exerciseName: candidate.exerciseName,
            maxWeight: weightRecord ? candidate.weight : previous.maxWeight,
            reps: weightRecord ? candidate.reps : previous.reps,
            bestVolume: volumeRecord ? candidate.volume : previous.bestVolume,
            date: weightRecord ? finishedAt : (previous.date ?? finishedAt),
            updatedAt: DateTime.now(),
          ).toMap(),
        );
        final announceVolume = volumeRecord && volumeKnown[index];
        if (!weightRecord && !announceVolume) continue;
        records.add(
          NewRecordInfo(
            exerciseId: candidate.exerciseId,
            exerciseName: candidate.exerciseName,
            previousWeight: previous.maxWeight,
            previousReps: previous.reps,
            newWeight: weightRecord ? candidate.weight : previous.maxWeight,
            reps: weightRecord ? candidate.reps : previous.reps,
            isWeightRecord: weightRecord,
            isVolumeRecord: announceVolume,
            newVolume: volumeRecord ? candidate.volume : previous.bestVolume,
            previousVolume: previous.bestVolume,
          ),
        );
      }

      return records;
    });

    return WorkoutSaveResult(
      workoutId: session.id,
      session: session,
      newRecords: newRecords,
    );
  }

  Future<List<PersonalRecord>> getPersonalRecords(String uid) async {
    final snap = await _recordsRef(uid)
        .orderBy('maxWeight', descending: true)
        .get();
    // A igual peso, primero el récord con más repeticiones.
    return snap.docs.map((d) => PersonalRecord.fromMap(d.id, d.data())).toList()
      ..sort(PersonalRecord.compareBest);
  }

  Future<List<WeeklyProgress>> getWeeklyProgress(String uid) async {
    final snap = await _weeklyRef(uid)
        .orderBy('weekStart', descending: true)
        .limit(26)
        .get();
    return snap.docs
        .map((d) => WeeklyProgress.fromMap(d.id, d.data()))
        .toList();
  }

  // ------------------------------------------------- calendario personal

  /// Entrenamientos programados del usuario, del más antiguo al más nuevo.
  Future<List<ScheduledWorkout>> getScheduledWorkouts(String uid) async {
    final snap = await _scheduledRef(uid).orderBy('date').get();
    return snap.docs
        .map((d) => ScheduledWorkout.fromMap(d.id, d.data()))
        .toList();
  }

  /// Guarda uno o varios entrenamientos programados en una sola escritura.
  Future<void> saveScheduledWorkouts(
    String uid,
    List<ScheduledWorkout> items,
  ) async {
    final batch = _db.batch();
    for (final item in items) {
      batch.set(_scheduledRef(uid).doc(item.id), item.toMap());
    }
    await batch.commit();
  }

  Future<void> deleteScheduledWorkout(String uid, String id) async {
    await _scheduledRef(uid).doc(id).delete();
  }
}
