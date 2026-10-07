import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitprogress/core/constants/app_constants.dart';
import 'package:fitprogress/core/constants/nutrition_catalog.dart';
import 'package:fitprogress/models/nutrition_model.dart';
import 'package:fitprogress/providers/nutrition_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodItem _food(
  String name,
  double kcal, {
  double p = 0,
  double c = 0,
  double f = 0,
}) => FoodItem(
  name: name,
  quantity: 100,
  kcal: kcal,
  protein: p,
  carbs: c,
  fat: f,
);

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    AppFirebase.firestoreOverride = db;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => AppFirebase.firestoreOverride = null);

  NutritionProvider provider([String uid = 'u1']) =>
      NutritionProvider(currentUid: () => uid);

  group('Cálculo de calorías y macros', () {
    test('los totales se suman con +', () {
      const a = NutritionTotals(kcal: 100, protein: 10, carbs: 5, fat: 2);
      const b = NutritionTotals(kcal: 50, protein: 1, carbs: 10, fat: 3);
      final sum = a + b;
      expect(sum.kcal, 150);
      expect(sum.protein, 11);
      expect(sum.carbs, 15);
      expect(sum.fat, 5);
      expect(NutritionTotals.sum([a, b, a]).kcal, 250);
    });

    test('cambiar la cantidad recalcula en proporción', () {
      final oats = NutritionCatalog.byName('Avena').toFood(); // 100 g
      final half = oats.withQuantity(50);
      expect(half.quantity, 50);
      expect(half.kcal, closeTo(194.5, 0.001));
      expect(half.protein, closeTo(8.5, 0.001));
      expect(half.id, oats.id);
      final eggs = NutritionCatalog.byName('Huevo').toFood(2);
      expect(eggs.kcal, 144);
      expect(eggs.unit, FoodUnit.unit);
    });

    test('no se admiten valores negativos', () {
      final food = FoodItem(name: 'X', quantity: -1, kcal: -5, protein: -1);
      expect(food.quantity, 0);
      expect(food.kcal, 0);
      expect(food.protein, 0);
    });

    test('totales de comida y plan; comidas en orden del día', () {
      final plan = NutritionPlan(
        id: 'p',
        name: 'Mi plan',
        calories: 2000,
        meals: [
          NutritionMeal(type: MealType.dinner, foods: [_food('Pollo', 300)]),
          NutritionMeal(
            type: MealType.breakfast,
            foods: [
              _food('Avena', 389, p: 17, c: 66, f: 7),
              _food('Leche', 61, p: 3, c: 5, f: 3),
            ],
          ),
        ],
      );
      expect(plan.meals.map((m) => m.type), [
        MealType.breakfast,
        MealType.dinner,
      ]);
      expect(plan.meals.first.totals.kcal, 450);
      expect(plan.meals.first.totals.protein, 20);
      expect(plan.plannedTotals.kcal, 750);
      expect(plan.targets.kcal, 2000);
      expect(plan.meals.first.name, 'Desayuno');
    });

    test('plan y registro diario sobreviven a Firestore (toMap/fromMap)', () {
      final plan = NutritionTemplate.all.first.toPlan(id: 'p1', active: true);
      final restored = NutritionPlan.fromMap('p1', plan.toMap());
      expect(restored.name, plan.name);
      expect(restored.active, isTrue);
      expect(restored.templateId, 'masa-muscular');
      expect(restored.meals.length, plan.meals.length);
      expect(
        restored.plannedTotals.kcal,
        closeTo(plan.plannedTotals.kcal, 0.01),
      );

      final record = DailyNutritionRecord(date: DateTime(2026, 10, 1, 15))
          .withEntry(
            FoodEntry(mealType: MealType.lunch, food: _food('Arroz', 130)),
          );
      expect(record.dateKey, '2026-10-01');
      final back = DailyNutritionRecord.fromMap(record.toMap());
      expect(back.dateKey, '2026-10-01');
      expect(back.entriesFor(MealType.lunch).single.food.name, 'Arroz');
      expect(back.totals.kcal, 130);
    });
  });

  group('Comidas del día', () {
    test('solo desayuno, almuerzo y cena; las antiguas se agrupan', () {
      expect(MealType.daily, [
        MealType.breakfast,
        MealType.lunch,
        MealType.dinner,
      ]);
      expect(MealType.midMorning.dailyGroup, MealType.breakfast);
      expect(MealType.afternoon.dailyGroup, MealType.lunch);
      expect(MealType.snack.dailyGroup, MealType.dinner);
      for (final meal in MealType.daily) {
        expect(meal.dailyGroup, meal);
      }

      FoodEntry entry(MealType type, double kcal) =>
          FoodEntry(mealType: type, food: _food('x', kcal));
      final day = DailyNutritionRecord(
        date: DateTime(2026, 10, 1),
        entries: [
          entry(MealType.breakfast, 300),
          entry(MealType.midMorning, 100),
          entry(MealType.afternoon, 150),
          entry(MealType.snack, 50),
        ],
      );
      expect(day.entriesInGroup(MealType.breakfast), hasLength(2));
      expect(day.totalsInGroup(MealType.breakfast).kcal, 400);
      expect(day.totalsInGroup(MealType.lunch).kcal, 150);
      expect(day.totalsInGroup(MealType.dinner).kcal, 50);
      // Los registros antiguos conservan su tipo original.
      expect(day.entriesFor(MealType.afternoon), hasLength(1));
    });
  });

  group('Plantillas', () {
    test('cada objetivo del perfil sugiere una plantilla existente', () {
      for (final goal in AppConstants.goals) {
        expect(NutritionTemplate.forProfileGoal(goal), isNotNull, reason: goal);
      }
      expect(NutritionTemplate.forProfileGoal('Fuerza')!.id, 'masa-muscular');
      expect(
        NutritionTemplate.forProfileGoal('Perder grasa')!.id,
        'perdida-grasa',
      );
      expect(NutritionTemplate.forProfileGoal(null), isNull);
      expect(NutritionTemplate.forProfileGoal('Otro'), isNull);
    });

    test('existen las cuatro plantillas con sus valores orientativos', () {
      final byGoal = {for (final t in NutritionTemplate.all) t.goal: t};
      expect(byGoal.length, 4);
      final gain = byGoal[NutritionGoals.muscleGain]!;
      expect(
        [gain.calories, gain.protein, gain.carbs, gain.fat],
        [2500, 160, 300, 70],
      );
      final loss = byGoal[NutritionGoals.fatLoss]!;
      expect(
        [loss.calories, loss.protein, loss.carbs, loss.fat],
        [2000, 160, 200, 60],
      );
      expect(byGoal[NutritionGoals.maintenance]!.calories, 2200);
      expect(byGoal[NutritionGoals.balanced]!.calories, 2100);
      expect(
        gain.meals.keys,
        containsAll([
          MealType.breakfast,
          MealType.midMorning,
          MealType.lunch,
          MealType.afternoon,
          MealType.dinner,
        ]),
      );
    });

    test('usar una plantilla crea una copia editable del usuario', () async {
      final p = provider();
      await p.load();
      final template = NutritionTemplate.all[1];
      final plan = await p.useTemplate(template);
      expect(plan.templateId, template.id);
      expect(plan.active, isTrue); // es el primer plan
      expect(plan.meals, isNotEmpty);

      // Se edita la copia; la plantilla no cambia.
      await p.updatePlan(plan.copyWith(name: 'Mi definición', calories: 1900));
      expect(p.planById(plan.id)!.name, 'Mi definición');
      expect(p.planById(plan.id)!.calories, 1900);
      expect(NutritionTemplate.all[1].calories, 2000);

      final doc = await db.doc('users/u1/nutrition_plans/${plan.id}').get();
      expect(doc.data()!['name'], 'Mi definición');
    });
  });

  group('NutritionProvider', () {
    test('crear plan, activar (solo uno activo) y eliminar', () async {
      final p = provider();
      await p.load();
      var notifications = 0;
      p.addListener(() => notifications++);

      final first = await p.createPlan(
        name: 'Plan A',
        goal: NutritionGoals.custom,
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );
      final second = await p.createPlan(
        name: 'Plan B',
        goal: NutritionGoals.maintenance,
        calories: 2200,
        protein: 140,
        carbs: 250,
        fat: 70,
      );
      expect(first.active, isTrue);
      expect(second.active, isFalse);
      expect(notifications, 2);

      await p.setActivePlan(second.id);
      expect(p.activePlan!.id, second.id);
      final docs = await db.collection('users/u1/nutrition_plans').get();
      expect(docs.docs.where((d) => d.data()['active'] == true).length, 1);

      await p.deletePlan(second.id);
      expect(p.plans.single.id, first.id);
      expect(p.activePlan, isNull);
    });

    test('agregar comida, alimentos y cambiar cantidades', () async {
      final p = provider();
      await p.load();
      final plan = await p.createPlan(
        name: 'Plan',
        goal: NutritionGoals.custom,
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );
      final meal = NutritionMeal(type: MealType.breakfast, time: '08:00');
      await p.saveMeal(plan.id, meal);
      final oats = NutritionCatalog.byName('Avena').toFood(80);
      await p.saveFood(plan.id, meal.id, oats);
      await p.saveFood(
        plan.id,
        meal.id,
        NutritionCatalog.byName('Huevo').toFood(2),
      );
      var saved = p.planById(plan.id)!.mealById(meal.id)!;
      expect(saved.foods, hasLength(2));
      expect(saved.time, '08:00');
      expect(saved.totals.kcal, closeTo(389 * 0.8 + 144, 0.01));

      await p.saveFood(plan.id, meal.id, oats.withQuantity(40));
      saved = p.planById(plan.id)!.mealById(meal.id)!;
      expect(saved.foods.first.kcal, closeTo(389 * 0.4, 0.01));

      await p.deleteFood(plan.id, meal.id, oats.id);
      expect(
        p.planById(plan.id)!.mealById(meal.id)!.foods.single.name,
        'Huevo',
      );

      await p.deleteMeal(plan.id, meal.id);
      expect(p.planById(plan.id)!.meals, isEmpty);
    });

    test('el registro diario se suma y se separa del plan', () async {
      final p = provider();
      await p.load();
      await p.useTemplate(NutritionTemplate.all.first);
      await p.logFood(
        MealType.breakfast,
        NutritionCatalog.byName('Avena').toFood(100),
      );
      await p.logFood(
        MealType.lunch,
        NutritionCatalog.byName('Pollo (pechuga)').toFood(200),
      );
      expect(p.today.totals.kcal, closeTo(389 + 330, 0.01));
      expect(p.today.totals.protein, closeTo(17 + 62, 0.01));
      expect(p.today.entriesFor(MealType.dinner), isEmpty);
      // El plan no cambia al registrar consumo.
      expect(p.activePlan!.calories, 2500);
      expect(
        NutritionProvider.progress(p.today.totals.kcal, p.activePlan!.calories),
        closeTo(719 / 2500, 0.001),
      );

      final key = DailyNutritionRecord.keyOf(DateTime.now());
      final doc = await db.doc('users/u1/nutrition_days/$key').get();
      expect((doc.data()!['entries'] as List), hasLength(2));

      await p.removeEntry(p.today.entries.first.id);
      expect(p.today.entries, hasLength(1));

      // Se vuelve a leer igual desde Firestore.
      final reloaded = provider();
      await reloaded.load();
      expect(reloaded.today.totals.kcal, closeTo(330, 0.01));
      expect(reloaded.activePlan!.templateId, 'masa-muscular');
    });

    test('estadísticas: promedios de días registrados y cumplimiento', () {
      DailyNutritionRecord day(int d, double kcal) =>
          DailyNutritionRecord(date: DateTime(2026, 9, d)).withEntry(
            FoodEntry(
              mealType: MealType.lunch,
              food: _food('Comida', kcal, p: kcal / 20),
            ),
          );
      final stats = NutritionProvider.computeStats([
        day(1, 2000), // 100 %
        day(2, 1500), // 75 %
        day(3, 2150), // 107 %
        DailyNutritionRecord(date: DateTime(2026, 9, 4)), // sin registros
      ], 2000);
      expect(stats.daysRegistered, 3);
      expect(stats.average.kcal, closeTo(5650 / 3, 0.01));
      expect(stats.average.protein, closeTo(5650 / 3 / 20, 0.01));
      expect(stats.compliancePercent, 67); // 2 de 3 dentro del ±10 %

      final noPlan = NutritionProvider.computeStats([day(1, 2000)], 0);
      expect(noPlan.compliancePercent, 0);
      final empty = NutritionProvider.computeStats(const [], 2000);
      expect(empty.daysRegistered, 0);
      expect(empty.average.kcal, 0);
    });

    test('semana actual y últimos 7 días', () async {
      final p = provider();
      await p.load();
      await p.createPlan(
        name: 'Plan',
        goal: NutritionGoals.custom,
        calories: 400,
        protein: 20,
        carbs: 60,
        fat: 10,
      );
      await p.logFood(
        MealType.breakfast,
        NutritionCatalog.byName('Avena').toFood(),
      );
      expect(p.thisWeek, hasLength(7));
      expect(p.thisWeek.map((r) => r.totals.kcal).reduce((a, b) => a + b), 389);
      final stats = p.statsForLast(7);
      expect(stats.daysRegistered, 1);
      expect(stats.compliancePercent, 100); // 389 de 400 kcal
    });

    test('cada usuario solo ve sus propios datos', () async {
      final ana = provider('ana');
      await ana.load();
      await ana.useTemplate(NutritionTemplate.all.first);
      await ana.logFood(
        MealType.lunch,
        NutritionCatalog.byName('Arroz cocido').toFood(),
      );

      final bruno = provider('bruno');
      await bruno.load();
      expect(bruno.plans, isEmpty);
      expect(bruno.today.isEmpty, isTrue);
      expect(
        (await db.collection('users/ana/nutrition_plans').get()).docs,
        hasLength(1),
      );
      expect(
        (await db.collection('users/bruno/nutrition_plans').get()).docs,
        isEmpty,
      );
    });

    test(
      'objetivo diario: crea un plan activo o actualiza el actual',
      () async {
        final p = provider();
        await p.load();
        final created = await p.setDailyGoal(
          goal: NutritionGoals.custom,
          calories: 2200,
          protein: 140,
        );
        expect(p.plans, hasLength(1));
        expect(p.activePlan!.id, created.id);
        expect(p.activePlan!.name, NutritionProvider.dailyGoalPlanName);
        expect(p.activePlan!.calories, 2200);

        // Con un plan antiguo activo (con comidas), se actualiza ese mismo
        // plan y conserva sus comidas.
        final q = provider('u2');
        await q.load();
        final old = await q.useTemplate(NutritionTemplate.all.first);
        await q.setDailyGoal(
          goal: NutritionGoals.fatLoss,
          calories: 1900,
          protein: 150,
          templateId: 'perdida-grasa',
        );
        expect(q.plans, hasLength(1));
        expect(q.activePlan!.id, old.id);
        expect(q.activePlan!.calories, 1900);
        expect(q.activePlan!.templateId, 'perdida-grasa');
        expect(q.activePlan!.meals, isNotEmpty);
        final reloaded = provider('u2');
        await reloaded.load();
        expect(reloaded.activePlan!.protein, 150);
      },
    );

    test('reset borra los datos en memoria (cierre de sesión)', () async {
      final p = provider();
      await p.load();
      await p.useTemplate(NutritionTemplate.all.first);
      p.reset();
      expect(p.plans, isEmpty);
      expect(p.loaded, isFalse);
      await p.ensureLoaded();
      expect(p.plans, hasLength(1));
    });
  });

  group('Hidratación', () {
    String todayKey() => DailyNutritionRecord.keyOf(DateTime.now());

    test('el registro diario guarda el agua y la conserva al cambiar '
        'alimentos', () {
      final day = DailyNutritionRecord(date: DateTime(2026, 10, 1));
      expect(day.waterMl, 0);
      expect(day.hasNoData, isTrue);

      final withWater = day.withWater(500);
      expect(withWater.waterMl, 500);
      // Un día con solo agua no cuenta como día con comidas registradas.
      expect(withWater.isEmpty, isTrue);
      expect(withWater.hasNoData, isFalse);
      expect(day.withWater(-200).waterMl, 0);

      final entry = FoodEntry(
        mealType: MealType.lunch,
        food: _food('Arroz', 200),
      );
      final withFood = withWater.withEntry(entry);
      expect(withFood.waterMl, 500);
      expect(withFood.withoutEntry(entry.id).waterMl, 500);

      final restored = DailyNutritionRecord.fromMap(
        withFood.toMap(),
        id: withFood.dateKey,
      );
      expect(restored.waterMl, 500);
      expect(restored.entries, hasLength(1));
    });

    test('un registro antiguo sin el campo de agua se lee con 0 ml', () {
      final legacy = DailyNutritionRecord.fromMap(const {
        'dateKey': '2026-09-01',
        'entries': [],
      });
      expect(legacy.waterMl, 0);
      final damaged = DailyNutritionRecord.fromMap(const {
        'dateKey': '2026-09-01',
        'waterMl': 'mucha',
      });
      expect(damaged.waterMl, 0);
    });

    test('sumar, restar y guardar el agua de hoy', () async {
      final p = provider();
      await p.load();
      await p.addWater(250);
      await p.addWater(500);
      expect(p.today.waterMl, 750);

      final doc = await db.doc('users/u1/nutrition_days/${todayKey()}').get();
      expect(doc.data()!['waterMl'], 750);

      // Restar nunca deja un valor negativo.
      await p.addWater(-1000);
      expect(p.today.waterMl, 0);
      // Sin alimentos ni agua, el documento del día se borra.
      final deleted = await db
          .doc('users/u1/nutrition_days/${todayKey()}')
          .get();
      expect(deleted.exists, isFalse);

      await p.setWater(1500);
      final reloaded = provider();
      await reloaded.load();
      expect(reloaded.today.waterMl, 1500);
    });

    test('toques seguidos se acumulan sin perderse', () async {
      final p = provider();
      await p.load();
      await Future.wait([p.addWater(250), p.addWater(250), p.addWater(500)]);
      expect(p.today.waterMl, 1000);

      final reloaded = provider();
      await reloaded.load();
      expect(reloaded.today.waterMl, 1000);
    });

    test('agua y alimentos del mismo día no se pisan', () async {
      final p = provider();
      await p.load();
      await Future.wait([
        p.logFood(
          MealType.breakfast,
          NutritionCatalog.byName('Avena').toFood(),
        ),
        p.addWater(500),
      ]);
      await p.addWater(250);
      expect(p.today.entries, hasLength(1));
      expect(p.today.waterMl, 750);

      // Quitar el último alimento no borra el agua del día.
      await p.removeEntry(p.today.entries.single.id);
      expect(p.today.waterMl, 750);

      final reloaded = provider();
      await reloaded.load();
      expect(reloaded.today.entries, isEmpty);
      expect(reloaded.today.waterMl, 750);
      // Un día con solo agua no cuenta en las estadísticas de comidas.
      expect(reloaded.statsForLast(7).daysRegistered, 0);
    });

    test(
      'añadir agua antes de cargar no borra los alimentos del día',
      () async {
        final first = provider();
        await first.load();
        await first.logFood(
          MealType.lunch,
          NutritionCatalog.byName('Arroz cocido').toFood(),
        );

        final fresh = provider();
        await fresh.addWater(250);
        expect(fresh.today.entries, hasLength(1));
        final doc = await db.doc('users/u1/nutrition_days/${todayKey()}').get();
        expect(doc.data()!['entries'] as List, hasLength(1));
        expect(doc.data()!['waterMl'], 250);
      },
    );

    test('estadísticas de agua: media de días con registro y meta', () {
      DailyNutritionRecord day(int d, int ml) =>
          DailyNutritionRecord(date: DateTime(2026, 9, d), waterMl: ml);
      final stats = NutritionProvider.computeWaterStats([
        day(1, 2000),
        day(2, 1000),
        day(3, 2500),
        day(4, 0),
      ], 2000);
      expect(stats.daysRegistered, 3);
      expect(stats.averageMl, 1833);
      expect(stats.daysOnGoal, 2);

      final empty = NutritionProvider.computeWaterStats(const [], 2000);
      expect(empty.daysRegistered, 0);
      expect(empty.averageMl, 0);
    });

    test('la meta de agua se guarda por usuario y vuelve al cerrar '
        'sesión', () async {
      final ana = provider('ana');
      await ana.load();
      expect(ana.waterGoal, 2000);
      await ana.updateWaterGoal(2750);
      expect(ana.waterGoal, 2750);
      // Valores fuera de rango se ignoran.
      await ana.updateWaterGoal(0);
      await ana.updateWaterGoal(50000);
      expect(ana.waterGoal, 2750);

      final anaAgain = provider('ana');
      await anaAgain.load();
      expect(anaAgain.waterGoal, 2750);

      final bruno = provider('bruno');
      await bruno.load();
      expect(bruno.waterGoal, 2000);

      ana.reset();
      expect(ana.waterGoal, 2000);
      await ana.ensureLoaded();
      expect(ana.waterGoal, 2750);
    });
  });
}
