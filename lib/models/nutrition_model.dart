import '../core/utils/firestore_utils.dart';

/// Genera identificadores locales para comidas, alimentos y registros (que
/// viven dentro de un documento de Firestore).
int _idCounter = 0;
String nutritionId([String prefix = 'n']) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// Unidades de cantidad de un alimento.
enum FoodUnit {
  grams('g', 'gramos'),
  milliliters('ml', 'mililitros'),
  unit('ud.', 'unidad'),
  portion('porc.', 'porción');

  const FoodUnit(this.short, this.label);

  final String short;
  final String label;

  static FoodUnit fromName(String? name) => FoodUnit.values.firstWhere(
    (u) => u.name == name,
    orElse: () => FoodUnit.grams,
  );
}

/// Comidas del día, en orden.
enum MealType {
  breakfast('Desayuno'),
  midMorning('Media mañana'),
  lunch('Almuerzo'),
  afternoon('Merienda'),
  dinner('Cena'),
  snack('Snack');

  const MealType(this.label);

  final String label;

  static MealType fromName(String? name) => MealType.values.firstWhere(
    (m) => m.name == name,
    orElse: () => MealType.snack,
  );
}

/// Objetivos de plan disponibles.
abstract final class NutritionGoals {
  static const String muscleGain = 'Aumento de masa muscular';
  static const String fatLoss = 'Pérdida de grasa';
  static const String maintenance = 'Mantenimiento';
  static const String balanced = 'Alimentación equilibrada';
  static const String custom = 'Personalizado';

  static const List<String> all = [
    muscleGain,
    fatLoss,
    maintenance,
    balanced,
    custom,
  ];
}

/// Energía y macronutrientes. Inmutable; se suman con `+`.
class NutritionTotals {
  const NutritionTotals({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  static const NutritionTotals zero = NutritionTotals();

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  NutritionTotals operator +(NutritionTotals other) => NutritionTotals(
    kcal: kcal + other.kcal,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
  );

  NutritionTotals scale(double factor) => NutritionTotals(
    kcal: kcal * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
  );

  /// Suma de una colección de totales.
  static NutritionTotals sum(Iterable<NutritionTotals> items) =>
      items.fold(zero, (total, item) => total + item);
}

/// Un alimento con su cantidad y los valores nutricionales de esa cantidad.
///
/// Encapsulado e inmutable. [withQuantity] recalcula los valores en
/// proporción a la nueva cantidad.
class FoodItem {
  FoodItem({
    String? id,
    required this._name,
    required double quantity,
    this._unit = FoodUnit.grams,
    double kcal = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) : _id = id ?? nutritionId('f'),
       _quantity = quantity < 0 ? 0 : quantity,
       _kcal = kcal < 0 ? 0 : kcal,
       _protein = protein < 0 ? 0 : protein,
       _carbs = carbs < 0 ? 0 : carbs,
       _fat = fat < 0 ? 0 : fat;

  final String _id;
  final String _name;
  final double _quantity;
  final FoodUnit _unit;
  final double _kcal;
  final double _protein;
  final double _carbs;
  final double _fat;

  String get id => _id;
  String get name => _name;
  double get quantity => _quantity;
  FoodUnit get unit => _unit;
  double get kcal => _kcal;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fat => _fat;

  NutritionTotals get totals =>
      NutritionTotals(kcal: _kcal, protein: _protein, carbs: _carbs, fat: _fat);

  /// Copia con otra cantidad y valores proporcionales (misma unidad).
  FoodItem withQuantity(double quantity) {
    final factor = _quantity <= 0 ? 0.0 : quantity / _quantity;
    return FoodItem(
      id: _id,
      name: _name,
      quantity: quantity,
      unit: _unit,
      kcal: _kcal * factor,
      protein: _protein * factor,
      carbs: _carbs * factor,
      fat: _fat * factor,
    );
  }

  /// Copia con otro identificador (al copiar plantillas o registrar).
  FoodItem withNewId() => FoodItem(
    name: _name,
    quantity: _quantity,
    unit: _unit,
    kcal: _kcal,
    protein: _protein,
    carbs: _carbs,
    fat: _fat,
  );

  Map<String, dynamic> toMap() => {
    'id': _id,
    'name': _name,
    'quantity': _quantity,
    'unit': _unit.name,
    'kcal': _kcal,
    'protein': _protein,
    'carbs': _carbs,
    'fat': _fat,
  };

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
    id: map['id'] as String?,
    name: map['name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    unit: FoodUnit.fromName(map['unit'] as String?),
    kcal: (map['kcal'] as num?)?.toDouble() ?? 0,
    protein: (map['protein'] as num?)?.toDouble() ?? 0,
    carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
    fat: (map['fat'] as num?)?.toDouble() ?? 0,
  );
}

/// Una comida planificada (desayuno, almuerzo…) con sus alimentos.
class NutritionMeal {
  NutritionMeal({
    String? id,
    required this._type,
    String? name,
    this._time = '',
    List<FoodItem> foods = const [],
  }) : _id = id ?? nutritionId('m'),
       _name = (name == null || name.trim().isEmpty) ? _type.label : name,
       _foods = List.unmodifiable(foods);

  final String _id;
  final MealType _type;
  final String _name;

  /// Horario opcional, p. ej. "08:00".
  final String _time;
  final List<FoodItem> _foods;

  String get id => _id;
  MealType get type => _type;
  String get name => _name;
  String get time => _time;
  List<FoodItem> get foods => _foods;

  NutritionTotals get totals =>
      NutritionTotals.sum(_foods.map((f) => f.totals));

  NutritionMeal copyWith({
    MealType? type,
    String? name,
    String? time,
    List<FoodItem>? foods,
  }) => NutritionMeal(
    id: _id,
    type: type ?? _type,
    name: name ?? _name,
    time: time ?? _time,
    foods: foods ?? _foods,
  );

  Map<String, dynamic> toMap() => {
    'id': _id,
    'type': _type.name,
    'name': _name,
    'time': _time,
    'foods': [for (final f in _foods) f.toMap()],
  };

  factory NutritionMeal.fromMap(Map<String, dynamic> map) => NutritionMeal(
    id: map['id'] as String?,
    type: MealType.fromName(map['type'] as String?),
    name: map['name'] as String?,
    time: map['time'] as String? ?? '',
    foods: parseMapList(map['foods'], FoodItem.fromMap),
  );
}

/// Plan nutricional personal: objetivos diarios y comidas planificadas.
class NutritionPlan {
  NutritionPlan({
    required this._id,
    required this._name,
    this._goal = NutritionGoals.custom,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    List<NutritionMeal> meals = const [],
    this._active = false,
    this._templateId = '',
    this._createdAt,
    this._updatedAt,
  }) : _calories = calories < 0 ? 0 : calories,
       _protein = protein < 0 ? 0 : protein,
       _carbs = carbs < 0 ? 0 : carbs,
       _fat = fat < 0 ? 0 : fat,
       _meals = List.unmodifiable(
         [...meals]..sort((a, b) => a.type.index.compareTo(b.type.index)),
       );

  final String _id;
  final String _name;
  final String _goal;
  final double _calories;
  final double _protein;
  final double _carbs;
  final double _fat;
  final List<NutritionMeal> _meals;
  final bool _active;

  /// Plantilla de la que se copió (vacío si se creó a mano).
  final String _templateId;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  String get id => _id;
  String get name => _name;
  String get goal => _goal;
  double get calories => _calories;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fat => _fat;

  /// Comidas en el orden del día (desayuno → snack).
  List<NutritionMeal> get meals => _meals;
  bool get active => _active;
  String get templateId => _templateId;
  DateTime? get createdAt => _createdAt;
  DateTime? get updatedAt => _updatedAt;

  /// Objetivos diarios del plan.
  NutritionTotals get targets => NutritionTotals(
    kcal: _calories,
    protein: _protein,
    carbs: _carbs,
    fat: _fat,
  );

  /// Lo que suman los alimentos planificados en todas las comidas.
  NutritionTotals get plannedTotals =>
      NutritionTotals.sum(_meals.map((m) => m.totals));

  NutritionMeal? mealById(String id) {
    for (final meal in _meals) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  NutritionPlan copyWith({
    String? id,
    String? name,
    String? goal,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    List<NutritionMeal>? meals,
    bool? active,
    String? templateId,
  }) => NutritionPlan(
    id: id ?? _id,
    name: name ?? _name,
    goal: goal ?? _goal,
    calories: calories ?? _calories,
    protein: protein ?? _protein,
    carbs: carbs ?? _carbs,
    fat: fat ?? _fat,
    meals: meals ?? _meals,
    active: active ?? _active,
    templateId: templateId ?? _templateId,
    createdAt: _createdAt,
    updatedAt: DateTime.now(),
  );

  /// Copia una comida actualizada (o la agrega si no existía).
  NutritionPlan withMeal(NutritionMeal meal) {
    final exists = _meals.any((m) => m.id == meal.id);
    return copyWith(
      meals: exists
          ? [for (final m in _meals) m.id == meal.id ? meal : m]
          : [..._meals, meal],
    );
  }

  NutritionPlan withoutMeal(String mealId) => copyWith(
    meals: [
      for (final m in _meals)
        if (m.id != mealId) m,
    ],
  );

  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'name': _name,
      'goal': _goal,
      'calories': _calories,
      'protein': _protein,
      'carbs': _carbs,
      'fat': _fat,
      'meals': [for (final m in _meals) m.toMap()],
      'active': _active,
      'templateId': _templateId,
      'createdAt': _createdAt ?? now,
      'updatedAt': _updatedAt ?? now,
    };
  }

  factory NutritionPlan.fromMap(String id, Map<String, dynamic> map) =>
      NutritionPlan(
        id: id,
        name: map['name'] as String? ?? '',
        goal: map['goal'] as String? ?? NutritionGoals.custom,
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        meals: parseMapList(map['meals'], NutritionMeal.fromMap),
        active: map['active'] as bool? ?? false,
        templateId: map['templateId'] as String? ?? '',
        createdAt: firestoreDateFrom(map['createdAt']),
        updatedAt: firestoreDateFrom(map['updatedAt']),
      );
}

/// Un alimento que el usuario registró como consumido en una comida.
class FoodEntry {
  FoodEntry({
    String? id,
    required this._mealType,
    required this._food,
    DateTime? loggedAt,
  }) : _id = id ?? nutritionId('e'),
       _loggedAt = loggedAt ?? DateTime.now();

  final String _id;
  final MealType _mealType;
  final FoodItem _food;
  final DateTime _loggedAt;

  String get id => _id;
  MealType get mealType => _mealType;
  FoodItem get food => _food;
  DateTime get loggedAt => _loggedAt;

  Map<String, dynamic> toMap() => {
    'id': _id,
    'mealType': _mealType.name,
    'food': _food.toMap(),
    'loggedAt': _loggedAt,
  };

  factory FoodEntry.fromMap(Map<String, dynamic> map) => FoodEntry(
    id: map['id'] as String?,
    mealType: MealType.fromName(map['mealType'] as String?),
    // Sin `food` el registro no tiene sentido: el error hace que
    // `parseMapList` lo omita.
    food: FoodItem.fromMap(Map<String, dynamic>.from(map['food'] as Map)),
    loggedAt: firestoreDateFrom(map['loggedAt']),
  );
}

/// Lo que el usuario consumió realmente en un día (distinto del plan).
class DailyNutritionRecord {
  DailyNutritionRecord({
    required DateTime date,
    List<FoodEntry> entries = const [],
  }) : _date = DateTime(date.year, date.month, date.day),
       _entries = List.unmodifiable(entries);

  final DateTime _date;
  final List<FoodEntry> _entries;

  DateTime get date => _date;
  List<FoodEntry> get entries => _entries;

  /// Identificador del documento: "2026-10-01".
  String get dateKey => keyOf(_date);

  static String keyOf(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  NutritionTotals get totals =>
      NutritionTotals.sum(_entries.map((e) => e.food.totals));

  bool get isEmpty => _entries.isEmpty;

  List<FoodEntry> entriesFor(MealType type) => [
    for (final e in _entries)
      if (e.mealType == type) e,
  ];

  NutritionTotals totalsFor(MealType type) =>
      NutritionTotals.sum(entriesFor(type).map((e) => e.food.totals));

  DailyNutritionRecord withEntry(FoodEntry entry) =>
      DailyNutritionRecord(date: _date, entries: [..._entries, entry]);

  DailyNutritionRecord withoutEntry(String entryId) => DailyNutritionRecord(
    date: _date,
    entries: [
      for (final e in _entries)
        if (e.id != entryId) e,
    ],
  );

  Map<String, dynamic> toMap() => {
    'date': _date,
    'dateKey': dateKey,
    'entries': [for (final e in _entries) e.toMap()],
    'kcal': totals.kcal,
    'updatedAt': DateTime.now(),
  };

  /// [id] es el identificador del documento ("2026-10-01"): sirve de
  /// respaldo si se borraron los campos `date` y `dateKey`.
  factory DailyNutritionRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    final key = map['dateKey'] is String ? map['dateKey'] as String : id;
    final date =
        firestoreDateFrom(map['date']) ??
        (key == null ? null : DateTime.tryParse(key)) ??
        DateTime.now();
    return DailyNutritionRecord(
      date: date,
      entries: parseMapList(map['entries'], FoodEntry.fromMap),
    );
  }
}

/// Lee una lista de mapas de Firestore omitiendo los elementos dañados o
/// incompletos (por ejemplo, si se borró parte de un documento a mano):
/// un elemento inválido no debe impedir cargar el resto.
List<T> parseMapList<T>(
  Object? raw,
  T Function(Map<String, dynamic> map) parse,
) {
  if (raw is! List) return const [];
  final result = <T>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      result.add(parse(Map<String, dynamic>.from(item)));
    } catch (_) {
      // Elemento inválido: se omite.
    }
  }
  return result;
}
