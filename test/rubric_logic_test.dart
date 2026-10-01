import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitprogress/core/constants/app_constants.dart';
import 'package:fitprogress/core/theme/app_theme.dart';
import 'package:fitprogress/models/exercise_model.dart';
import 'package:fitprogress/models/goal_model.dart';
import 'package:fitprogress/models/personal_record_model.dart';
import 'package:fitprogress/models/progress_model.dart';
import 'package:fitprogress/models/routine_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/models/workout_set_model.dart';
import 'package:fitprogress/providers/progress_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:fitprogress/services/firestore_service.dart';
import 'package:fitprogress/widgets/weekly_goals_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uid = 'u1';

/// Sesión con una serie por ejercicio indicado (peso, reps).
WorkoutSession _session(
  String id,
  DateTime finished,
  Map<String, (double, int)> sets,
) {
  final records = [
    for (final entry in sets.entries)
      WorkoutExerciseRecord(
        exerciseId: entry.key,
        exerciseName: 'Ejercicio ${entry.key}',
        sets: [
          WorkoutSet(
            setNumber: 1,
            weight: entry.value.$1,
            repetitions: entry.value.$2,
          ),
        ],
      ),
  ];
  return WorkoutSession(
    id: id,
    userId: _uid,
    startedAt: finished.subtract(const Duration(minutes: 40)),
    finishedAt: finished,
    duration: const Duration(minutes: 40),
    totalVolume: records.fold(0, (sum, r) => sum + r.volume),
    totalSets: records.length,
    totalReps: records.fold(0, (sum, r) => sum + r.totalReps),
    totalExercises: records.length,
    exercises: records,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppFirebase.firestoreOverride = FakeFirebaseFirestore();
  });

  tearDown(() => AppFirebase.firestoreOverride = null);

  group('Récord personal (peso + repeticiones)', () {
    PersonalRecord record(double weight, int reps) => PersonalRecord(
      id: 'e1',
      userId: _uid,
      exerciseId: 'e1',
      exerciseName: 'Press banca',
      maxWeight: weight,
      reps: reps,
    );

    test('a igual peso, más repeticiones es récord', () {
      expect(record(80, 6).isBetterThan(80, 8), isTrue);
      expect(record(80, 8).isBetterThan(80, 6), isFalse);
      expect(record(80, 8).isBetterThan(80, 8), isFalse);
    });

    test('más peso es récord aunque tenga menos repeticiones', () {
      expect(record(80, 8).isBetterThan(82.5, 3), isTrue);
      expect(record(80, 6).isBetterThan(79, 12), isFalse);
    });

    test('WorkoutSet.outperforms usa el mismo criterio', () {
      final a = WorkoutSet(setNumber: 1, weight: 80, repetitions: 8);
      final b = WorkoutSet(setNumber: 2, weight: 80, repetitions: 6);
      expect(a.outperforms(b), isTrue);
      expect(b.outperforms(a), isFalse);
      expect(a.volume, 640); // peso × repeticiones
    });

    test('saveWorkout guarda el récord al subir repeticiones con el mismo '
        'peso', () async {
      final service = FirestoreService();
      final first = await service.saveWorkout(
        _uid,
        _session('w1', DateTime.now(), {'e1': (80, 6)}),
      );
      expect(first.newRecords.single.isFirst, isTrue);

      final better = await service.saveWorkout(
        _uid,
        _session('w2', DateTime.now(), {'e1': (80, 8)}),
      );
      final info = better.newRecords.single;
      expect(info.previousWeight, 80);
      expect(info.previousReps, 6);
      expect(info.reps, 8);

      final worse = await service.saveWorkout(
        _uid,
        _session('w3', DateTime.now(), {'e1': (80, 5)}),
      );
      expect(worse.newRecords, isEmpty);

      final records = await service.getPersonalRecords(_uid);
      expect(records.single.maxWeight, 80);
      expect(records.single.reps, 8);
    });

    test('la mejor serie de la sesión desempata por repeticiones', () async {
      final session = WorkoutSession(
        id: 'w1',
        userId: _uid,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        totalSets: 2,
        exercises: [
          WorkoutExerciseRecord(
            exerciseId: 'e1',
            exerciseName: 'Press banca',
            sets: [
              WorkoutSet(setNumber: 1, weight: 80, repetitions: 5),
              WorkoutSet(setNumber: 2, weight: 80, repetitions: 9),
            ],
          ),
        ],
      );
      final result = await FirestoreService().saveWorkout(_uid, session);
      expect(result.newRecords.single.reps, 9);
      expect(result.session, same(session));
    });
  });

  group('Metas semanales', () {
    test('estado alcanzada, a buen ritmo y pendiente', () {
      final reached = WeeklyGoal(
        title: 'Volumen',
        unit: 'kg',
        target: 10000,
        current: 10500,
        expectedFraction: 0.5,
      );
      expect(reached.status, GoalStatus.reached);
      expect(reached.statusLabel, 'Meta alcanzada');
      expect(reached.ratio, 1);
      expect(reached.percent, 105);
      expect(reached.remaining, 0);

      final onTrack = WeeklyGoal(
        title: 'Volumen',
        unit: 'kg',
        target: 10000,
        current: 7500,
        expectedFraction: 0.5,
      );
      expect(onTrack.status, GoalStatus.onTrack);
      expect(onTrack.remaining, 2500);
      expect(onTrack.percent, 75);

      final pending = WeeklyGoal(
        title: 'Volumen',
        unit: 'kg',
        target: 10000,
        current: 2000,
        expectedFraction: 0.5,
      );
      expect(pending.status, GoalStatus.pending);
      expect(pending.statusLabel, 'Meta pendiente');
    });

    test('buildWeeklyGoals usa los totales reales de la semana', () {
      final goals = ProgressProvider.buildWeeklyGoals(
        week: (workouts: 3, volume: 7500, sets: 20),
        volumeGoal: 10000,
        setsGoal: 20,
        workoutsGoal: 4,
        now: DateTime(2026, 10, 4), // domingo: semana completa
      );
      expect(goals.map((g) => g.status), [
        GoalStatus.pending,
        GoalStatus.reached,
        GoalStatus.pending,
      ]);
      expect(goals.first.current, 7500);
    });
  });

  group('ProgressProvider.agregarSesion', () {
    Future<ProgressProvider> loaded() async {
      final provider = ProgressProvider(firestore: FirestoreService());
      await provider.refresh(uid: _uid);
      expect(provider.hasData, isTrue);
      return provider;
    }

    test('actualiza historial, semana, récords y estadísticas y notifica '
        'sin volver a leer Firestore', () async {
      final provider = await loaded();
      var notifications = 0;
      provider.addListener(() => notifications++);

      final session = _session('w1', DateTime.now(), {
        'e1': (100, 5),
        'e2': (60, 10),
      });
      provider.agregarSesion(
        session,
        newRecords: const [
          NewRecordInfo(
            exerciseId: 'e1',
            exerciseName: 'Ejercicio e1',
            previousWeight: 0,
            newWeight: 100,
            reps: 5,
          ),
        ],
      );

      expect(notifications, 1);
      expect(provider.loading, isFalse); // no se lanzó otra carga
      expect(provider.workouts.single.id, 'w1');
      expect(provider.progress!.totalWorkouts, 1);
      expect(provider.progress!.totalVolume, 100 * 5 + 60 * 10);
      expect(provider.progress!.totalSets, 2);
      expect(provider.thisWeek.sets, 2);
      expect(provider.records.single.maxWeight, 100);
      expect(provider.weekly.single.totalVolume, 1100);

      // La misma sesión no se suma dos veces.
      provider.agregarSesion(session);
      expect(provider.workouts, hasLength(1));
    });

    test('si los datos no se habían cargado, hace la carga completa', () async {
      final service = FirestoreService();
      final session = _session('w1', DateTime.now(), {'e1': (50, 10)});
      await service.saveWorkout(_uid, session);

      final provider = ProgressProvider(firestore: service);
      provider.agregarSesion(session);
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();
      expect(provider.hasData, isTrue);
      expect(provider.workouts.single.id, 'w1');
    });

    test('progreso semanal acumulado por día', () async {
      final provider = await loaded();
      final monday = FirestoreService.weekStartOf(DateTime.now());
      provider.agregarSesion(
        _session('a', monday.add(const Duration(hours: 9)), {
          'e1': (50, 10),
          'e2': (40, 10),
        }),
      );
      provider.agregarSesion(
        _session('b', monday.add(const Duration(hours: 18)), {'e1': (50, 8)}),
      );
      final progress = provider.progress!;
      expect(progress.weekSetsByDay.first, 3);
      expect(progress.weekVolumeByDay.first, 500 + 400 + 400);
      expect(progress.weekSetsByDay.fold<int>(0, (a, b) => a + b), 3);
      expect(provider.weekly.single.workouts, 2);
    });

    test('el historial semanal incluye las semanas sin entrenamientos '
        '(do-while)', () async {
      final provider = await loaded();
      // Sin datos: aun así aparece la semana actual.
      expect(provider.weeklyAscending, hasLength(1));

      final now = DateTime.now();
      provider.agregarSesion(
        _session('old', now.subtract(const Duration(days: 14)), {
          'e1': (40, 10),
        }),
      );
      final weeks = provider.weeklyAscending;
      expect(weeks, hasLength(3));
      expect(weeks.first.totalVolume, 400);
      expect(weeks[1].workouts, 0); // la semana vacía se muestra con 0
      expect(
        weeks.last.weekId,
        FirestoreService.weekIdOf(FirestoreService.weekStartOf(now)),
      );
    });

    test('el historial semanal se limita a las últimas semanas', () async {
      final provider = await loaded();
      provider.agregarSesion(
        _session('old', DateTime.now().subtract(const Duration(days: 200)), {
          'e1': (40, 10),
        }),
      );
      expect(provider.weeklyAscending, hasLength(AppConstants.weeksInHistory));
    });

    test('Map de progreso por ejercicio', () async {
      final provider = await loaded();
      final now = DateTime.now();
      provider.agregarSesion(
        _session('a', now.subtract(const Duration(days: 2)), {'e1': (80, 6)}),
      );
      provider.agregarSesion(
        _session('b', now.subtract(const Duration(days: 1)), {
          'e1': (80, 8),
          'e2': (20, 15),
        }),
      );
      provider.agregarSesion(_session('c', now, {'e1': (88, 3)}));

      final byExercise = provider.progressByExercise;
      expect(byExercise.keys, containsAll(['e1', 'e2']));
      final bench = byExercise['e1']!;
      expect(bench.workoutCount, 3);
      expect(bench.totalSets, 3);
      expect(bench.totalReps, 17);
      expect(bench.bestWeight, 88);
      expect(bench.bestReps, 3);
      expect(bench.firstWeight, 80);
      expect(bench.latestWeight, 88);
      expect(bench.progressPercent, closeTo(10, 0.001));
      expect(bench.totalVolume, 80 * 6 + 80 * 8 + 88 * 3);
    });

    test('updateGoals cambia las metas y notifica', () async {
      final provider = await loaded();
      var notifications = 0;
      provider.addListener(() => notifications++);
      await provider.updateGoals(volume: 500, sets: 2, workouts: 1);
      expect(notifications, 1);
      expect(provider.volumeGoal, 500);

      provider.agregarSesion(_session('w', DateTime.now(), {'e1': (100, 5)}));
      expect(provider.goalsReached, 2); // volumen y entrenamientos
      // Valores inválidos se ignoran.
      await provider.updateGoals(volume: 0, sets: 2, workouts: 1);
      expect(provider.volumeGoal, 500);
    });
  });

  testWidgets('Consumer de metas se reconstruye con notifyListeners', (
    tester,
  ) async {
    final provider = ProgressProvider(firestore: FirestoreService());
    await tester.runAsync(() => provider.refresh(uid: _uid));
    await provider.updateGoals(volume: 1000, sets: 3, workouts: 1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: WeeklyGoalsCard()),
          ),
        ),
      ),
    );
    expect(find.text('0 de 3 metas cumplidas esta semana'), findsOneWidget);
    expect(find.text('Meta alcanzada'), findsNothing);

    provider.agregarSesion(
      _session('w', DateTime.now(), {
        'e1': (100, 5),
        'e2': (100, 5),
        'e3': (50, 2),
      }),
    );
    await tester.pump();
    expect(find.text('3 de 3 metas cumplidas esta semana'), findsOneWidget);
    expect(find.text('Meta alcanzada'), findsNWidgets(3));
  });

  group('Encapsulamiento de los modelos', () {
    test('las listas internas no se pueden modificar desde fuera', () {
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: _uid,
        name: 'Pierna',
        exercises: ['e1', 'e2'],
      );
      expect(() => routine.exercises.add('e3'), throwsUnsupportedError);

      final session = _session('w1', DateTime.now(), {'e1': (50, 10)});
      expect(() => session.exercises.clear(), throwsUnsupportedError);
      expect(
        () => session.exercises.first.sets.removeLast(),
        throwsUnsupportedError,
      );
    });

    test('la lista original tampoco altera el objeto', () {
      final ids = ['e1'];
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: _uid,
        name: 'Pierna',
        exercises: ids,
      );
      ids.add('e2');
      expect(routine.exercises, ['e1']);
    });

    test('los cambios se hacen con copias', () {
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: _uid,
        name: 'Pierna',
        exercises: ['e1', 'e2', 'e3'],
      );
      final updated = routine.withoutExercise('e2');
      expect(updated.exercises, ['e1', 'e3']);
      expect(routine.exercises, ['e1', 'e2', 'e3']); // el original no cambia
      expect(updated.id, 'r1');

      final set = WorkoutSet(setNumber: 3, weight: 60, repetitions: 8);
      final renumbered = set.renumbered(1);
      expect(renumbered.setNumber, 1);
      expect(renumbered.volume, set.volume);
      expect(set.setNumber, 3);

      final exercise = ExerciseModel(
        id: 'e1',
        name: 'Remo',
        muscleGroup: 'Espalda',
      );
      expect(exercise.copyWith(name: 'Remo con barra').name, 'Remo con barra');
      expect(exercise.name, 'Remo');
    });

    test('WeeklyProgress solo cambia con registerSession y valida', () {
      final week = WeeklyProgress(id: 'w', userId: _uid, weekId: '2026-W40');
      week.registerSession(sets: 4, reps: 32, volume: 2400);
      week.registerSession(sets: 2, reps: 10, volume: 500);
      expect(week.workouts, 2);
      expect(week.totalSets, 6);
      expect(week.totalReps, 42);
      expect(week.totalVolume, 2900);
      expect(
        () => week.registerSession(sets: -1, reps: 0, volume: 0),
        throwsArgumentError,
      );
      expect(week.workouts, 2);
    });
  });

  group('WorkoutRoutine se relaciona con sus ejercicios', () {
    final catalog = [
      ExerciseModel(id: 'e1', name: 'Press banca', muscleGroup: 'Pecho'),
      ExerciseModel(id: 'e2', name: 'Aperturas', muscleGroup: 'Pecho'),
      ExerciseModel(id: 'e3', name: 'Sentadilla', muscleGroup: 'Piernas'),
    ];

    test('withExercises resuelve los objetos en orden y omite borrados', () {
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: _uid,
        name: 'Mixta',
        exercises: ['e3', 'borrado', 'e1', 'e2'],
      ).withExercises(catalog);
      expect(routine.exerciseDetails.map((e) => e.name), [
        'Sentadilla',
        'Press banca',
        'Aperturas',
      ]);
      // Set: los grupos musculares no se repiten.
      expect(routine.muscleGroups, {'Piernas', 'Pecho'});
      // En Firestore siguen viajando solo los IDs.
      expect(routine.toMap()['exercises'], ['e3', 'borrado', 'e1', 'e2']);
    });
  });
}
