import 'package:flutter/material.dart';

/// Colores de marca y de estado. Son iguales en modo claro y oscuro.
///
/// Los colores neutros (fondos, textos, bordes) dependen del tema y se
/// obtienen con `context.palette` (ver `AppPalette` en `app_theme.dart`).
class AppColors {
  AppColors._();

  /// Índigo eléctrico: color principal de la marca.
  static const Color primary = Color(0xFF5B5BF0);
  static const Color primaryLight = Color(0xFFA9AAF9);

  /// Final del degradado de marca (índigo → violeta).
  static const Color primaryGradientEnd = Color(0xFF8B5CF6);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Lima: acento de la marca (indicador de navegación, destacados). Solo
  /// como relleno, con [onAccent] encima: como texto sobre blanco no se lee.
  static const Color accent = Color(0xFFA3E635);
  static const Color onAccent = Color(0xFF1A2E05);

  /// Tinta índigo oscura (fondos de avisos, texto fuerte). Conserva el
  /// nombre histórico `navy`.
  static const Color navy = Color(0xFF1C1D3F);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);
  static const Color teal = Color(0xFF0D9488);
  static const Color violet = Color(0xFFA855F7);

  static const Color googleBlue = Color(0xFF4285F4);
}

class AppConstants {
  AppConstants._();

  static const String appName = 'Vatio';
  static const String appTagline = 'Pura energía para entrenar.';

  /// Código de país que se añade a un celular escrito sin `+` (Perú).
  static const String defaultPhoneCountryCode = '+51';

  static const Set<String> muscleGroups = {
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Piernas',
    'Glúteos',
    'Abdomen',
    'Cardio',
  };

  static const Set<String> goals = {
    'Ganar músculo',
    'Perder grasa',
    'Fuerza',
    'Resistencia',
    'Mantenimiento',
    'Salud general',
  };

  static const Set<String> levels = {'Principiante', 'Intermedio', 'Avanzado'};

  static const List<String> weekDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<int> restPresets = [60, 90, 120, 180];
  static const int defaultRestSeconds = 90;

  /// Metas semanales por defecto (el usuario puede cambiarlas en Progreso).
  static const double defaultWeeklyVolumeGoal = 10000;
  static const int defaultWeeklySetsGoal = 20;
  static const int defaultWeeklyWorkoutsGoal = 3;

  /// Meta diaria de agua por defecto (el usuario puede cambiarla en
  /// Alimentación), cantidades rápidas y límites del registro, en ml.
  static const int defaultWaterGoalMl = 2000;
  static const List<int> waterPresets = [250, 500];
  static const int maxWaterGoalMl = 10000;
  static const int maxWaterPerDayMl = 20000;

  /// Semanas que muestra el historial semanal.
  static const int weeksInHistory = 12;

  static const String collectionUsers = 'users';
  static const String subRoutines = 'routines';
  static const String subExercises = 'exercises';
  static const String subWorkouts = 'workouts';
  static const String subPersonalRecords = 'personal_records';
  static const String subWeeklyProgress = 'weekly_progress';
  static const String subScheduledWorkouts = 'scheduled_workouts';
  static const String subNutritionPlans = 'nutrition_plans';
  static const String subNutritionDays = 'nutrition_days';
  static const String subAchievements = 'achievements';
}
