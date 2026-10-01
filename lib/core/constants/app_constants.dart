import 'package:flutter/material.dart';

/// Colores de marca y de estado. Son iguales en modo claro y oscuro.
///
/// Los colores neutros (fondos, textos, bordes) dependen del tema y se
/// obtienen con `context.palette` (ver `AppPalette` en `app_theme.dart`).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF6D00);
  static const Color primaryLight = Color(0xFFFFAB66);
  static const Color primaryGradientEnd = Color(0xFFFF9E40);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color navy = Color(0xFF14213D);

  static const Color success = Color(0xFF2E9E57);
  static const Color error = Color(0xFFD64545);
  static const Color amber = Color(0xFFF5A524);
  static const Color teal = Color(0xFF0F9D8A);
  static const Color violet = Color(0xFF6C5CE7);

  static const Color googleBlue = Color(0xFF4285F4);
}

class AppConstants {
  AppConstants._();

  static const String appName = 'FitProgress';
  static const String appTagline = 'Entrena. Progresa. Supérate.';

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

  /// Semanas que muestra el historial semanal.
  static const int weeksInHistory = 12;

  static const String collectionUsers = 'users';
  static const String subRoutines = 'routines';
  static const String subExercises = 'exercises';
  static const String subWorkouts = 'workouts';
  static const String subPersonalRecords = 'personal_records';
  static const String subWeeklyProgress = 'weekly_progress';
  static const String subScheduledWorkouts = 'scheduled_workouts';
}
