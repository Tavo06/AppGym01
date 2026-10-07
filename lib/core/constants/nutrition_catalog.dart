import 'package:flutter/material.dart';

import '../../models/nutrition_model.dart';

/// Alimento del catálogo local con valores de referencia para una cantidad
/// ([quantity] en [unit]). Los valores son aproximados y orientativos.
class CatalogFood {
  const CatalogFood({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.icon = Icons.restaurant_rounded,
  });

  final String name;
  final double quantity;
  final FoodUnit unit;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Icono Material del alimento. No se usan emojis: en Flutter Web obligan
  /// a descargar y procesar una fuente de emojis de varios MB, lo que
  /// congelaba la página al abrir un plan.
  final IconData icon;

  /// Alimento con los valores proporcionales a [amount].
  FoodItem toFood([double? amount]) => FoodItem(
    name: name,
    quantity: quantity,
    unit: unit,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
  ).withQuantity(amount ?? quantity);
}

/// Alimentos comunes para elegir rápido (sin API externa).
abstract final class NutritionCatalog {
  static const List<CatalogFood> foods = [
    CatalogFood(
      name: 'Avena',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 389,
      protein: 17,
      carbs: 66,
      fat: 7,
      icon: Icons.breakfast_dining_rounded,
    ),
    CatalogFood(
      name: 'Arroz cocido',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
      icon: Icons.rice_bowl_rounded,
    ),
    CatalogFood(
      name: 'Pollo (pechuga)',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 165,
      protein: 31,
      carbs: 0,
      fat: 3.6,
      icon: Icons.kebab_dining_rounded,
    ),
    CatalogFood(
      name: 'Huevo',
      quantity: 1,
      unit: FoodUnit.unit,
      kcal: 72,
      protein: 6.3,
      carbs: 0.4,
      fat: 4.8,
      icon: Icons.egg_rounded,
    ),
    CatalogFood(
      name: 'Atún al natural',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 116,
      protein: 26,
      carbs: 0,
      fat: 1,
      icon: Icons.set_meal_rounded,
    ),
    CatalogFood(
      name: 'Pescado blanco',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 105,
      protein: 23,
      carbs: 0,
      fat: 1,
      icon: Icons.set_meal_rounded,
    ),
    CatalogFood(
      name: 'Papa cocida',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 87,
      protein: 1.9,
      carbs: 20,
      fat: 0.1,
      icon: Icons.lunch_dining_rounded,
    ),
    CatalogFood(
      name: 'Camote cocido',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 90,
      protein: 2,
      carbs: 21,
      fat: 0.1,
      icon: Icons.lunch_dining_rounded,
    ),
    CatalogFood(
      name: 'Plátano',
      quantity: 1,
      unit: FoodUnit.unit,
      kcal: 105,
      protein: 1.3,
      carbs: 27,
      fat: 0.4,
      icon: Icons.spa_rounded,
    ),
    CatalogFood(
      name: 'Manzana',
      quantity: 1,
      unit: FoodUnit.unit,
      kcal: 95,
      protein: 0.5,
      carbs: 25,
      fat: 0.3,
      icon: Icons.spa_rounded,
    ),
    CatalogFood(
      name: 'Fruta variada',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 55,
      protein: 0.7,
      carbs: 14,
      fat: 0.2,
      icon: Icons.spa_rounded,
    ),
    CatalogFood(
      name: 'Yogur natural',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 61,
      protein: 3.5,
      carbs: 4.7,
      fat: 3.3,
      icon: Icons.local_drink_rounded,
    ),
    CatalogFood(
      name: 'Leche',
      quantity: 100,
      unit: FoodUnit.milliliters,
      kcal: 61,
      protein: 3.2,
      carbs: 4.8,
      fat: 3.3,
      icon: Icons.local_drink_rounded,
    ),
    CatalogFood(
      name: 'Pan integral',
      quantity: 1,
      unit: FoodUnit.portion,
      kcal: 75,
      protein: 3.6,
      carbs: 12.6,
      fat: 1,
      icon: Icons.bakery_dining_rounded,
    ),
    CatalogFood(
      name: 'Palta',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 160,
      protein: 2,
      carbs: 8.5,
      fat: 14.7,
      icon: Icons.eco_rounded,
    ),
    CatalogFood(
      name: 'Frutos secos',
      quantity: 1,
      unit: FoodUnit.portion,
      kcal: 180,
      protein: 5,
      carbs: 6,
      fat: 16,
      icon: Icons.cookie_rounded,
    ),
    CatalogFood(
      name: 'Verduras',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 35,
      protein: 2,
      carbs: 7,
      fat: 0.3,
      icon: Icons.grass_rounded,
    ),
    CatalogFood(
      name: 'Ensalada',
      quantity: 100,
      unit: FoodUnit.grams,
      kcal: 20,
      protein: 1.2,
      carbs: 3.5,
      fat: 0.2,
      icon: Icons.grass_rounded,
    ),
    CatalogFood(
      name: 'Aceite de oliva',
      quantity: 1,
      unit: FoodUnit.portion,
      kcal: 88,
      protein: 0,
      carbs: 0,
      fat: 10,
      icon: Icons.water_drop_rounded,
    ),
  ];

  static CatalogFood byName(String name) =>
      foods.firstWhere((f) => f.name == name);

  /// Icono del alimento si está en el catálogo (por nombre); si no, uno
  /// genérico.
  static IconData iconFor(String name) {
    final key = name.toLowerCase();
    for (final food in foods) {
      if (food.name.toLowerCase() == key) return food.icon;
    }
    return Icons.restaurant_rounded;
  }
}

/// Plantilla de plan nutricional (ejemplo orientativo, no una recomendación
/// médica). Al usarla se crea una copia editable para el usuario.
class NutritionTemplate {
  const NutritionTemplate({
    required this.id,
    required this.name,
    required this.goal,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.meals,
  });

  final String id;
  final String name;
  final String goal;
  final String description;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Comidas: tipo → lista de (alimento del catálogo, cantidad).
  final Map<MealType, List<(String, double)>> meals;

  /// Plan nuevo del usuario a partir de la plantilla (todo editable).
  NutritionPlan toPlan({required String id, bool active = false}) =>
      NutritionPlan(
        id: id,
        name: name,
        goal: goal,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        active: active,
        templateId: this.id,
        meals: [
          for (final entry in meals.entries)
            NutritionMeal(
              type: entry.key,
              foods: [
                for (final (food, amount) in entry.value)
                  NutritionCatalog.byName(food).toFood(amount),
              ],
            ),
        ],
      );

  NutritionTotals get targets =>
      NutritionTotals(kcal: calories, protein: protein, carbs: carbs, fat: fat);

  static const List<NutritionTemplate> all = [
    NutritionTemplate(
      id: 'masa-muscular',
      name: 'Aumento de masa muscular',
      goal: NutritionGoals.muscleGain,
      description:
          'Más energía y proteína repartidas en cinco comidas para '
          'acompañar el entrenamiento de fuerza.',
      calories: 2500,
      protein: 160,
      carbs: 300,
      fat: 70,
      meals: {
        MealType.breakfast: [
          ('Avena', 80),
          ('Plátano', 1),
          ('Huevo', 3),
          ('Leche', 250),
        ],
        MealType.midMorning: [
          ('Yogur natural', 200),
          ('Fruta variada', 150),
          ('Frutos secos', 1),
        ],
        MealType.lunch: [
          ('Pollo (pechuga)', 180),
          ('Arroz cocido', 250),
          ('Ensalada', 150),
          ('Palta', 50),
        ],
        MealType.afternoon: [
          ('Yogur natural', 150),
          ('Avena', 40),
          ('Fruta variada', 100),
        ],
        MealType.dinner: [
          ('Pescado blanco', 180),
          ('Papa cocida', 250),
          ('Verduras', 200),
          ('Aceite de oliva', 1),
        ],
      },
    ),
    NutritionTemplate(
      id: 'perdida-grasa',
      name: 'Pérdida de grasa',
      goal: NutritionGoals.fatLoss,
      description:
          'Proteína alta, porciones moderadas de carbohidratos y muchas '
          'verduras para sentir saciedad.',
      calories: 2000,
      protein: 160,
      carbs: 200,
      fat: 60,
      meals: {
        MealType.breakfast: [('Avena', 50), ('Huevo', 2), ('Manzana', 1)],
        MealType.midMorning: [('Yogur natural', 150), ('Fruta variada', 100)],
        MealType.lunch: [
          ('Pollo (pechuga)', 170),
          ('Arroz cocido', 150),
          ('Ensalada', 200),
          ('Aceite de oliva', 1),
        ],
        MealType.afternoon: [('Yogur natural', 125), ('Frutos secos', 1)],
        MealType.dinner: [
          ('Pescado blanco', 180),
          ('Camote cocido', 150),
          ('Verduras', 250),
        ],
      },
    ),
    NutritionTemplate(
      id: 'mantenimiento',
      name: 'Mantenimiento',
      goal: NutritionGoals.maintenance,
      description:
          'Reparto estable de energía para mantener tu peso actual mientras '
          'entrenas.',
      calories: 2200,
      protein: 150,
      carbs: 250,
      fat: 65,
      meals: {
        MealType.breakfast: [
          ('Avena', 60),
          ('Huevo', 2),
          ('Plátano', 1),
          ('Leche', 200),
        ],
        MealType.midMorning: [('Yogur natural', 150), ('Fruta variada', 100)],
        MealType.lunch: [
          ('Pollo (pechuga)', 160),
          ('Arroz cocido', 200),
          ('Ensalada', 150),
          ('Palta', 40),
        ],
        MealType.afternoon: [('Pan integral', 2), ('Atún al natural', 80)],
        MealType.dinner: [
          ('Pescado blanco', 160),
          ('Papa cocida', 200),
          ('Verduras', 200),
        ],
      },
    ),
    NutritionTemplate(
      id: 'equilibrada',
      name: 'Alimentación equilibrada',
      goal: NutritionGoals.balanced,
      description:
          'Variedad de alimentos de todos los grupos en proporciones '
          'equilibradas para el día a día.',
      calories: 2100,
      protein: 140,
      carbs: 240,
      fat: 65,
      meals: {
        MealType.breakfast: [
          ('Pan integral', 2),
          ('Huevo', 2),
          ('Fruta variada', 150),
        ],
        MealType.midMorning: [('Yogur natural', 125), ('Frutos secos', 1)],
        MealType.lunch: [
          ('Pescado blanco', 160),
          ('Arroz cocido', 180),
          ('Verduras', 200),
          ('Aceite de oliva', 1),
        ],
        MealType.afternoon: [('Manzana', 1), ('Leche', 200)],
        MealType.dinner: [
          ('Pollo (pechuga)', 140),
          ('Camote cocido', 150),
          ('Ensalada', 150),
        ],
      },
    ),
  ];

  static NutritionTemplate? byId(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }

  /// Plantilla que encaja con cada objetivo del perfil
  /// (`AppConstants.goals`). Es solo una sugerencia de por dónde empezar,
  /// no una recomendación personalizada.
  static const Map<String, String> profileGoalTemplates = {
    'Ganar músculo': 'masa-muscular',
    'Fuerza': 'masa-muscular',
    'Perder grasa': 'perdida-grasa',
    'Mantenimiento': 'mantenimiento',
    'Resistencia': 'equilibrada',
    'Salud general': 'equilibrada',
  };

  /// Plantilla sugerida para el objetivo del perfil, o `null`.
  static NutritionTemplate? forProfileGoal(String? goal) {
    final id = goal == null ? null : profileGoalTemplates[goal];
    return id == null ? null : byId(id);
  }
}
