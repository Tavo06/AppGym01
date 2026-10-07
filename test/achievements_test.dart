import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitprogress/core/constants/achievement_catalog.dart';
import 'package:fitprogress/models/achievement_model.dart';
import 'package:fitprogress/models/nutrition_model.dart';
import 'package:fitprogress/models/personal_record_model.dart';
import 'package:fitprogress/models/scheduled_workout_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/models/workout_set_model.dart';
import 'package:fitprogress/providers/achievement_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session(
  String id,
  DateTime finished, {
  double volume = 1000,
  Duration duration = const Duration(minutes: 60),
  List<String> exercises = const ['e1'],
  String routineId = '',
  String dayId = '',
}) => WorkoutSession(
  id: id,
  userId: 'u1',
  routineId: routineId,
  routineDayId: dayId,
  startedAt: finished.subtract(duration),
  finishedAt: finished,
  duration: duration,
  totalVolume: volume,
  exercises: [
    for (final e in exercises)
      WorkoutExerciseRecord(
        exerciseId: e,
        exerciseName: e,
        sets: [WorkoutSet(setNumber: 1, weight: 50, repetitions: 10)],
      ),
  ],
);

PersonalRecord _record(String exerciseId) => PersonalRecord(
  id: exerciseId,
  userId: 'u1',
  exerciseId: exerciseId,
  exerciseName: exerciseId,
  maxWeight: 50,
  reps: 10,
);

DailyNutritionRecord _day(DateTime date, {double kcal = 0, int water = 0}) {
  final day = DailyNutritionRecord(date: date, waterMl: water);
  if (kcal <= 0) return day;
  return day.withEntry(
    FoodEntry(
      mealType: MealType.lunch,
      food: FoodItem(name: 'Comida', quantity: 100, kcal: kcal),
    ),
  );
}

AchievementStats _trainingStats(int workouts) => AchievementStats.compute(
  now: DateTime(2026, 10, 6),
  workouts: [
    for (var i = 0; i < workouts; i++)
      _session('w$i', DateTime(2026, 9, 1 + i * 3, 18)),
  ],
  records: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catálogo', () {
    test('identificadores únicos, metas positivas y todas las categorías', () {
      final ids = AchievementCatalog.all.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(AchievementCatalog.all.every((d) => d.target > 0), isTrue);
      for (final category in AchievementCategory.values) {
        expect(AchievementCatalog.ofCategory(category), isNotEmpty);
      }
      expect(AchievementCatalog.byId('workouts-1')!.title, 'Primer paso');
      expect(AchievementCatalog.byId('no-existe'), isNull);
    });

    test('avance y formato de la métrica', () {
      final volume = AchievementCatalog.byId('volume-10000')!;
      final stats = AchievementStats({AchievementMetric.totalVolume: 2500});
      expect(volume.progressOf(stats), closeTo(0.25, 0.001));
      expect(volume.isReachedBy(stats), isFalse);
      expect(volume.format(10000), '10.000 kg');
      expect(AchievementCatalog.byId('hours-10')!.format(9.9), '9 h');
      // Sin datos de la fuente no hay avance (ni se considera conseguido).
      expect(volume.progressOf(AchievementStats.empty), isNull);
      expect(volume.isReachedBy(AchievementStats.empty), isFalse);
    });
  });

  group('Rachas', () {
    test('racha de días más larga, no solo la actual', () {
      expect(AchievementStats.longestDayStreak(const []), 0);
      expect(
        AchievementStats.longestDayStreak([
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 2, 20), // la hora no importa
          DateTime(2026, 9, 2, 8), // repetido
          DateTime(2026, 9, 5),
          // Cruza el cambio de mes.
          DateTime(2026, 9, 29),
          DateTime(2026, 9, 30),
          DateTime(2026, 10, 1),
        ]),
        3,
      );
    });

    test('racha de semanas seguidas, también entre años', () {
      expect(
        AchievementStats.longestWeekStreak([
          DateTime(2025, 12, 22), // lunes
          DateTime(2025, 12, 24), // misma semana
          DateTime(2025, 12, 31), // miércoles, semana siguiente
          DateTime(2026, 1, 4), // domingo, misma semana que el 31
          DateTime(2026, 1, 9), // semana siguiente
          DateTime(2026, 2, 2), // otra racha de 1
        ]),
        3,
      );
    });
  });

  group('Métricas', () {
    test('entrenamiento: sesiones, volumen, horas y ejercicios', () {
      final stats = AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        workouts: [
          _session('a', DateTime(2026, 10, 1, 18), volume: 6000),
          _session(
            'b',
            DateTime(2026, 10, 2, 18),
            volume: 2000,
            duration: const Duration(minutes: 90),
            exercises: ['e1', 'e2', 'e3'],
          ),
          _session('c', DateTime(2026, 10, 3, 18), exercises: []),
        ],
        records: [_record('e1'), _record('e2')],
      );
      expect(stats.valueOf(AchievementMetric.workouts), 3);
      expect(stats.valueOf(AchievementMetric.totalVolume), 9000);
      expect(stats.valueOf(AchievementMetric.bestSessionVolume), 6000);
      expect(stats.valueOf(AchievementMetric.trainingHours), 3.5);
      expect(stats.valueOf(AchievementMetric.distinctExercises), 3);
      expect(stats.valueOf(AchievementMetric.bestDayStreak), 3);
      expect(stats.valueOf(AchievementMetric.records), 2);
      // Fuentes sin cargar: sin valor.
      expect(stats.valueOf(AchievementMetric.scheduledDone), isNull);
      expect(stats.valueOf(AchievementMetric.waterDayStreak), isNull);
      expect(stats.sources, {AchievementSource.training});
    });

    test('programados: solo cuentan los cumplidos hasta hoy', () {
      final workouts = [
        _session('a', DateTime(2026, 10, 1, 18), routineId: 'r1'),
        _session('b', DateTime(2026, 10, 3, 18), routineId: 'r2'),
      ];
      final stats = AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        workouts: workouts,
        records: const [],
        scheduled: [
          // Cumplido: misma rutina ese día.
          ScheduledWorkout(
            id: '1',
            date: DateTime(2026, 10, 1),
            routineId: 'r1',
            routineName: 'R1',
          ),
          // Otra rutina ese día: no cumplido.
          ScheduledWorkout(
            id: '2',
            date: DateTime(2026, 10, 3),
            routineId: 'r1',
            routineName: 'R1',
          ),
          // Futuro: no cuenta.
          ScheduledWorkout(
            id: '3',
            date: DateTime(2026, 10, 9),
            routineId: 'r2',
            routineName: 'R2',
          ),
        ],
      );
      expect(stats.valueOf(AchievementMetric.scheduledDone), 1);
      expect(stats.sources, {
        AchievementSource.training,
        AchievementSource.schedule,
      });
    });

    test('alimentación e hidratación', () {
      final stats = AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        nutritionDays: [
          _day(DateTime(2026, 10, 1), kcal: 2000, water: 2000),
          _day(DateTime(2026, 10, 2), kcal: 2150, water: 2500),
          _day(DateTime(2026, 10, 3), kcal: 1500, water: 1000),
          _day(DateTime(2026, 10, 4), water: 2000), // solo agua
          _day(DateTime(2026, 10, 5), kcal: 1900),
        ],
        nutritionPlans: const [],
        calorieTarget: 2000,
        waterGoal: 2000,
      );
      expect(stats.valueOf(AchievementMetric.nutritionPlans), 0);
      expect(stats.valueOf(AchievementMetric.foodDayStreak), 3);
      // 2000, 2150 y 1900 están dentro del ±10 %; 1500 no.
      expect(stats.valueOf(AchievementMetric.calorieDaysOnTarget), 3);
      expect(stats.valueOf(AchievementMetric.waterDaysOnGoal), 3);
      expect(stats.valueOf(AchievementMetric.waterDayStreak), 2);
      expect(stats.valueOf(AchievementMetric.workouts), isNull);

      // Sin plan activo no hay días "en el objetivo".
      final noPlan = AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        nutritionDays: [_day(DateTime(2026, 10, 1), kcal: 2000)],
        nutritionPlans: const [],
      );
      expect(noPlan.valueOf(AchievementMetric.calorieDaysOnTarget), 0);
    });
  });

  group('AchievementProvider', () {
    late FakeFirebaseFirestore db;

    setUp(() {
      db = FakeFirebaseFirestore();
      AppFirebase.firestoreOverride = db;
    });

    tearDown(() => AppFirebase.firestoreOverride = null);

    AchievementProvider provider([String uid = 'u1']) =>
        AchievementProvider(currentUid: () => uid);

    test('lo ya conseguido antes se guarda sin anunciar', () async {
      final p = provider();
      await p.load();
      // Primera evaluación del entrenamiento: un usuario con historial.
      p.updateStats(_trainingStats(10));
      expect(p.isUnlocked('workouts-1'), isTrue);
      expect(p.isUnlocked('workouts-10'), isTrue);
      expect(p.isUnlocked('workouts-50'), isFalse);
      expect(p.takeAnnouncements(), isEmpty);

      // La escritura en Firestore no bloquea la interfaz.
      await pumpEventQueue();
      final docs = await db.collection('users/u1/achievements').get();
      expect(docs.docs.map((d) => d.id), contains('workouts-10'));
    });

    test('un logro nuevo se anuncia una vez y se guarda', () async {
      final p = provider();
      await p.load();
      final before = DateTime.now();
      p.updateStats(_trainingStats(0));
      expect(p.unlockedCount, 0);

      p.updateStats(_trainingStats(1));
      expect(p.isUnlocked('workouts-1'), isTrue);
      expect(p.announcedSince(before).map((d) => d.id), ['workouts-1']);
      final announced = p.takeAnnouncements();
      expect(announced.map((d) => d.id), ['workouts-1']);
      expect(p.takeAnnouncements(), isEmpty);

      // Volver a evaluar no lo repite.
      p.updateStats(_trainingStats(1));
      expect(p.takeAnnouncements(), isEmpty);

      // Otra instancia (otro arranque de la app) lo lee de Firestore.
      await pumpEventQueue();
      final again = provider();
      await again.load();
      expect(again.isUnlocked('workouts-1'), isTrue);
      expect(again.unlockedAt('workouts-1'), isNotNull);
      again.updateStats(_trainingStats(1));
      expect(again.takeAnnouncements(), isEmpty);
    });

    test(
      'las métricas recibidas antes de cargar se evalúan al cargar',
      () async {
        final p = provider();
        p.updateStats(_trainingStats(1));
        expect(p.isUnlocked('workouts-1'), isFalse);
        await p.load();
        expect(p.isUnlocked('workouts-1'), isTrue);
        expect(p.takeAnnouncements(), isEmpty);
      },
    );

    test('cada fuente tiene su propia primera evaluación', () async {
      final p = provider();
      await p.load();
      p.updateStats(_trainingStats(0));

      // La alimentación llega después (al abrir su pestaña) con la meta de
      // agua ya cumplida antes: se guarda sin anunciar.
      AchievementStats withWater(List<int> water) => AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        workouts: const [],
        records: const [],
        nutritionDays: [
          for (var i = 0; i < water.length; i++)
            _day(DateTime(2026, 10, 1 + i), water: water[i]),
        ],
        nutritionPlans: const [],
        waterGoal: 2000,
      );
      p.updateStats(withWater([2000]));
      expect(p.isUnlocked('water-goal-1'), isTrue);
      expect(p.takeAnnouncements(), isEmpty);

      // A partir de ahí sí se anuncia.
      p.updateStats(withWater([2000, 0]));
      expect(p.takeAnnouncements(), isEmpty);
      final nutritionPlan = AchievementStats.compute(
        now: DateTime(2026, 10, 6),
        workouts: const [],
        records: const [],
        nutritionDays: const [],
        nutritionPlans: [NutritionPlan(id: 'p1', name: 'Plan')],
      );
      p.updateStats(nutritionPlan);
      expect(p.takeAnnouncements().map((d) => d.id), ['nutrition-plan-1']);
    });

    test('reset borra todo y cada usuario ve solo sus logros', () async {
      final ana = provider('ana');
      await ana.load();
      ana.updateStats(_trainingStats(1));
      expect(ana.unlockedCount, greaterThan(0));

      ana.reset();
      expect(ana.loaded, isFalse);
      expect(ana.unlockedCount, 0);
      expect(ana.stats.sources, isEmpty);

      final bruno = provider('bruno');
      await bruno.load();
      expect(bruno.unlockedCount, 0);
      expect(
        (await db.collection('users/bruno/achievements').get()).docs,
        isEmpty,
      );
    });

    test('logros conseguidos, del más reciente al más antiguo', () async {
      await db.doc('users/u1/achievements/workouts-1').set({
        'unlockedAt': DateTime(2026, 1, 1),
      });
      await db.doc('users/u1/achievements/records-1').set({
        'unlockedAt': DateTime(2026, 3, 1),
      });
      // Un logro que ya no existe en el catálogo no cuenta.
      await db.doc('users/u1/achievements/antiguo').set({
        'unlockedAt': DateTime(2026, 2, 1),
      });
      final p = provider();
      await p.load();
      expect(p.unlockedDefinitions.map((d) => d.id), [
        'records-1',
        'workouts-1',
      ]);
      expect(p.unlockedCount, 2);
    });
  });
}
