import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/nutrition_catalog.dart';
import '../models/nutrition_model.dart';
import '../services/app_firebase.dart';
import '../services/firestore_service.dart';
import '../services/nutrition_service.dart';
import 'progress_provider.dart';

/// Estadísticas del consumo registrado en un periodo.
typedef NutritionStats = ({
  int daysRegistered,
  NutritionTotals average,

  /// Porcentaje de días registrados con calorías entre el 90 % y el 110 %
  /// del objetivo del plan activo (0 si no hay plan activo).
  int compliancePercent,
});

/// Estado global de Alimentación del usuario autenticado: sus planes, el
/// plan activo, las comidas y alimentos de cada plan y el consumo diario.
///
/// El plan (lo planificado) y el consumo (lo registrado) son datos
/// distintos: el progreso compara el consumo con los objetivos del plan.
class NutritionProvider extends ChangeNotifier {
  NutritionProvider({NutritionService? service, this._currentUid})
    : _serviceOverride = service;

  final NutritionService? _serviceOverride;
  final String? Function()? _currentUid;
  NutritionService? _lazyService;
  NutritionService get _service =>
      _serviceOverride ?? (_lazyService ??= NutritionService());

  /// Días de consumo que se cargan (4 semanas).
  static const int historyDays = 28;

  List<NutritionPlan> _plans = [];
  final Map<String, DailyNutritionRecord> _days = {};
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  List<NutritionPlan> get plans => List.unmodifiable(_plans);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  String? get _uid =>
      _currentUid != null ? _currentUid() : AppFirebase.auth.currentUser?.uid;

  NutritionPlan? get activePlan {
    for (final plan in _plans) {
      if (plan.active) return plan;
    }
    return null;
  }

  NutritionPlan? planById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Consumo registrado en [date] (vacío si no hay registros).
  DailyNutritionRecord recordFor(DateTime date) =>
      _days[DailyNutritionRecord.keyOf(date)] ??
      DailyNutritionRecord(date: date);

  DailyNutritionRecord get today => recordFor(DateTime.now());

  // -------------------------------------------------------------- carga

  /// Carga los datos solo si todavía no se cargaron.
  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading) await load();
  }

  /// Tiempo máximo de espera de la carga: pasado este tiempo se muestra un
  /// error con "Reintentar" en lugar de quedarse cargando para siempre.
  static const Duration loadTimeout = Duration(seconds: 15);

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      // Antes la carga terminaba en silencio y la pantalla se quedaba
      // cargando sin fin.
      _error = 'No hay una sesión activa. Vuelve a iniciar sesión.';
      notifyListeners();
      return;
    }
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final from = _day(DateTime.now())
          .subtract(const Duration(days: historyDays - 1));
      final results = await Future.wait([
        _service.getPlans(uid),
        _service.getDays(uid, from),
      ]).timeout(loadTimeout);
      if (generation != _generation) return;
      _plans = (results[0] as List).cast<NutritionPlan>();
      _days
        ..clear()
        ..addEntries(
          (results[1] as List).cast<DailyNutritionRecord>().map(
            (r) => MapEntry(r.dateKey, r),
          ),
        );
      _loaded = true;
    } catch (error) {
      if (generation != _generation) return;
      _error = error is TimeoutException
          ? 'La carga tardó demasiado. Revisa tu conexión e inténtalo de '
                'nuevo.'
          : ProgressProvider.describeError(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Borra los datos en memoria al cerrar sesión.
  void reset() {
    _generation++;
    _plans = [];
    _days.clear();
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  // -------------------------------------------------------------- planes

  String get _requireUid {
    final uid = _uid;
    if (uid == null) throw StateError('No hay una sesión activa.');
    return uid;
  }

  /// Crea un plan propio. Si es el único plan, queda como activo.
  Future<NutritionPlan> createPlan({
    required String name,
    required String goal,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final uid = _requireUid;
    final plan = NutritionPlan(
      id: _service.newDocId,
      name: name.trim(),
      goal: goal,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      active: activePlan == null,
    );
    await _service.savePlan(uid, plan);
    _plans = [..._plans, plan];
    notifyListeners();
    return plan;
  }

  /// Crea una copia editable de la plantilla para el usuario.
  Future<NutritionPlan> useTemplate(NutritionTemplate template) async {
    final uid = _requireUid;
    final plan = template.toPlan(
      id: _service.newDocId,
      active: activePlan == null,
    );
    await _service.savePlan(uid, plan);
    _plans = [..._plans, plan];
    notifyListeners();
    return plan;
  }

  Future<void> updatePlan(NutritionPlan plan) async {
    final uid = _requireUid;
    await _service.savePlan(uid, plan);
    _plans = [for (final p in _plans) p.id == plan.id ? plan : p];
    notifyListeners();
  }

  Future<void> deletePlan(String planId) async {
    final uid = _requireUid;
    await _service.deletePlan(uid, planId);
    _plans = [
      for (final p in _plans)
        if (p.id != planId) p,
    ];
    notifyListeners();
  }

  /// Deja [planId] como único plan activo (o ninguno si es `null`).
  Future<void> setActivePlan(String? planId) async {
    final uid = _requireUid;
    await _service.setActivePlan(uid, planId, _plans.map((p) => p.id));
    _plans = [for (final p in _plans) p.copyWith(active: p.id == planId)];
    notifyListeners();
  }

  // ------------------------------------------------------------- comidas

  Future<void> saveMeal(String planId, NutritionMeal meal) async {
    final plan = planById(planId);
    if (plan == null) return;
    await updatePlan(plan.withMeal(meal));
  }

  Future<void> deleteMeal(String planId, String mealId) async {
    final plan = planById(planId);
    if (plan == null) return;
    await updatePlan(plan.withoutMeal(mealId));
  }

  /// Agrega o reemplaza un alimento de una comida del plan.
  Future<void> saveFood(String planId, String mealId, FoodItem food) async {
    final meal = planById(planId)?.mealById(mealId);
    if (meal == null) return;
    final exists = meal.foods.any((f) => f.id == food.id);
    await saveMeal(
      planId,
      meal.copyWith(
        foods: exists
            ? [for (final f in meal.foods) f.id == food.id ? food : f]
            : [...meal.foods, food],
      ),
    );
  }

  Future<void> deleteFood(String planId, String mealId, String foodId) async {
    final meal = planById(planId)?.mealById(mealId);
    if (meal == null) return;
    await saveMeal(
      planId,
      meal.copyWith(
        foods: [
          for (final f in meal.foods)
            if (f.id != foodId) f,
        ],
      ),
    );
  }

  // ------------------------------------------------------ consumo diario

  /// Registra un alimento consumido en la comida [mealType] de [date] (hoy
  /// por defecto). Se suma automáticamente al consumo del día.
  Future<void> logFood(
    MealType mealType,
    FoodItem food, {
    DateTime? date,
  }) async {
    final uid = _requireUid;
    final record = recordFor(date ?? DateTime.now())
        .withEntry(FoodEntry(mealType: mealType, food: food.withNewId()));
    await _service.saveDay(uid, record);
    _days[record.dateKey] = record;
    notifyListeners();
  }

  Future<void> removeEntry(String entryId, {DateTime? date}) async {
    final uid = _requireUid;
    final record = recordFor(date ?? DateTime.now()).withoutEntry(entryId);
    await _service.saveDay(uid, record);
    if (record.isEmpty) {
      _days.remove(record.dateKey);
    } else {
      _days[record.dateKey] = record;
    }
    notifyListeners();
  }

  // --------------------------------------------------------- estadísticas

  /// Consumo de cada día de la semana actual (lunes a domingo).
  List<DailyNutritionRecord> get thisWeek {
    final monday = FirestoreService.weekStartOf(DateTime.now());
    return [
      for (var i = 0; i < 7; i++)
        recordFor(DateTime(monday.year, monday.month, monday.day + i)),
    ];
  }

  /// Estadísticas de los últimos [days] días.
  NutritionStats statsForLast(int days) {
    final today = _day(DateTime.now());
    final records = [
      for (var i = 0; i < days; i++)
        recordFor(DateTime(today.year, today.month, today.day - i)),
    ];
    return computeStats(records, activePlan?.calories ?? 0);
  }

  /// Calcula promedios (solo de los días con registros) y cumplimiento.
  @visibleForTesting
  static NutritionStats computeStats(
    Iterable<DailyNutritionRecord> records,
    double calorieTarget,
  ) {
    final registered = records.where((r) => !r.isEmpty).toList();
    if (registered.isEmpty) {
      return (
        daysRegistered: 0,
        average: NutritionTotals.zero,
        compliancePercent: 0,
      );
    }
    final total = NutritionTotals.sum(registered.map((r) => r.totals));
    var onTarget = 0;
    if (calorieTarget > 0) {
      for (final record in registered) {
        final ratio = record.totals.kcal / calorieTarget;
        if (ratio >= 0.9 && ratio <= 1.1) onTarget++;
      }
    }
    return (
      daysRegistered: registered.length,
      average: total.scale(1 / registered.length),
      compliancePercent: calorieTarget > 0
          ? (onTarget / registered.length * 100).round()
          : 0,
    );
  }

  /// Avance (0–1, sin pasar de 1) del consumo respecto de un objetivo.
  static double progress(double consumed, double target) {
    if (target <= 0) return 0;
    final ratio = consumed / target;
    return ratio > 1 ? 1 : ratio;
  }
}
