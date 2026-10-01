import 'package:fitprogress/core/theme/app_theme.dart';
import 'package:fitprogress/core/utils/formatters.dart';
import 'package:fitprogress/models/exercise_model.dart';
import 'package:fitprogress/models/routine_model.dart';
import 'package:fitprogress/models/user_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/providers/progress_provider.dart';
import 'package:fitprogress/providers/theme_provider.dart';
import 'package:fitprogress/providers/workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session(
  DateTime finished, {
  double volume = 100,
  int sets = 3,
}) {
  return WorkoutSession(
    id: finished.toIso8601String(),
    userId: 'u1',
    startedAt: finished.subtract(const Duration(minutes: 45)),
    finishedAt: finished,
    totalVolume: volume,
    totalSets: sets,
  );
}

ExerciseModel _exercise(String id) =>
    ExerciseModel(id: id, name: 'Ejercicio $id', muscleGroup: 'Pecho');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('ProgressProvider.computeDayStreak', () {
    final now = DateTime(2026, 9, 30, 18);

    test('sin entrenamientos la racha es 0', () {
      expect(ProgressProvider.computeDayStreak(const [], now), 0);
    });

    test('cuenta días consecutivos terminando hoy', () {
      final dates = [
        DateTime(2026, 9, 30, 8),
        DateTime(2026, 9, 29, 20),
        DateTime(2026, 9, 28, 7),
        DateTime(2026, 9, 26, 7), // hueco el 27
      ];
      expect(ProgressProvider.computeDayStreak(dates, now), 3);
    });

    test('la racha sigue viva si el último entrenamiento fue ayer', () {
      final dates = [DateTime(2026, 9, 29), DateTime(2026, 9, 28)];
      expect(ProgressProvider.computeDayStreak(dates, now), 2);
    });

    test('se corta si no entrenaste ni hoy ni ayer', () {
      final dates = [DateTime(2026, 9, 27), DateTime(2026, 9, 26)];
      expect(ProgressProvider.computeDayStreak(dates, now), 0);
    });

    test('varios entrenamientos el mismo día cuentan una vez', () {
      final dates = [DateTime(2026, 9, 30, 8), DateTime(2026, 9, 30, 19)];
      expect(ProgressProvider.computeDayStreak(dates, now), 1);
    });
  });

  group('ProgressProvider.totalsBetween', () {
    test('suma solo los entrenamientos dentro del periodo', () {
      final from = DateTime(2026, 9, 28); // lunes
      final to = DateTime(2026, 10, 5);
      final workouts = [
        _session(DateTime(2026, 9, 30), volume: 500, sets: 5),
        _session(DateTime(2026, 9, 28, 0, 1), volume: 200, sets: 2),
        _session(DateTime(2026, 9, 27, 23), volume: 999, sets: 9),
        _session(DateTime(2026, 10, 5), volume: 999, sets: 9),
      ];
      final totals = ProgressProvider.totalsBetween(workouts, from, to);
      expect(totals.workouts, 2);
      expect(totals.volume, 700);
      expect(totals.sets, 7);
    });
  });

  group('WorkoutProvider', () {
    WorkoutProvider provider() => WorkoutProvider(currentUid: () => 'u1');

    test('entrenamiento libre con los ejercicios elegidos', () {
      final p = provider();
      expect(p.startFreeWorkout(const []), isFalse);
      expect(p.active, isFalse);

      expect(p.startFreeWorkout([_exercise('a'), _exercise('b')]), isTrue);
      expect(p.active, isTrue);
      expect(p.isFreeWorkout, isTrue);
      expect(p.routineName, WorkoutProvider.freeWorkoutName);
      expect(p.exercises.map((e) => e.id), ['a', 'b']);
    });

    test('registra series y calcula totales', () {
      final p = provider()..startFreeWorkout([_exercise('a'), _exercise('b')]);
      p.addSet('a', weight: 50, repetitions: 10);
      p.addSet('a', weight: 60, repetitions: 8);
      p.addSet('b', weight: 0, repetitions: 15);

      expect(p.totalCompletedSets, 3);
      expect(p.totalVolume, 50 * 10 + 60 * 8);
      expect(p.totalReps, 33);
      expect(p.totalExercises, 2);
    });

    test('al quitar una serie se renumeran las demás', () {
      final p = provider()..startFreeWorkout([_exercise('a')]);
      p.addSet('a', weight: 10, repetitions: 5);
      p.addSet('a', weight: 20, repetitions: 5);
      p.addSet('a', weight: 30, repetitions: 5);
      p.removeSet('a', 0);
      expect(p.setsFor('a').map((s) => s.setNumber), [1, 2]);
      expect(p.setsFor('a').map((s) => s.weight), [20, 30]);
    });

    test('no inicia una rutina cuyos ejercicios ya no existen', () {
      final p = provider();
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: 'u1',
        name: 'Pierna',
        exercises: ['borrado'],
      );
      expect(
        p.startWorkout(routine: routine, allExercises: [_exercise('a')]),
        isFalse,
      );
      expect(p.active, isFalse);
    });

    test('reset limpia todo el estado', () {
      final p = provider()..startFreeWorkout([_exercise('a')]);
      p.addSet('a', weight: 10, repetitions: 5);
      p.reset();
      expect(p.active, isFalse);
      expect(p.totalSets, 0);
      expect(p.lastSession, isNull);
    });
  });

  group('UserModel', () {
    test('passwordPending se guarda y se lee', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Ana',
        email: 'ana@x.com',
        passwordPending: true,
      );
      final map = user.toMap();
      expect(map['passwordPending'], isTrue);
      expect(map.containsKey('password'), isFalse);
      expect(UserModel.fromMap('u1', map).passwordPending, isTrue);
    });

    test('perfiles antiguos sin el campo no quedan pendientes', () {
      final user = UserModel.fromMap('u1', {'name': 'Ana'});
      expect(user.passwordPending, isFalse);
    });
  });

  group('Formatters.formatRelativeDay', () {
    final now = DateTime(2026, 9, 30, 12);

    test('hoy y ayer', () {
      expect(
        Formatters.formatRelativeDay(DateTime(2026, 9, 30, 7), now: now),
        'Hoy',
      );
      expect(
        Formatters.formatRelativeDay(DateTime(2026, 9, 29, 23), now: now),
        'Ayer',
      );
    });

    test('fechas anteriores usan la fecha corta', () {
      expect(
        Formatters.formatRelativeDay(DateTime(2026, 9, 20), now: now),
        Formatters.formatDate(DateTime(2026, 9, 20)),
      );
    });
  });

  group('ThemeProvider', () {
    test('guarda la preferencia y la vuelve a leer', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemeProvider.loadSavedMode(), ThemeMode.system);

      final provider = ThemeProvider();
      await provider.setMode(ThemeMode.dark);
      expect(provider.mode, ThemeMode.dark);
      expect(await ThemeProvider.loadSavedMode(), ThemeMode.dark);
    });
  });

  group('AppTheme', () {
    test('ambos temas incluyen su paleta', () {
      expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
      expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });
  });
}
