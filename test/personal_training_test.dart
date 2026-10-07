import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitprogress/models/exercise_model.dart';
import 'package:fitprogress/models/routine_day_model.dart';
import 'package:fitprogress/models/routine_model.dart';
import 'package:fitprogress/models/scheduled_workout_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/models/workout_set_model.dart';
import 'package:fitprogress/providers/progress_provider.dart';
import 'package:fitprogress/screens/main/main_shell.dart';
import 'package:fitprogress/providers/schedule_provider.dart';
import 'package:fitprogress/providers/workout_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:fitprogress/services/firestore_service.dart';
import 'package:fitprogress/widgets/week_strip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uid = 'u1';

ExerciseModel _exercise(String id, [String group = 'Pecho']) =>
    ExerciseModel(id: id, name: 'Ejercicio $id', muscleGroup: group);

WorkoutRoutine _pushPull() => WorkoutRoutine(
  id: 'r1',
  userId: _uid,
  name: 'Push Pull',
  days: [
    RoutineDay(
      id: 'push',
      name: 'Empuje',
      exercises: [
        RoutineExercise(
          exerciseId: 'press',
          sets: 4,
          reps: 10,
          weight: 60,
          restSeconds: 120,
          notes: 'Codos a 45°',
        ),
        RoutineExercise(exerciseId: 'triceps', sets: 3, reps: 12),
      ],
    ),
    RoutineDay(
      id: 'pull',
      name: 'Tirón',
      exercises: [RoutineExercise(exerciseId: 'remo', sets: 4, reps: 8)],
    ),
  ],
);

WorkoutSession _session(
  String id,
  DateTime finished, {
  String routineId = 'r1',
  String dayId = '',
  Duration duration = const Duration(minutes: 45),
  Map<String, List<(double, int)>> sets = const {},
}) {
  final records = [
    for (final entry in sets.entries)
      WorkoutExerciseRecord(
        exerciseId: entry.key,
        exerciseName: 'Ejercicio ${entry.key}',
        sets: [
          for (var i = 0; i < entry.value.length; i++)
            WorkoutSet(
              setNumber: i + 1,
              weight: entry.value[i].$1,
              repetitions: entry.value[i].$2,
            ),
        ],
      ),
  ];
  return WorkoutSession(
    id: id,
    userId: _uid,
    routineId: routineId,
    routineName: 'Push Pull',
    routineDayId: dayId,
    startedAt: finished.subtract(duration),
    finishedAt: finished,
    duration: duration,
    totalVolume: records.fold(0, (sum, r) => sum + r.volume),
    totalSets: records.fold(0, (sum, r) => sum + r.sets.length),
    totalReps: records.fold(0, (sum, r) => sum + r.totalReps),
    totalExercises: records.length,
    exercises: records,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppFirebase.firestoreOverride = FakeFirebaseFirestore();
  });

  tearDown(() => AppFirebase.firestoreOverride = null);

  group('Rutinas con días', () {
    test('las rutinas antiguas (solo IDs) se leen como un único día', () {
      final legacy = WorkoutRoutine.fromMap('r0', {
        'name': 'Antigua',
        'exercises': ['a', 'b'],
      });
      expect(legacy.days, hasLength(1));
      expect(legacy.days.first.name, 'Día 1');
      expect(legacy.days.first.exerciseIds, ['a', 'b']);
      expect(legacy.exercises, ['a', 'b']);
      final plan = legacy.planFor('a')!;
      expect(plan.sets, RoutineExercise.defaultSets);
      expect(plan.reps, RoutineExercise.defaultReps);
    });

    test('se guardan días y plan, y se vuelven a leer igual', () {
      final routine = _pushPull();
      final map = routine.toMap();
      // Compatibilidad: la lista plana de IDs se sigue guardando.
      expect(map['exercises'], ['press', 'triceps', 'remo']);
      final restored = WorkoutRoutine.fromMap('r1', map);
      expect(restored.days.map((d) => d.name), ['Empuje', 'Tirón']);
      final press = restored.planFor('press')!;
      expect(press.sets, 4);
      expect(press.reps, 10);
      expect(press.weight, 60);
      expect(press.restSeconds, 120);
      expect(press.notes, 'Codos a 45°');
      expect(press.plannedVolume, 4 * 10 * 60);
      expect(restored.totalSets, 11);
    });

    test('forDay entrena solo ese día y conserva el ID de la rutina', () {
      final routine = _pushPull().withExercises([
        _exercise('press'),
        _exercise('triceps', 'Tríceps'),
        _exercise('remo', 'Espalda'),
      ]);
      final pull = routine.forDay(routine.days[1]);
      expect(pull.id, 'r1');
      expect(pull.name, 'Push Pull · Tirón');
      expect(pull.exercises, ['remo']);
      expect(pull.exerciseDetails.single.id, 'remo');
      expect(pull.days.single.id, 'pull');
    });

    test('copyWith(exercises:) conserva el plan de los que siguen', () {
      final routine = WorkoutRoutine(
        id: 'r',
        userId: _uid,
        name: 'Una',
        days: [
          RoutineDay(
            id: 'd',
            name: 'Día 1',
            exercises: [RoutineExercise(exerciseId: 'a', sets: 5)],
          ),
        ],
      );
      final updated = routine.copyWith(exercises: ['a', 'b']);
      expect(updated.planFor('a')!.sets, 5);
      expect(updated.planFor('b')!.sets, RoutineExercise.defaultSets);
    });

    test('withoutExercise lo quita de todos los días', () {
      final updated = _pushPull().withoutExercise('press');
      expect(updated.days.first.exerciseIds, ['triceps']);
      expect(updated.exercises, ['triceps', 'remo']);
    });

    test('el plan no admite valores inválidos', () {
      final plan = RoutineExercise(
        exerciseId: 'a',
        sets: 0,
        reps: -3,
        weight: -10,
        restSeconds: -1,
      );
      expect(plan.sets, 1);
      expect(plan.reps, 1);
      expect(plan.weight, 0);
      expect(plan.restSeconds, 0);
    });
  });

  group('WorkoutProvider con plan', () {
    test('expone el plan, el día y los ejercicios completos', () {
      final routine = _pushPull().withExercises([
        _exercise('press'),
        _exercise('triceps'),
        _exercise('remo'),
      ]);
      final provider = WorkoutProvider(currentUid: () => _uid);
      provider.startWorkout(
        routine: routine.forDay(routine.days.first),
        allExercises: routine.exerciseDetails,
      );
      expect(provider.routineDayId, 'push');
      expect(provider.plannedFor('press')!.weight, 60);
      expect(provider.isExerciseDone('press'), isFalse);
      for (var i = 0; i < 4; i++) {
        provider.addSet('press', weight: 60, repetitions: 10);
      }
      expect(provider.isExerciseDone('press'), isTrue);
      expect(provider.completedExercises, 1);
    });

    test('los entrenamientos libres no tienen plan', () {
      final provider = WorkoutProvider(currentUid: () => _uid)
        ..startFreeWorkout([_exercise('a')]);
      expect(provider.plannedFor('a'), isNull);
      expect(provider.routineDayId, '');
      provider.addSet('a', weight: 10, repetitions: 5);
      expect(provider.isExerciseDone('a'), isTrue);
    });
  });

  group('Récord de volumen', () {
    test(
      'más volumen con menos peso es récord de volumen, no de peso',
      () async {
        final service = FirestoreService();
        await service.saveWorkout(
          _uid,
          _session(
            'w1',
            DateTime.now(),
            sets: {
              'press': [(80, 6)],
            },
          ),
        );
        final result = await service.saveWorkout(
          _uid,
          _session(
            'w2',
            DateTime.now(),
            sets: {
              'press': [(70, 10)],
            },
          ),
        );
        final info = result.newRecords.single;
        expect(info.isWeightRecord, isFalse);
        expect(info.isVolumeRecord, isTrue);
        expect(info.previousVolume, 480);
        expect(info.newVolume, 700);

        final record = (await service.getPersonalRecords(_uid)).single;
        expect(record.maxWeight, 80); // la mejor serie se conserva
        expect(record.reps, 6);
        expect(record.bestVolume, 700);
      },
    );

    test('récords antiguos sin volumen no anuncian un récord falso', () async {
      final db = AppFirebase.firestore;
      await db.doc('users/$_uid/personal_records/press').set({
        'exerciseId': 'press',
        'exerciseName': 'Press',
        'maxWeight': 100,
        'reps': 5,
      });
      final result = await FirestoreService().saveWorkout(
        _uid,
        _session(
          'w1',
          DateTime.now(),
          sets: {
            'press': [(60, 10)],
          },
        ),
      );
      expect(result.newRecords, isEmpty);
      final data = (await db.doc('users/$_uid/personal_records/press').get())
          .data()!;
      expect(data['bestVolume'], 600); // queda registrado para la próxima
      expect(data['maxWeight'], 100);
    });
  });

  group('ProgressProvider: tiempo, comparación e historial', () {
    Future<ProgressProvider> loaded() async {
      final provider = ProgressProvider(firestore: FirestoreService());
      await provider.refresh(uid: _uid);
      return provider;
    }

    test('tiempo entrenado total y de la semana', () async {
      final provider = await loaded();
      final now = DateTime.now();
      provider.agregarSesion(
        _session('a', now, duration: const Duration(minutes: 50)),
      );
      provider.agregarSesion(
        _session(
          'b',
          now.subtract(const Duration(days: 21)),
          duration: const Duration(minutes: 30),
        ),
      );
      expect(provider.totalDuration, const Duration(minutes: 80));
      expect(provider.thisWeekDuration, const Duration(minutes: 50));
    });

    test('compara con la sesión anterior del mismo día de rutina', () async {
      final provider = await loaded();
      final now = DateTime.now();
      final oldPush = _session(
        'p1',
        now.subtract(const Duration(days: 7)),
        dayId: 'push',
        sets: {
          'press': [(55, 10)],
        },
      );
      final pull = _session(
        'l1',
        now.subtract(const Duration(days: 3)),
        dayId: 'pull',
      );
      final newPush = _session(
        'p2',
        now,
        dayId: 'push',
        sets: {
          'press': [(60, 10)],
        },
      );
      provider
        ..agregarSesion(oldPush)
        ..agregarSesion(pull)
        ..agregarSesion(newPush);
      expect(provider.previousComparable(newPush)!.id, 'p1');
      final previous = provider.previousRecordFor(
        'press',
        before: now,
        excludingSessionId: 'p2',
      );
      expect(previous!.volume, 550);
    });

    test('mejor peso por semana y días entrenados', () async {
      final provider = await loaded();
      final monday = FirestoreService.weekStartOf(DateTime.now());
      provider
        ..agregarSesion(
          _session(
            'a',
            monday.subtract(const Duration(days: 6)),
            sets: {
              'press': [(50, 10), (52.5, 8)],
            },
          ),
        )
        ..agregarSesion(
          _session(
            'b',
            monday.add(const Duration(hours: 10)),
            sets: {
              'press': [(55, 8)],
            },
          ),
        );
      final weekly = provider.weeklyBestWeight('press');
      expect(weekly.map((w) => w.bestWeight), [52.5, 55]);
      expect(weekly.last.weekStart, monday);
      expect(provider.trainedDays, contains(monday));
      expect(provider.sessionsOn(monday).single.id, 'b');
    });
  });

  group('Calendario personal', () {
    test(
      'programar con repetición semanal crea una fecha por semana',
      () async {
        final provider = ScheduleProvider(currentUid: () => _uid);
        final routine = _pushPull();
        final start = DateTime(2026, 10, 5); // lunes
        final created = await provider.schedule(
          routine: routine,
          day: routine.days[1],
          date: start,
          weeks: 3,
        );
        expect(created, 3);
        expect(provider.items.map((i) => i.date), [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 19),
        ]);
        expect(
          provider.forDay(DateTime(2026, 10, 12)).single.title,
          'Push Pull · Tirón',
        );

        // Se guardó en Firestore bajo el usuario y se vuelve a leer.
        final reloaded = ScheduleProvider(currentUid: () => _uid);
        await reloaded.load();
        expect(reloaded.items, hasLength(3));

        await provider.remove(provider.items.first.id);
        expect(provider.items, hasLength(2));
        provider.reset();
        expect(provider.items, isEmpty);
        expect(provider.loaded, isFalse);
      },
    );

    test('sin repetición se programa una sola vez', () async {
      final provider = ScheduleProvider(currentUid: () => _uid);
      final created = await provider.schedule(
        routine: _pushPull(),
        day: null,
        date: DateTime(2026, 10, 7),
      );
      expect(created, 1);
    });

    test('un entrenamiento programado se completa con la sesión del día', () {
      final item = ScheduledWorkout(
        id: 's',
        date: DateTime(2026, 10, 5, 18),
        routineId: 'r1',
        routineName: 'Push Pull',
        dayId: 'push',
      );
      expect(item.date, DateTime(2026, 10, 5)); // sin hora
      final pull = _session('a', DateTime(2026, 10, 5), dayId: 'pull');
      final push = _session('b', DateTime(2026, 10, 5), dayId: 'push');
      final otherRoutine = _session(
        'c',
        DateTime(2026, 10, 5),
        routineId: 'r9',
      );
      expect(item.isCompletedBy([pull, otherRoutine]), isFalse);
      expect(item.isCompletedBy([push]), isTrue);
      // Sesiones antiguas sin día guardado cuentan para la misma rutina.
      expect(
        item.isCompletedBy([_session('d', DateTime(2026, 10, 5))]),
        isTrue,
      );
    });
  });

  group('Navegación y calendario semanal', () {
    test('las pantallas sin pestaña marcan su pestaña madre', () {
      expect(MainShell.parentTab(ShellBranch.hoy), ShellBranch.hoy);
      expect(MainShell.parentTab(ShellBranch.perfil), ShellBranch.perfil);
      expect(
        MainShell.parentTab(ShellBranch.entrenamiento),
        ShellBranch.entrenar,
      );
      expect(MainShell.parentTab(ShellBranch.ejercicios), ShellBranch.entrenar);
      expect(MainShell.parentTab(ShellBranch.calendario), ShellBranch.hoy);
    });

    test('lunes de la semana y rótulo del rango', () async {
      await initializeDateFormatting('es');
      // Miércoles 7 de octubre de 2026 → lunes 5.
      expect(
        WeekStrip.mondayOf(DateTime(2026, 10, 7, 18)),
        DateTime(2026, 10, 5),
      );
      // Un lunes es su propio lunes; un domingo pertenece a la semana anterior.
      expect(WeekStrip.mondayOf(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
      expect(WeekStrip.mondayOf(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
      // Cruza de año.
      expect(WeekStrip.mondayOf(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));

      expect(
        WeekStrip.rangeLabel(DateTime(2026, 10, 5)),
        startsWith('5 – 11 '),
      );
      final crossing = WeekStrip.rangeLabel(DateTime(2026, 9, 28));
      expect(crossing, startsWith('28 '));
      expect(crossing, contains('– 4 '));
    });
  });
}
