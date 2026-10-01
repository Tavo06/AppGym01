import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fitprogress/core/routes/app_router.dart';
import 'package:fitprogress/core/theme/app_theme.dart';
import 'package:fitprogress/core/constants/nutrition_catalog.dart';
import 'package:fitprogress/models/exercise_model.dart';
import 'package:fitprogress/models/nutrition_model.dart';
import 'package:fitprogress/models/routine_day_model.dart';
import 'package:fitprogress/models/routine_model.dart';
import 'package:fitprogress/models/user_model.dart';
import 'package:fitprogress/models/workout_model.dart';
import 'package:fitprogress/models/workout_set_model.dart';
import 'package:fitprogress/providers/auth_provider.dart';
import 'package:fitprogress/screens/auth/register_dialog.dart';
import 'package:fitprogress/providers/nutrition_provider.dart';
import 'package:fitprogress/providers/progress_provider.dart';
import 'package:fitprogress/providers/schedule_provider.dart';
import 'package:fitprogress/providers/session_cleanup.dart';
import 'package:fitprogress/providers/theme_provider.dart';
import 'package:fitprogress/providers/workout_provider.dart';
import 'package:fitprogress/services/app_firebase.dart';
import 'package:fitprogress/services/firestore_service.dart';
import 'package:fitprogress/services/nutrition_service.dart';
import 'package:fitprogress/widgets/create_password_dialog.dart';
import 'package:fitprogress/widgets/custom_button.dart';
import 'package:fitprogress/widgets/progress_card.dart';
import 'package:fitprogress/widgets/routine_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uid = 'user-a';

/// Datos de ejemplo realistas: 2 ejercicios, 1 rutina y entrenamientos de
/// esta semana y de la anterior (con récords y progreso semanal).
Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  AppFirebase.firestoreOverride = db;
  final service = FirestoreService();

  await service.createUserProfile(
    UserModel(
      uid: _uid,
      name: 'Ana Pérez',
      email: 'ana@example.com',
      goal: 'Fuerza',
      level: 'Intermedio',
      birthDate: '1995-04-12',
      emailVerified: true,
    ),
  );
  await service.saveExercise(
    _uid,
    ExerciseModel(id: 'e1', name: 'Press banca', muscleGroup: 'Pecho'),
  );
  await service.saveExercise(
    _uid,
    ExerciseModel(
      id: 'e2',
      name: 'Sentadilla',
      muscleGroup: 'Piernas',
      equipment: 'Barra',
    ),
  );
  await service.saveRoutine(
    _uid,
    WorkoutRoutine(
      id: 'r1',
      userId: _uid,
      name: 'Fuerza total',
      description: 'Básicos de fuerza',
      goal: 'Fuerza',
      exercises: ['e1', 'e2'],
    ),
  );

  final now = DateTime.now();
  final dates = [
    now.subtract(const Duration(days: 9)),
    now.subtract(const Duration(days: 8)),
    now.subtract(const Duration(days: 1)),
    now,
  ];
  var weight = 60.0;
  for (var i = 0; i < dates.length; i++) {
    weight += 5;
    final sets = [
      WorkoutSet(setNumber: 1, weight: weight, repetitions: 8),
      WorkoutSet(setNumber: 2, weight: weight, repetitions: 6),
    ];
    final session = WorkoutSession(
      id: 'w$i',
      userId: _uid,
      routineId: 'r1',
      routineName: 'Fuerza total',
      startedAt: dates[i].subtract(const Duration(minutes: 50)),
      finishedAt: dates[i],
      duration: const Duration(minutes: 50),
      totalVolume: weight * 14,
      totalSets: 2,
      totalReps: 14,
      totalExercises: 1,
      exercises: [
        WorkoutExerciseRecord(
          exerciseId: 'e1',
          exerciseName: 'Press banca',
          sets: sets,
        ),
      ],
    );
    await service.saveWorkout(_uid, session);
  }
  return db;
}

class _Harness {
  _Harness(this.router, this.workout, this.progress);

  final GoRouter router;
  final WorkoutProvider workout;
  final ProgressProvider progress;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  required ThemeMode theme,
  Size size = const Size(360, 780),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final auth = AuthProvider();
  final workout = WorkoutProvider();
  final progress = ProgressProvider();
  final schedule = ScheduleProvider();
  final nutrition = NutritionProvider();
  final themeProvider = ThemeProvider(initialMode: theme);
  final router = AppRouter(auth).router;
  final unbind = bindSessionCleanup(
    auth: auth,
    workout: workout,
    progress: progress,
    schedule: schedule,
    nutrition: nutrition,
  );
  addTearDown(unbind);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: workout),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: schedule),
        ChangeNotifierProvider.value(value: nutrition),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  // Splash (1,2 s) → Inicio, y lecturas de Firestore simulado.
  await _settle(tester, seconds: 3);
  return _Harness(router, workout, progress);
}

/// Avanza el tiempo en pasos cortos (pumpAndSettle no termina mientras hay
/// indicadores de carga o cronómetros activos).
Future<void> _settle(WidgetTester tester, {int seconds = 1}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _go(WidgetTester tester, _Harness app, String location) async {
  app.router.go(location);
  await _settle(tester);
}

String _location(_Harness app) =>
    app.router.routeInformationProvider.value.uri.path;

/// Desplaza la lista del entrenamiento hasta que [text] esté construido y
/// visible (la ListView construye sus hijos de forma perezosa).
Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.dragUntilVisible(
    find.text(text),
    find.byType(ListView).last,
    const Offset(0, -200),
  );
  await _settle(tester);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await _seed();
    AppFirebase.authOverride = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: _uid,
        email: 'ana@example.com',
        displayName: 'Ana Pérez',
        isEmailVerified: true,
      ),
    );
  });

  tearDown(() {
    AppFirebase.authOverride = null;
    AppFirebase.firestoreOverride = null;
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    final name = theme == ThemeMode.light ? 'claro' : 'oscuro';

    testWidgets('pantallas principales en móvil (tema $name)', (tester) async {
      final app = await _pumpApp(tester, theme: theme);

      // Rutinas es la pantalla principal.
      expect(_location(app), '/rutinas');
      expect(find.text('Mis rutinas'), findsOneWidget);
      expect(find.text('Fuerza total'), findsOneWidget);
      expect(find.textContaining('Press banca'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Panel (antes Inicio) con datos reales.
      await _go(tester, app, '/home');
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Accesos rápidos'), findsOneWidget);
      expect(find.text('Metas semanales'), findsOneWidget);

      await _go(tester, app, '/progreso');
      expect(find.text('Récords personales'), findsOneWidget);
      expect(find.text('Progreso por ejercicio'), findsOneWidget);
      expect(find.text('Metas semanales'), findsOneWidget);

      await _go(tester, app, '/profile');
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      await _go(tester, app, '/ejercicio');
      expect(find.text('Sentadilla'), findsOneWidget);

      await _go(tester, app, '/profile/edit');
      expect(find.text('Fuerza'), findsOneWidget);
      expect(find.text('Intermedio'), findsOneWidget);
      expect(find.text('12/04/1995'), findsOneWidget);

      await _go(tester, app, '/entrenamiento');
      expect(find.text('No hay entrenamiento activo'), findsOneWidget);
    });
  }

  testWidgets('escritorio: navegación lateral y contenido centrado', (
    tester,
  ) async {
    final app = await _pumpApp(
      tester,
      theme: ThemeMode.light,
      size: const Size(1400, 900),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await _go(tester, app, '/progreso');
    expect(find.text('Últimas semanas'), findsOneWidget);
    await _go(tester, app, '/rutinas');
    expect(find.text('Fuerza total'), findsOneWidget);
  });

  testWidgets('entrenamiento libre: series, finalizar, guardar y resumen', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/entrenamiento');

    await tester.tap(find.text('Entrenamiento libre'));
    await _settle(tester);
    await tester.tap(find.text('Sentadilla'));
    await _settle(tester);
    await tester.tap(find.textContaining('Comenzar con 1'));
    await _settle(tester);

    expect(app.workout.active, isTrue);
    expect(app.workout.isFreeWorkout, isTrue);

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tester.enterText(field('Peso (kg)'), '100');
    await tester.enterText(field('Repeticiones'), '5');
    await tester.dragUntilVisible(
      find.text('Agregar serie'),
      find.byType(ListView).last,
      const Offset(0, -150),
    );
    await _settle(tester);
    await tester.tap(find.text('Agregar serie'));
    await _settle(tester);
    expect(app.workout.totalCompletedSets, 1);

    await tester.dragUntilVisible(
      find.text('Finalizar entrenamiento'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await _settle(tester);
    await tester.tap(find.text('Finalizar entrenamiento'));
    await _settle(tester);
    await tester.tap(find.text('Finalizar').last);
    await _settle(tester, seconds: 2);

    expect(find.text('Entrenamiento guardado'), findsOneWidget);
    // 100 kg supera el récord previo de Sentadilla (no tenía).
    expect(find.text('Nuevos récords personales'), findsOneWidget);

    final saved = await AppFirebase.firestore
        .collection('users')
        .doc(_uid)
        .collection('workouts')
        .get();
    expect(saved.docs.length, 5);

    // El estado global se actualizó al guardar (Progreso aún no se había
    // abierto, así que agregarSesion hizo la carga completa).
    await _settle(tester);
    expect(app.progress.workouts.length, 5);
  });

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<Map<String, dynamic>?> doc(String path) async =>
      (await AppFirebase.firestore.doc(path).get()).data();

  testWidgets('crear ejercicio lo guarda en Firestore', (tester) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/ejercicio/crear');
    await tester.enterText(field('Nombre del ejercicio'), 'Remo con barra');
    await tester.tap(find.text('Grupo muscular'));
    await _settle(tester);
    await tester.tap(find.text('Espalda').last);
    await _settle(tester);
    await tester.enterText(field('Equipamiento (opcional)'), 'Barra');
    await tester.tap(find.text('Guardar ejercicio'));
    await _settle(tester, seconds: 2);
    expect(find.text('Ejercicio creado'), findsOneWidget);

    final all = await AppFirebase.firestore
        .collection('users/$_uid/exercises')
        .where('name', isEqualTo: 'Remo con barra')
        .get();
    expect(all.docs.single.data()['muscleGroup'], 'Espalda');
    expect(all.docs.single.data()['equipment'], 'Barra');
  });

  testWidgets('editar rutina desde el menú abre sus datos y guarda', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/rutinas');
    await tester.tap(find.byTooltip('Opciones').first);
    await _settle(tester);
    await tester.tap(find.text('Editar'));
    await _settle(tester, seconds: 2);

    // Antes esto lanzaba una excepción (GoRouterState.of en initState).
    expect(find.text('Editar rutina'), findsOneWidget);
    expect(find.text('Fuerza total'), findsOneWidget);
    await tester.enterText(field('Nombre de la rutina'), 'Fuerza 2.0');
    await tester.dragUntilVisible(
      find.text('Actualizar rutina'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Actualizar rutina'));
    await _settle(tester, seconds: 2);

    final data = await doc('users/$_uid/routines/r1');
    expect(data?['name'], 'Fuerza 2.0');
    expect(data?['exercises'], ['e1', 'e2']);
  });

  testWidgets('iniciar rutina con otro entrenamiento en curso pide '
      'confirmación', (tester) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    app.workout.startFreeWorkout([
      ExerciseModel(id: 'e2', name: 'Sentadilla', muscleGroup: 'Piernas'),
    ]);
    await _go(tester, app, '/rutinas');
    await tester.tap(find.text('Comenzar').first);
    await _settle(tester);
    expect(find.text('Ya tienes un entrenamiento en curso'), findsOneWidget);
    await tester.tap(find.text('Descartar y comenzar'));
    await _settle(tester);
    expect(app.workout.routineName, 'Fuerza total');
    expect(app.workout.isFreeWorkout, isFalse);
  });

  testWidgets('editar perfil guarda objetivo, nivel y nombre', (tester) async {
    final app = await _pumpApp(tester, theme: ThemeMode.dark);
    await _go(tester, app, '/profile/edit');
    await tester.enterText(field('Nombre completo'), 'Ana María');
    await tester.tap(find.text('Intermedio'));
    await _settle(tester);
    await tester.tap(find.text('Avanzado').last);
    await _settle(tester);
    await tester.tap(find.text('Fuerza'));
    await _settle(tester);
    await tester.tap(find.text('Sin especificar').last);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Guardar cambios'));
    await _settle(tester, seconds: 2);

    final data = await doc('users/$_uid');
    expect(data?['name'], 'Ana María');
    expect(data?['level'], 'Avanzado');
    expect(data?['goal'], isNull);
    expect(data?['birthDate'], '1995-04-12');
    expect(data?.containsKey('password'), isFalse);
  });

  testWidgets('eliminar rutina la borra de Firestore', (tester) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/rutinas');
    await tester.tap(find.byTooltip('Opciones').first);
    await _settle(tester);
    await tester.tap(find.text('Eliminar'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await _settle(tester, seconds: 2);
    expect(await doc('users/$_uid/routines/r1'), isNull);
    expect(find.text('Todavía no tienes rutinas'), findsOneWidget);
  });

  testWidgets('al cerrar sesión no quedan datos del usuario anterior', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    // Las estadísticas se cargan al abrir Progreso.
    await _go(tester, app, '/progreso');
    final progress = app.progress;
    expect(progress.workouts, isNotEmpty);

    app.workout.startFreeWorkout([
      ExerciseModel(id: 'e1', name: 'Press banca', muscleGroup: 'Pecho'),
    ]);
    await AppFirebase.auth.signOut();
    await _settle(tester, seconds: 2);

    expect(progress.workouts, isEmpty);
    expect(progress.progress, isNull);
    expect(find.text('Iniciar sesión'), findsWidgets);
  });

  testWidgets('usuario verificado sin contraseña: modal sobre el Login, '
      'crea la contraseña y vuelve al Login con el correo escrito', (
    tester,
  ) async {
    await AppFirebase.firestore.doc('users/$_uid').set({
      'passwordPending': true,
    }, SetOptions(merge: true));
    final app = await _pumpApp(tester, theme: ThemeMode.light);

    // No entra al Dashboard: el router lo retiene en /login con el modal.
    expect(app.router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(CreatePasswordDialog), findsOneWidget);
    expect(find.textContaining('ana@example.com'), findsWidgets);

    await tester.enterText(field('Nueva contraseña'), 'MiClave2026!');
    await tester.enterText(field('Confirmar contraseña'), 'MiClave2026!');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear contraseña'));
    await _settle(tester, seconds: 2);

    expect(find.byType(CreatePasswordDialog), findsNothing);
    expect(AppFirebase.auth.currentUser, isNull);
    expect(app.router.routeInformationProvider.value.uri.path, '/login');
    final email = tester.widget<EditableText>(
      find.descendant(
        of: field('Correo electrónico'),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.controller.text, 'ana@example.com');
    final password = tester.widget<EditableText>(
      find.descendant(
        of: field('Contraseña'),
        matching: find.byType(EditableText),
      ),
    );
    expect(password.controller.text, isEmpty);
    expect((await doc('users/$_uid'))?['passwordPending'], isFalse);
  });

  testWidgets('usuario sin verificar queda en "Verifica tu correo"', (
    tester,
  ) async {
    AppFirebase.authOverride = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: _uid,
        email: 'ana@example.com',
        isEmailVerified: false,
      ),
    );
    final app = await _pumpApp(tester, theme: ThemeMode.dark);
    expect(find.text('Verifica tu correo'), findsOneWidget);
    await _go(tester, app, '/home');
    expect(find.text('Verifica tu correo'), findsOneWidget);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('pantallas secundarias sin desbordes ($theme)', (tester) async {
      final app = await _pumpApp(tester, theme: theme);
      for (final route in [
        '/change-password',
        '/entrenamiento/resumen',
        '/rutinas/crear',
        '/ejercicio/crear',
      ]) {
        await _go(tester, app, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      expect(find.text('Nuevo ejercicio'), findsOneWidget);
    });
  }

  // ---------------------------------------------------------------------
  // Requisitos de la especificación: navegación, paso de datos y estado.
  // ---------------------------------------------------------------------

  Future<void> tapMenu(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        // Por tooltip: en móvil estrecho solo se rotula el destino elegido.
        matching: find.byTooltip(label),
      ),
    );
    await _settle(tester);
  }

  testWidgets('menú principal: Rutinas, Entrenar, Ejercicios y Progreso', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    expect(_location(app), '/rutinas');

    await tapMenu(tester, 'Entrenar');
    expect(_location(app), '/entrenamiento');
    expect(find.text('No hay entrenamiento activo'), findsOneWidget);

    await tapMenu(tester, 'Ejercicios');
    expect(_location(app), '/ejercicio');
    expect(find.text('Mis ejercicios'), findsOneWidget);
    // Los filtros salen del Set de grupos musculares que tienen ejercicios.
    expect(find.text('Pecho (1)'), findsOneWidget);
    expect(find.text('Piernas (1)'), findsOneWidget);
    expect(find.textContaining('Espalda'), findsNothing);
    await tester.tap(find.text('Pecho (1)'));
    await _settle(tester);
    expect(find.text('Press banca'), findsOneWidget);
    expect(find.text('Sentadilla'), findsNothing);

    await tapMenu(tester, 'Progreso');
    expect(_location(app), '/progreso');
    expect(find.text('Metas semanales'), findsOneWidget);

    await tapMenu(tester, 'Rutinas');
    expect(_location(app), '/rutinas');
    expect(find.text('Fuerza total'), findsOneWidget);
  });

  testWidgets('las rutas antiguas redirigen a las nuevas', (tester) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    const aliases = {
      '/routines': '/rutinas',
      '/workout': '/entrenamiento',
      '/exercises': '/ejercicio',
      '/progress': '/progreso',
      '/exercises/create': '/ejercicio/crear',
    };
    for (final entry in aliases.entries) {
      await _go(tester, app, entry.key);
      expect(_location(app), entry.value, reason: entry.key);
    }
  });

  testWidgets('flujo completo: la rutina viaja a /entrenamiento, se registran '
      'series con estado local y la sesión vuelve a Rutinas y a Progreso', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    // Progreso cargado: al guardar se actualiza en memoria, sin Firestore.
    await _go(tester, app, '/progreso');
    final before = app.progress.workouts.length;
    expect(find.widgetWithText(ProgressCard, '$before'), findsOneWidget);
    var notifications = 0;
    void listener() => notifications++;
    app.progress.addListener(listener);
    addTearDown(() => app.progress.removeListener(listener));

    // 1. Selección de rutina y paso del objeto WorkoutRoutine.
    await _go(tester, app, '/rutinas');
    expect(find.text('Pecho'), findsOneWidget); // grupos de la rutina (Set)
    await tester.tap(find.text('Comenzar').first);
    await _settle(tester);
    expect(_location(app), '/entrenamiento');
    expect(app.workout.routineName, 'Fuerza total');
    expect(app.workout.isFreeWorkout, isFalse);
    expect(app.workout.exercises.map((e) => e.id), ['e1', 'e2']);
    expect(find.text('Serie 1 en curso'), findsOneWidget);

    // El plan de la rutina (rutina antigua: 3 × 10 por defecto) precarga
    // las repeticiones y se muestra como objetivo.
    expect(find.textContaining('Objetivo: 3 × 10'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget); // serie actual / planeadas

    // 2. Estado local con setState: peso y repeticiones en curso.
    await tester.enterText(field('Peso (kg)'), '70');
    await tester.enterText(field('Repeticiones'), '1');
    await tester.ensureVisible(find.byTooltip('Una repetición más'));
    await _settle(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Una repetición más'));
      await tester.pump();
    }
    expect(find.text('70 kg × 3 = 210 kg'), findsOneWidget);

    // 3. Registro de la serie: pasa al estado global y avanza la serie.
    await tester.ensureVisible(find.text('Agregar serie'));
    await _settle(tester);
    await tester.tap(find.text('Agregar serie'));
    await _settle(tester);
    expect(app.workout.totalCompletedSets, 1);
    expect(app.workout.totalVolume, 210);
    expect(app.workout.totalReps, 3);
    expect(find.text('Serie 2 en curso'), findsOneWidget);

    // 4. Finalizar con el descanso en marcha.
    await _scrollTo(tester, 'Finalizar entrenamiento');
    await _settle(tester);
    expect(find.text('Pausar'), findsOneWidget);
    await tester.tap(find.text('Finalizar entrenamiento'));
    await _settle(tester);
    await tester.tap(find.text('Finalizar').last);
    await _settle(tester, seconds: 2);
    expect(find.text('Entrenamiento guardado'), findsOneWidget);
    // Resumen: comparación con la sesión anterior y ejercicios realizados.
    expect(find.text('Comparado con tu sesión anterior'), findsOneWidget);
    expect(find.text('Ejercicios realizados'), findsOneWidget);
    expect(find.textContaining('1 series · 3 reps'), findsOneWidget);

    // 5 y 6. ProgressProvider recibió la sesión y notificó.
    expect(app.progress.workouts.length, before + 1);
    expect(app.progress.workouts.first.routineName, 'Fuerza total');
    expect(notifications, greaterThan(0));

    // La sesión completada vuelve a Rutinas.
    await tester.ensureVisible(find.text('Volver a rutinas'));
    await _settle(tester);
    await tester.tap(find.text('Volver a rutinas'));
    await _settle(tester);
    expect(_location(app), '/rutinas');
    expect(find.text('Sesión completada'), findsOneWidget);
    expect(find.textContaining('Fuerza total · 1 series · 3 reps'), findsOne);

    // 7. El Consumer del panel de estadísticas ya muestra la nueva sesión.
    await tapMenu(tester, 'Progreso');
    expect(find.widgetWithText(ProgressCard, '${before + 1}'), findsOneWidget);

    // Bug del descanso: un nuevo entrenamiento no hereda el descanso.
    await tapMenu(tester, 'Rutinas');
    await tester.tap(find.text('Comenzar').first);
    await _settle(tester);
    expect(app.workout.active, isTrue);
    expect(find.text('Serie 1 en curso'), findsOneWidget);
    await _scrollTo(tester, 'Finalizar entrenamiento');
    await _settle(tester);
    expect(find.text('Pausar'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // Registro y recuperación de contraseña como modales sobre el Login.
  // ---------------------------------------------------------------------

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(Dialog), matching: finder);

  testWidgets('registro y recuperar contraseña se abren como modales sobre '
      'el Login', (tester) async {
    AppFirebase.authOverride = MockFirebaseAuth(signedIn: false);
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    expect(_location(app), '/login');

    // Registro: modal centrado, sin cambiar de página.
    await tester.ensureVisible(find.text('Regístrate'));
    await _settle(tester);
    await tester.tap(find.text('Regístrate'));
    await _settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(inDialog(find.text('Crear cuenta')), findsWidgets);
    expect(_location(app), '/login');
    await tester.tap(inDialog(find.byTooltip('Cerrar')));
    await _settle(tester);
    expect(find.byType(Dialog), findsNothing);

    // Recuperar contraseña: recibe el correo ya escrito en el Login.
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
    await _settle(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await _settle(tester);
    expect(inDialog(find.text('Recuperar contraseña')), findsOneWidget);
    final email = tester.widget<EditableText>(
      inDialog(find.byType(EditableText)),
    );
    expect(email.controller.text, 'ana@example.com');
    await tester.tap(inDialog(find.text('Enviar enlace')));
    await _settle(tester);
    expect(inDialog(find.text('Revisa tu correo')), findsOneWidget);
    await tester.tap(inDialog(find.text('Entendido')));
    await _settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(_location(app), '/login');

    // Las rutas antiguas de esas páginas llevan al Login.
    await _go(tester, app, '/register');
    expect(_location(app), '/login');
    await _go(tester, app, '/forgot-password');
    expect(_location(app), '/login');
  });

  testWidgets('crear la cuenta desde el modal lleva a verificar el correo', (
    tester,
  ) async {
    AppFirebase.authOverride = MockFirebaseAuth(signedIn: false);
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await tester.ensureVisible(find.text('Regístrate'));
    await _settle(tester);
    await tester.tap(find.text('Regístrate'));
    await _settle(tester);

    // Sin datos válidos, el error se muestra dentro del modal.
    await tester.ensureVisible(
      inDialog(find.widgetWithText(CustomButton, 'Crear cuenta')),
    );
    await _settle(tester);
    await tester.tap(
      inDialog(find.widgetWithText(CustomButton, 'Crear cuenta')),
    );
    await _settle(tester);
    expect(
      inDialog(find.text('Revisa los campos marcados en rojo.')),
      findsOneWidget,
    );

    await tester.enterText(inDialog(field('Nombre completo')), 'Bruno Díaz');
    await tester.enterText(
      inDialog(field('Correo electrónico')),
      'bruno@example.com',
    );
    await tester.enterText(
      inDialog(field('Confirmar correo electrónico')),
      'bruno@example.com',
    );
    await tester.ensureVisible(
      inDialog(find.widgetWithText(CustomButton, 'Crear cuenta')),
    );
    await tester.tap(
      inDialog(find.widgetWithText(CustomButton, 'Crear cuenta')),
    );
    await _settle(tester, seconds: 2);

    // El modal de registro se cerró y la cuenta quedó creada con su perfil.
    expect(find.byType(RegisterDialog), findsNothing);
    final uid = AppFirebase.auth.currentUser!.uid;
    final profile = await doc('users/$uid');
    expect(profile?['name'], 'Bruno Díaz');
    expect(profile?['passwordPending'], isTrue);
    // MockFirebaseAuth crea los usuarios con el correo ya verificado, así
    // que la app continúa con el paso siguiente del flujo real: el modal
    // "Crear contraseña" sobre el Login (con un usuario sin verificar, el
    // router lo llevaría a /verify-email).
    expect(app.router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(CreatePasswordDialog), findsOneWidget);
  });

  testWidgets('el botón atrás en el resumen también devuelve la sesión', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    app.workout.startFreeWorkout([
      ExerciseModel(id: 'e2', name: 'Sentadilla', muscleGroup: 'Piernas'),
    ]);
    app.workout.addSet('e2', weight: 50, repetitions: 10);
    await _go(tester, app, '/entrenamiento');
    await _scrollTo(tester, 'Finalizar entrenamiento');
    await _settle(tester);
    await tester.tap(find.text('Finalizar entrenamiento'));
    await _settle(tester);
    await tester.tap(find.text('Finalizar').last);
    await _settle(tester, seconds: 2);
    expect(find.text('Entrenamiento guardado'), findsOneWidget);

    await app.router.routerDelegate.navigatorKey.currentState!.maybePop();
    await _settle(tester);
    expect(_location(app), '/rutinas');
    expect(find.text('Sesión completada'), findsOneWidget);
    expect(app.progress.workouts.length, 5);
  });

  // ---------------------------------------------------------------------
  // Entrenamiento personal: rutinas por días, calendario.
  // ---------------------------------------------------------------------

  Future<void> seedMultiDayRoutine() => FirestoreService().saveRoutine(
    _uid,
    WorkoutRoutine(
      id: 'r2',
      userId: _uid,
      name: 'Torso Pierna',
      days: [
        RoutineDay(
          id: 'torso',
          name: 'Torso',
          exercises: [
            RoutineExercise(
              exerciseId: 'e1',
              sets: 4,
              reps: 8,
              weight: 60,
              restSeconds: 120,
              notes: 'Bajar controlado',
            ),
          ],
        ),
        RoutineDay(
          id: 'pierna',
          name: 'Pierna',
          exercises: [RoutineExercise(exerciseId: 'e2', sets: 5, reps: 5)],
        ),
      ],
    ),
  );

  testWidgets('rutina por días: el detalle muestra el plan y se entrena un '
      'día concreto', (tester) async {
    await seedMultiDayRoutine();
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    expect(find.text('Torso Pierna'), findsOneWidget);
    expect(find.text('2 días'), findsOneWidget);

    // Detalle: días con su plan.
    await tester.tap(find.text('Torso Pierna'));
    await _settle(tester);
    expect(find.text('Entrenar Torso'), findsOneWidget);
    expect(find.text('4 × 8 · 60 kg · descanso 120 s'), findsOneWidget);
    expect(find.text('Bajar controlado'), findsOneWidget);

    // Entrenar un día: solo sus ejercicios y su plan.
    await tester.ensureVisible(find.text('Entrenar Pierna'));
    await _settle(tester);
    await tester.tap(find.text('Entrenar Pierna'));
    await _settle(tester);
    expect(_location(app), '/entrenamiento');
    expect(app.workout.routineName, 'Torso Pierna · Pierna');
    expect(app.workout.exercises.map((e) => e.id), ['e2']);
    expect(app.workout.routineDayId, 'pierna');
    expect(find.textContaining('Objetivo: 5 × 5'), findsOneWidget);
  });

  testWidgets('"Comenzar" en una rutina de varios días pregunta el día', (
    tester,
  ) async {
    await seedMultiDayRoutine();
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    final card = find.ancestor(
      of: find.text('Torso Pierna'),
      matching: find.byType(RoutineCard),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.text('Comenzar')),
    );
    await _settle(tester);
    expect(find.text('¿Qué día vas a entrenar?'), findsOneWidget);
    await tester.tap(find.text('Torso').last);
    await _settle(tester);
    expect(app.workout.routineName, 'Torso Pierna · Torso');
    expect(app.workout.plannedFor('e1')!.weight, 60);
    // El peso y las repeticiones se precargan desde el plan.
    final weight = tester.widget<EditableText>(
      find.descendant(
        of: field('Peso (kg)'),
        matching: find.byType(EditableText),
      ),
    );
    expect(weight.controller.text, '60');
  });

  testWidgets('el editor guarda una rutina con varios días y su plan', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/rutinas/crear');
    await tester.enterText(field('Nombre de la rutina'), 'Full body');

    Future<void> addExercise(String name) async {
      await tester.ensureVisible(find.text('Añadir ejercicios'));
      await _settle(tester);
      await tester.tap(find.text('Añadir ejercicios'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(CheckboxListTile, name));
      await _settle(tester);
      await tester.tap(find.text('Añadir 1'));
      await _settle(tester);
    }

    // Día 1: Press banca con 4 series.
    await addExercise('Press banca');
    await tester.enterText(field('Series').first, '4');
    await _settle(tester);

    // Día 2: Sentadilla.
    await tester.ensureVisible(find.text('Añadir día'));
    await _settle(tester);
    await tester.tap(find.text('Añadir día'));
    await _settle(tester);
    expect(find.text('Día 2'), findsOneWidget);
    await addExercise('Sentadilla');

    await tester.dragUntilVisible(
      find.text('Guardar rutina'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Guardar rutina'));
    await _settle(tester, seconds: 2);

    final saved = await AppFirebase.firestore
        .collection('users/$_uid/routines')
        .where('name', isEqualTo: 'Full body')
        .get();
    final routine = WorkoutRoutine.fromMap(
      saved.docs.single.id,
      saved.docs.single.data(),
    );
    expect(routine.days.map((d) => d.exerciseIds), [
      ['e1'],
      ['e2'],
    ]);
    expect(routine.planFor('e1')!.sets, 4);
    expect(routine.exercises, ['e1', 'e2']);
  });

  testWidgets('calendario: días entrenados y programar un entrenamiento', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await tapMenu(tester, 'Calendario');
    expect(_location(app), '/calendario');
    expect(find.text('Mi calendario'), findsOneWidget);
    expect(find.text('Días entrenados'), findsOneWidget);
    // Hoy hay una sesión sembrada: aparece en el panel del día.
    expect(find.text('SESIONES REALIZADAS'), findsOneWidget);

    await tester.tap(find.text('Programar'));
    await _settle(tester, seconds: 2);
    expect(find.text('Programar entrenamiento'), findsWidgets);
    await tester.tap(find.text('Guardar en el calendario'));
    await _settle(tester, seconds: 2);

    final docs = await AppFirebase.firestore
        .collection('users/$_uid/scheduled_workouts')
        .get();
    expect(docs.docs.single.data()['routineId'], 'r1');
    // Hoy ya se entrenó esa rutina: el programado aparece completado.
    // Uno es la leyenda del calendario; el otro, el estado del programado.
    expect(find.text('Completado'), findsNWidgets(2));
    expect(find.text('Fuerza total'), findsWidgets);
  });

  for (final size in [const Size(360, 780), const Size(1400, 900)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('pantallas nuevas sin desbordes (${size.width.toInt()} px, '
          '$theme)', (tester) async {
        await seedMultiDayRoutine();
        final app = await _pumpApp(tester, theme: theme, size: size);
        for (final route in [
          '/calendario',
          '/progreso',
          '/ejercicio',
          '/rutinas/crear',
          '/rutinas',
        ]) {
          await _go(tester, app, route);
          expect(tester.takeException(), isNull, reason: route);
        }
        // Detalle de una rutina de varios días.
        await tester.tap(find.text('Torso Pierna'));
        await _settle(tester);
        expect(find.text('Entrenar Torso'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'detalle');
      });
    }
  }

  // Login con imagen de fondo: sin desbordes en móvil, tablet y escritorio,
  // en ambos temas, y con toda su funcionalidad visible.
  for (final size in const [
    Size(360, 800),
    Size(390, 844),
    Size(768, 1024),
    Size(1280, 720),
    Size(1400, 900),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Login con fondo: ${size.width.toInt()}×'
          '${size.height.toInt()} ($theme)', (tester) async {
        AppFirebase.authOverride = MockFirebaseAuth(signedIn: false);
        final app = await _pumpApp(tester, theme: theme, size: size);
        expect(_location(app), '/login');
        expect(tester.takeException(), isNull);

        final background = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'lib/img/fondo.png',
        );
        expect(background, findsOneWidget);
        expect(tester.widget<Image>(background).fit, BoxFit.cover);

        expect(field('Correo electrónico'), findsOneWidget);
        expect(field('Contraseña'), findsOneWidget);
        expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
        expect(find.text('Regístrate'), findsOneWidget);

        // El formulario sigue siendo usable: se valida al enviar vacío.
        await tester.ensureVisible(
          find.widgetWithText(CustomButton, 'Iniciar sesión'),
        );
        await _settle(tester);
        await tester.tap(find.widgetWithText(CustomButton, 'Iniciar sesión'));
        await _settle(tester);
        expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // ---------------------------------------------------------------------
  // Alimentación.
  // ---------------------------------------------------------------------

  /// Plan activo (copia de la plantilla de masa muscular) y un registro hoy.
  Future<void> seedNutrition() async {
    final service = NutritionService();
    await service.savePlan(
      _uid,
      NutritionTemplate.all.first.toPlan(id: 'np1', active: true),
    );
    await service.saveDay(
      _uid,
      DailyNutritionRecord(date: DateTime.now()).withEntry(
        FoodEntry(
          mealType: MealType.breakfast,
          food: NutritionCatalog.byName('Avena').toFood(100),
        ),
      ),
    );
  }

  /// Elige un alimento del catálogo en la hoja "Agregar alimento"
  /// desplazando la fila horizontal de chips si hace falta.
  Future<void> pickCatalogFood(WidgetTester tester, String name) async {
    final chip = find.widgetWithText(ActionChip, name);
    await tester.dragUntilVisible(
      chip,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListView),
      ),
      const Offset(-150, 0),
    );
    await _settle(tester);
    await tester.tap(chip);
  }

  NutritionProvider nutritionOf(_Harness app) => app
      .router
      .routerDelegate
      .navigatorKey
      .currentContext!
      .read<NutritionProvider>();

  testWidgets('Alimentación: sin plan, usar una plantilla la deja activa', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await tapMenu(tester, 'Alimentación');
    expect(_location(app), '/alimentacion');
    expect(find.text('Alimentación saludable'), findsOneWidget);
    expect(
      find.text('Selecciona un plan o crea uno personalizado.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Planes predeterminados'));
    await _settle(tester);
    expect(find.text('Pérdida de grasa'), findsWidgets);
    await tester.ensureVisible(find.text('Usar este plan').first);
    await _settle(tester);
    await tester.tap(find.text('Usar este plan').first);
    await _settle(tester, seconds: 2);

    // Se abre la copia del usuario, ya activa y con sus comidas.
    expect(find.text('Plan activo'), findsOneWidget);
    expect(find.text('Comidas'), findsOneWidget);
    expect(find.text('DESAYUNO'), findsOneWidget);
    final plans = await AppFirebase.firestore
        .collection('users/$_uid/nutrition_plans')
        .get();
    expect(plans.docs.single.data()['templateId'], 'masa-muscular');
    expect(plans.docs.single.data()['active'], isTrue);
  });

  testWidgets('crear mi plan: validación, comida y alimento del catálogo', (
    tester,
  ) async {
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await _go(tester, app, '/alimentacion/plan/nuevo');
    expect(find.text('Crear mi plan'), findsOneWidget);

    // Sin datos: no se crea.
    await tester.ensureVisible(find.text('Crear plan'));
    await _settle(tester);
    await tester.tap(find.text('Crear plan'));
    await _settle(tester);
    expect(find.text('Ingresa el nombre del plan.'), findsOneWidget);
    expect(find.text('Ingresa las calorías diarias.'), findsOneWidget);

    await tester.enterText(field('Nombre del plan'), 'Mi plan');
    await tester.enterText(field('Calorías (kcal)'), '0');
    await tester.enterText(field('Proteínas (g)'), '150');
    await tester.enterText(field('Carbohidratos (g)'), '220');
    await tester.enterText(field('Grasas (g)'), '60');
    await tester.ensureVisible(find.text('Crear plan'));
    await _settle(tester);
    await tester.tap(find.text('Crear plan'));
    await _settle(tester);
    expect(find.text('Las calorías deben ser mayores que 0.'), findsOneWidget);

    await tester.enterText(field('Calorías (kcal)'), '2100');
    await tester.ensureVisible(find.text('Crear plan'));
    await _settle(tester);
    await tester.tap(find.text('Crear plan'));
    await _settle(tester, seconds: 2);
    expect(find.text('Comidas'), findsOneWidget);
    expect(find.text('Plan activo'), findsOneWidget); // primer plan

    // Agregar comida (diálogo) y un alimento del catálogo.
    await tester.tap(find.text('Agregar comida'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await _settle(tester, seconds: 2);
    expect(find.text('DESAYUNO'), findsOneWidget);
    // El aviso "Comida agregada." puede tapar el botón.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.ensureVisible(find.text('Alimento'));
    await _settle(tester);
    await tester.tap(find.text('Alimento'));
    await _settle(tester);
    await pickCatalogFood(tester, 'Avena');
    await _settle(tester);
    await tester.enterText(field('Cantidad'), '50');
    await _settle(tester);
    final add = find.widgetWithText(CustomButton, 'Agregar alimento');
    await tester.ensureVisible(add);
    await _settle(tester);
    await tester.tap(add);
    await _settle(tester, seconds: 2);
    expect(find.text('Avena'), findsOneWidget);
    expect(find.textContaining('Total: 195 kcal'), findsOneWidget);

    final plan = nutritionOf(app).plans.single;
    expect(plan.name, 'Mi plan');
    expect(plan.calories, 2100);
    expect(plan.meals.single.foods.single.quantity, 50);
  });

  testWidgets('registro diario: el alimento se suma al progreso de hoy', (
    tester,
  ) async {
    await seedNutrition();
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await tapMenu(tester, 'Alimentación');
    final nutrition = nutritionOf(app);
    expect(nutrition.today.totals.kcal, 389);
    expect(find.text('PROGRESO DE HOY'), findsOneWidget);
    expect(find.text('Aumento de masa muscular'), findsWidgets);

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Registrar alimento'),
    );
    await _settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Almuerzo'));
    await _settle(tester);
    await pickCatalogFood(tester, 'Huevo');
    await _settle(tester);
    await tester.enterText(field('Cantidad'), '2');
    await _settle(tester);
    final submit = find.widgetWithText(CustomButton, 'Registrar');
    await tester.ensureVisible(submit);
    await _settle(tester);
    await tester.tap(submit);
    await _settle(tester, seconds: 2);

    expect(find.text('Alimento agregado.'), findsOneWidget);
    expect(nutrition.today.totals.kcal, 389 + 144);
    expect(
      nutrition.today.entriesFor(MealType.lunch).single.food.name,
      'Huevo',
    );
    // El Consumer reconstruye el progreso del plan activo (2.500 kcal).
    expect(find.textContaining('/ 2.500 kcal'), findsOneWidget);
  });

  testWidgets('el resumen del entrenamiento muestra la alimentación de hoy', (
    tester,
  ) async {
    await seedNutrition();
    final app = await _pumpApp(tester, theme: ThemeMode.light);
    app.workout.startFreeWorkout([
      ExerciseModel(id: 'e2', name: 'Sentadilla', muscleGroup: 'Piernas'),
    ]);
    app.workout.addSet('e2', weight: 50, repetitions: 10);
    await _go(tester, app, '/entrenamiento');
    await _scrollTo(tester, 'Finalizar entrenamiento');
    await tester.tap(find.text('Finalizar entrenamiento'));
    await _settle(tester);
    await tester.tap(find.text('Finalizar').last);
    await _settle(tester, seconds: 2);
    expect(find.text('Entrenamiento guardado'), findsOneWidget);
    expect(find.text('Alimentación de hoy'), findsOneWidget);
    expect(find.text('Calorías: 389 / 2.500 kcal'), findsOneWidget);
  });

  for (final size in const [
    Size(360, 800),
    Size(390, 844),
    Size(768, 1024),
    Size(1024, 768),
    Size(1400, 900),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Alimentación sin desbordes: ${size.width.toInt()} px '
          '($theme)', (tester) async {
        await seedNutrition();
        final app = await _pumpApp(tester, theme: theme, size: size);
        for (final route in [
          '/alimentacion',
          '/alimentacion/plantillas',
          '/alimentacion/plan/nuevo',
          '/alimentacion/plan/np1',
        ]) {
          await _go(tester, app, route);
          expect(tester.takeException(), isNull, reason: route);
        }
        expect(find.text('Comidas'), findsOneWidget);
        // Hoja de alimento abierta en la pantalla del plan.
        await tester.ensureVisible(find.text('Alimento').first);
        await _settle(tester);
        await tester.tap(find.text('Alimento').first);
        await _settle(tester);
        expect(find.text('Agregar alimento'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'hoja de alimento');
      });
    }
  }

  testWidgets('Alimentación carga aunque se hayan borrado datos a mano', (
    tester,
  ) async {
    // Plan de plantilla al que se le borraron createdAt y las comidas, y un
    // día sin campos de fecha.
    final plan =
        NutritionTemplate.all.first.toPlan(id: 'np1', active: true).toMap()
          ..remove('createdAt')
          ..remove('meals');
    await AppFirebase.firestore
        .doc('users/$_uid/nutrition_plans/np1')
        .set(plan);
    final key = DailyNutritionRecord.keyOf(DateTime.now());
    await AppFirebase.firestore.doc('users/$_uid/nutrition_days/$key').set({
      'entries': [
        FoodEntry(
          mealType: MealType.breakfast,
          food: NutritionCatalog.byName('Avena').toFood(100),
        ).toMap(),
      ],
    });

    final app = await _pumpApp(tester, theme: ThemeMode.light);
    await tapMenu(tester, 'Alimentación');
    expect(find.text('Cargando tu alimentación...'), findsNothing);
    expect(find.text('PROGRESO DE HOY'), findsOneWidget);
    expect(nutritionOf(app).today.totals.kcal, 389);
    // Las comidas borradas se restauraron desde la plantilla.
    expect(nutritionOf(app).activePlan!.meals, isNotEmpty);
  });
}
