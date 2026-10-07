import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
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

/// Estadísticas del agua registrada en un periodo.
typedef WaterStats = ({
  /// Días con algo de agua registrada.
  int daysRegistered,

  /// Media en ml de los días con registro.
  int averageMl,

  /// Días en que se alcanzó la meta diaria.
  int daysOnGoal,
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
  int _waterGoal = AppConstants.defaultWaterGoalMl;
  String? _waterGoalUid;

  List<NutritionPlan> get plans => List.unmodifiable(_plans);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Meta diaria de agua en ml (se guarda en el dispositivo por usuario).
  int get waterGoal => _waterGoal;

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

  /// Días con registros cargados (los últimos [historyDays]).
  List<DailyNutritionRecord> get loadedDays => List.unmodifiable(_days.values);

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
      final results = await Future.wait<Object?>([
        _service.getPlans(uid),
        _service.getDays(uid, from),
        // La meta de agua va dentro del mismo límite de tiempo: si el
        // almacenamiento no responde, la carga no debe quedarse colgada.
        if (_waterGoalUid != uid) _readWaterGoal(uid),
      ]).timeout(loadTimeout);
      if (generation != _generation) return;
      if (results.length > 2) {
        _waterGoal = results[2] as int;
        _waterGoalUid = uid;
      }
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
    _waterGoal = AppConstants.defaultWaterGoalMl;
    _waterGoalUid = null;
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

  /// Nombre del plan que guarda el objetivo diario simplificado.
  static const String dailyGoalPlanName = 'Mi objetivo diario';

  /// Fija el objetivo diario (pantalla Comida). Se guarda en el plan activo
  /// (un plan antiguo conserva sus comidas) o, si no hay, en un plan nuevo
  /// que queda activo: así los datos existentes, las estadísticas y los
  /// logros siguen funcionando igual.
  Future<NutritionPlan> setDailyGoal({
    required String goal,
    required double calories,
    required double protein,
    double carbs = 0,
    double fat = 0,
    String templateId = '',
  }) async {
    final uid = _requireUid;
    final current = activePlan;
    if (current != null) {
      final updated = current.copyWith(
        goal: goal,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        templateId: templateId,
      );
      await updatePlan(updated);
      return updated;
    }
    final plan = NutritionPlan(
      id: _service.newDocId,
      name: dailyGoalPlanName,
      goal: goal,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      active: true,
      templateId: templateId,
    );
    await _service.savePlan(uid, plan);
    _plans = [..._plans, plan];
    notifyListeners();
    return plan;
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
  Future<void> logFood(MealType mealType, FoodItem food, {DateTime? date}) =>
      _updateDay(
        date,
        (day) => day.withEntry(
          FoodEntry(mealType: mealType, food: food.withNewId()),
        ),
      );

  Future<void> removeEntry(String entryId, {DateTime? date}) =>
      _updateDay(date, (day) => day.withoutEntry(entryId));

  /// Aplica [change] al día [date] (hoy por defecto) y lo guarda.
  ///
  /// La memoria se actualiza antes de escribir en Firestore: así, varios
  /// cambios seguidos (dos toques en "+250 ml", o agua mientras se registra
  /// un alimento) parten siempre del último estado y no se pisan entre sí.
  /// Si la escritura falla se vuelve al estado anterior (salvo que otro
  /// cambio posterior ya lo haya reemplazado) y se relanza el error.
  Future<void> _updateDay(
    DateTime? date,
    DailyNutritionRecord Function(DailyNutritionRecord day) change,
  ) async {
    final uid = _requireUid;
    final generation = _generation;
    final previous = recordFor(date ?? DateTime.now());
    final record = change(previous);
    _store(record);
    notifyListeners();
    try {
      await _service.saveDay(uid, record);
    } catch (_) {
      final stored = _days[record.dateKey];
      final unchanged =
          identical(stored, record) || (stored == null && record.hasNoData);
      if (generation == _generation && unchanged) {
        _store(previous);
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Guarda [record] en memoria; un día sin alimentos ni agua se quita.
  void _store(DailyNutritionRecord record) {
    if (record.hasNoData) {
      _days.remove(record.dateKey);
    } else {
      _days[record.dateKey] = record;
    }
  }

  // ---------------------------------------------------------------- agua

  /// Suma [ml] de agua a [date] (hoy por defecto). Con un valor negativo
  /// resta, sin bajar de 0.
  Future<void> addWater(int ml, {DateTime? date}) =>
      _updateWater(date, (current) => current + ml);

  /// Fija el agua de [date] (hoy por defecto) en [ml].
  Future<void> setWater(int ml, {DateTime? date}) =>
      _updateWater(date, (_) => ml);

  /// [next] recibe el agua que hay en memoria justo al aplicar el cambio
  /// (no antes de esperar la carga), para que los toques seguidos se sumen.
  Future<void> _updateWater(
    DateTime? date,
    int Function(int current) next,
  ) async {
    await _requireLoaded();
    await _updateDay(
      date,
      (day) => day.withWater(
        next(day.waterMl).clamp(0, AppConstants.maxWaterPerDayMl),
      ),
    );
  }

  /// `saveDay` reemplaza el documento del día: escribir sin haber cargado
  /// los datos borraría los alimentos ya registrados. Solo se pueden
  /// cambiar los días cargados (los últimos [historyDays]).
  Future<void> _requireLoaded() async {
    if (!_loaded) await ensureLoaded();
    if (!_loaded) {
      throw StateError('Los datos de alimentación todavía no se cargaron.');
    }
  }

  /// Cambia la meta diaria de agua y la guarda en el dispositivo.
  Future<void> updateWaterGoal(int ml) async {
    if (ml <= 0 || ml > AppConstants.maxWaterGoalMl) return;
    _waterGoal = ml;
    notifyListeners();
    final uid = _waterGoalUid ?? _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('water_goal_$uid', ml);
    } catch (_) {
      // Si no se puede guardar, la meta sigue aplicada en esta sesión.
    }
  }

  /// Meta de agua guardada en el dispositivo, o la meta por defecto si no
  /// hay ninguna o el almacenamiento no responde a tiempo.
  Future<int> _readWaterGoal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
      );
      return prefs.getInt('water_goal_$uid') ?? AppConstants.defaultWaterGoalMl;
    } catch (_) {
      return AppConstants.defaultWaterGoalMl;
    }
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

  /// Agua de los últimos [days] días frente a la meta actual.
  WaterStats waterStatsForLast(int days) {
    final today = _day(DateTime.now());
    return computeWaterStats([
      for (var i = 0; i < days; i++)
        recordFor(DateTime(today.year, today.month, today.day - i)),
    ], _waterGoal);
  }

  /// Media (solo de los días con agua registrada) y días con la meta.
  @visibleForTesting
  static WaterStats computeWaterStats(
    Iterable<DailyNutritionRecord> records,
    int goalMl,
  ) {
    final registered = records.where((r) => r.waterMl > 0).toList();
    if (registered.isEmpty) {
      return (daysRegistered: 0, averageMl: 0, daysOnGoal: 0);
    }
    final total = registered.fold<int>(0, (sum, r) => sum + r.waterMl);
    return (
      daysRegistered: registered.length,
      averageMl: (total / registered.length).round(),
      daysOnGoal: goalMl <= 0
          ? 0
          : registered.where((r) => r.waterMl >= goalMl).length,
    );
  }

  /// Avance (0–1, sin pasar de 1) del consumo respecto de un objetivo.
  static double progress(double consumed, double target) {
    if (target <= 0) return 0;
    final ratio = consumed / target;
    return ratio > 1 ? 1 : ratio;
  }
}
