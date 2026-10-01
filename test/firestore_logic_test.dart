import 'package:fitprogress/core/utils/formatters.dart';
import 'package:fitprogress/models/exercise_model.dart';
import 'package:fitprogress/models/personal_record_model.dart';
import 'package:fitprogress/models/routine_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/models/workout_set_model.dart';
import 'package:fitprogress/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreService.weekIdOf', () {
    test('usa la semana ISO (lunes a domingo)', () {
      // La semana ISO 1 de 2026 va del 29/12/2025 al 04/01/2026, porque
      // contiene el primer jueves del año. Por eso el 05/01/2026 ya es W02.
      expect(FirestoreService.weekIdOf(DateTime(2025, 12, 29)), '2026-W01');
      expect(FirestoreService.weekIdOf(DateTime(2026, 1, 4)), '2026-W01');
      expect(FirestoreService.weekIdOf(DateTime(2026, 1, 5)), '2026-W02');
      expect(FirestoreService.weekIdOf(DateTime(2026, 1, 11)), '2026-W02');
    });

    test('el domingo sigue en la misma semana que su lunes', () {
      for (var week = 0; week < 20; week++) {
        final monday = DateTime(2026, 1, 5).add(Duration(days: 7 * week));
        final sunday = monday.add(const Duration(days: 6));
        expect(
          FirestoreService.weekIdOf(sunday),
          FirestoreService.weekIdOf(monday),
          reason: 'La semana ISO debe cerrarse el domingo',
        );
      }
    });

    test('el lunes siguiente abre una semana nueva', () {
      final monday = DateTime(2026, 1, 5);
      expect(
        FirestoreService.weekIdOf(monday.add(const Duration(days: 7))),
        isNot(FirestoreService.weekIdOf(monday)),
      );
    });

    test('maneja el cruce de año ISO', () {
      // El 31/12/2026 es jueves: pertenece a la semana ISO 2026-W53.
      expect(FirestoreService.weekIdOf(DateTime(2026, 12, 31)), '2026-W53');
      // El 01/01/2021 es viernes y pertenece a la semana ISO 2020-W53.
      expect(FirestoreService.weekIdOf(DateTime(2021, 1, 1)), '2020-W53');
    });

    test('el identificador y el inicio de semana nunca se contradicen', () {
      // Ambas consultas alimentan los gráficos: si divergieran, el resumen
      // semanal mostraría cero entrenamientos.
      for (var day = 0; day < 60; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        final start = FirestoreService.weekStartOf(date);
        expect(
          FirestoreService.weekIdOf(date),
          FirestoreService.weekIdOf(start),
          reason: 'Discrepancia para $date',
        );
      }
    });
  });

  group('FirestoreService.weekStartOf', () {
    test('siempre devuelve el lunes a medianoche', () {
      for (var day = 0; day < 40; day++) {
        final date = DateTime(2026, 3, 2).add(Duration(days: day));
        final start = FirestoreService.weekStartOf(date);
        expect(start.weekday, DateTime.monday);
        expect(start.hour, 0);
        expect(start.minute, 0);
        expect(start.isAfter(date), isFalse);
        expect(date.difference(start).inDays, inInclusiveRange(0, 6));
      }
    });
  });

  group('WorkoutSession', () {
    test('sobrevive a un viaje de ida y vuelta por Firestore', () {
      final original = WorkoutSession(
        id: 'w1',
        userId: 'u1',
        routineId: 'r1',
        routineName: 'Pecho',
        startedAt: DateTime(2026, 2, 1, 10),
        finishedAt: DateTime(2026, 2, 1, 11),
        duration: const Duration(hours: 1),
        totalVolume: 1500,
        totalSets: 10,
        totalReps: 80,
        totalExercises: 2,
        notes: 'buena sesion',
        exercises: [
          WorkoutExerciseRecord(
            exerciseId: 'e1',
            exerciseName: 'Press banca',
            sets: [
              WorkoutSet(
                setNumber: 1,
                weight: 60,
                repetitions: 10,
                restSeconds: 90,
              ),
            ],
          ),
        ],
      );

      final restored = WorkoutSession.fromMap('w1', original.toMap());

      expect(restored.id, 'w1');
      expect(restored.userId, 'u1');
      expect(restored.routineName, 'Pecho');
      expect(restored.totalVolume, 1500);
      expect(restored.totalSets, 10);
      expect(restored.totalReps, 80);
      expect(restored.exercises, hasLength(1));
      expect(restored.exercises.first.exerciseName, 'Press banca');
      expect(restored.exercises.first.sets.first.weight, 60);
      expect(restored.exercises.first.sets.first.repetitions, 10);
      expect(restored.notes, 'buena sesion');
    });

    test('tolera documentos con campos faltantes', () {
      final restored = WorkoutSession.fromMap('w2', <String, dynamic>{});
      expect(restored.id, 'w2');
      expect(restored.routineName, 'Entrenamiento libre');
      expect(restored.exercises, isEmpty);
      expect(restored.totalVolume, 0);
    });

    test('el volumen solo cuenta las series completadas', () {
      final record = WorkoutExerciseRecord(
        exerciseId: 'e1',
        exerciseName: 'Sentadilla',
        sets: [
          WorkoutSet(setNumber: 1, weight: 100, repetitions: 5),
          WorkoutSet(
            setNumber: 2,
            weight: 100,
            repetitions: 5,
            completed: false,
          ),
        ],
      );
      expect(record.volume, 500);
      expect(record.totalReps, 5);
    });
  });

  group('WorkoutRoutine', () {
    test('conserva el orden de los ejercicios al serializar', () {
      final routine = WorkoutRoutine(
        id: 'r1',
        userId: 'u1',
        name: 'Full body',
        exercises: ['e3', 'e1', 'e2'],
      );
      final restored = WorkoutRoutine.fromMap('r1', routine.toMap());
      expect(restored.exercises, ['e3', 'e1', 'e2']);
    });
  });

  group('ExerciseModel', () {
    test('copyWith no pierde el identificador', () {
      final exercise = ExerciseModel(
        id: 'e1',
        name: 'Sentadilla',
        muscleGroup: 'Piernas',
      );
      expect(exercise.copyWith(name: 'Sentadilla trasera').id, 'e1');
    });
  });

  group('PersonalRecord', () {
    test('isBetterThan compara contra el máximo actual', () {
      final record = PersonalRecord(
        id: 'e1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Press banca',
        maxWeight: 100,
      );
      expect(record.isBetterThan(101), isTrue);
      expect(record.isBetterThan(100), isFalse);
      expect(record.isBetterThan(99), isFalse);
    });
  });

  group('Formatters', () {
    test('formatWeight omite decimales en pesos enteros', () {
      expect(Formatters.formatWeight(100), '100');
      expect(Formatters.formatWeight(72.5), '72,5');
    });

    test('formatDuration muestra horas solo cuando corresponde', () {
      expect(Formatters.formatDuration(const Duration(seconds: 65)), '01:05');
      expect(Formatters.formatDuration(const Duration(minutes: 75)), '1h 15m');
    });
  });
}
