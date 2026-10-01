import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitprogress/core/constants/nutrition_catalog.dart';
import 'package:fitprogress/models/nutrition_model.dart';
import 'package:fitprogress/providers/nutrition_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:fitprogress/services/nutrition_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servicio cuya carga nunca termina (red colgada).
class _HangingService extends NutritionService {
  @override
  Future<List<NutritionPlan>> getPlans(String uid) =>
      Completer<List<NutritionPlan>>().future;
}

/// Datos borrados a mano en la consola de Firebase: la sección de
/// Alimentación debe cargar igualmente (y reparar lo que pueda).
void main() {
  late FakeFirebaseFirestore db;
  const uid = 'u1';

  setUp(() {
    db = FakeFirebaseFirestore();
    AppFirebase.firestoreOverride = db;
  });

  tearDown(() => AppFirebase.firestoreOverride = null);

  NutritionProvider provider() => NutritionProvider(currentUid: () => uid);

  Map<String, dynamic> templatePlanMap() =>
      NutritionTemplate.all.first.toPlan(id: 'p1', active: true).toMap();

  test('un plan sin createdAt sigue apareciendo', () async {
    final data = templatePlanMap()..remove('createdAt');
    await db.doc('users/$uid/nutrition_plans/p1').set(data);
    final p = provider();
    await p.load();
    expect(p.loaded, isTrue);
    expect(p.plans.single.id, 'p1');
    expect(p.activePlan?.id, 'p1');
  });

  test(
    'restaura desde la plantilla los campos borrados y los guarda',
    () async {
      final data = templatePlanMap()
        ..remove('meals')
        ..remove('calories')
        ..remove('name');
      await db.doc('users/$uid/nutrition_plans/p1').set(data);

      final p = provider();
      await p.load();
      final plan = p.plans.single;
      final template = NutritionTemplate.all.first;
      expect(plan.name, template.name);
      expect(plan.calories, template.calories);
      expect(plan.meals, hasLength(template.meals.length));
      expect(plan.active, isTrue);

      // La versión reparada queda guardada en Firestore.
      await pumpEventQueue();
      final saved = (await db.doc('users/$uid/nutrition_plans/p1').get())
          .data()!;
      expect(saved['name'], template.name);
      expect(saved['calories'], template.calories);
      expect((saved['meals'] as List), hasLength(template.meals.length));
    },
  );

  test('reconoce la plantilla por el nombre si se borró templateId', () {
    final data = templatePlanMap()
      ..remove('templateId')
      ..remove('meals');
    final (:plan, :repaired) = NutritionService.restorePlan('p1', data);
    expect(repaired, isTrue);
    expect(plan.templateId, 'masa-muscular');
    expect(plan.meals, isNotEmpty);
  });

  test('una lista de comidas vacía se respeta (no se restaura)', () {
    final data = templatePlanMap()..['meals'] = <Object>[];
    final (:plan, :repaired) = NutritionService.restorePlan('p1', data);
    expect(repaired, isFalse);
    expect(plan.meals, isEmpty);
  });

  test('un plan propio incompleto usa valores por defecto', () {
    final (:plan, :repaired) = NutritionService.restorePlan('x', {
      'goal': NutritionGoals.custom,
    });
    expect(repaired, isTrue);
    expect(plan.name, 'Mi plan');
    expect(plan.meals, isEmpty);
  });

  test('comidas, alimentos y registros dañados se omiten', () async {
    final data = templatePlanMap();
    final meals = List<Object?>.from(data['meals'] as List);
    final firstMeal = Map<String, dynamic>.from(meals.first as Map);
    firstMeal['foods'] = [
      null,
      'no es un mapa',
      NutritionCatalog.byName('Avena').toFood().toMap(),
    ];
    meals[0] = firstMeal;
    meals.add(null);
    data['meals'] = meals;
    await db.doc('users/$uid/nutrition_plans/p1').set(data);

    final key = DailyNutritionRecord.keyOf(DateTime.now());
    await db.doc('users/$uid/nutrition_days/$key').set({
      // Se borraron `date` y `dateKey`; además hay un registro sin alimento.
      'entries': [
        {'id': 'roto', 'mealType': 'lunch'},
        FoodEntry(
          mealType: MealType.lunch,
          food: NutritionCatalog.byName('Huevo').toFood(2),
        ).toMap(),
      ],
    });

    final p = provider();
    await p.load();
    expect(p.error, isNull);
    final plan = p.plans.single;
    expect(plan.meals.first.foods.single.name, 'Avena');
    expect(plan.meals, hasLength(NutritionTemplate.all.first.meals.length));
    expect(p.today.entries.single.food.name, 'Huevo');
    expect(p.today.totals.kcal, 144);
  });

  test('activar un plan no falla si otro se borró a mano', () async {
    final p = provider();
    await p.load();
    final a = await p.useTemplate(NutritionTemplate.all[0]);
    final b = await p.useTemplate(NutritionTemplate.all[1]);
    await db.doc('users/$uid/nutrition_plans/${a.id}').delete();
    await p.setActivePlan(b.id);
    expect(p.activePlan?.id, b.id);
  });

  test('sin sesión muestra un error en lugar de cargar para siempre', () async {
    final p = NutritionProvider(currentUid: () => null);
    await p.load();
    expect(p.loaded, isFalse);
    expect(p.error, contains('sesión'));
  });

  // testWidgets usa un reloj simulado: se avanza el tiempo sin esperar.
  testWidgets('si Firestore no responde, la carga termina con un error', (
    tester,
  ) async {
    final p = NutritionProvider(
      service: _HangingService(),
      currentUid: () => uid,
    );
    unawaited(p.load());
    expect(p.loading, isTrue);
    await tester.pump(
      NutritionProvider.loadTimeout + const Duration(seconds: 1),
    );
    expect(p.loading, isFalse);
    expect(p.loaded, isFalse);
    expect(p.error, contains('tardó demasiado'));
  });
}
