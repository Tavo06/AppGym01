import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/exercise_model.dart';
import '../../models/routine_model.dart';
import '../../models/workout_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/change_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../models/nutrition_model.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/nutrition/nutrition_plan_form_screen.dart';
import '../../screens/nutrition/nutrition_plan_screen.dart';
import '../../screens/nutrition/nutrition_screen.dart';
import '../../screens/nutrition/nutrition_templates_screen.dart';
import '../../screens/exercises/create_exercise_screen.dart';
import '../../screens/exercises/exercise_catalog_screen.dart';
import '../../screens/exercises/exercises_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/main/main_shell.dart';
import '../../screens/profile/achievements_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/progress/progress_screen.dart';
import '../../screens/routines/create_routine_screen.dart';
import '../../screens/routines/routine_detail_screen.dart';
import '../../screens/routines/routines_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/workout/workout_screen.dart';
import '../../screens/workout/workout_summary_screen.dart';
import '../../services/firestore_service.dart';

/// Rutas nombradas de la aplicación.
abstract final class AppRoutes {
  static const String rutinas = '/rutinas';
  static const String entrenamiento = '/entrenamiento';
  static const String ejercicio = '/ejercicio';
  static const String progreso = '/progreso';
  static const String perfil = '/profile';
  static const String logros = '/profile/logros';

  /// Antigua ruta del Panel; ahora es un alias de [hoy].
  static const String panel = '/home';

  /// Pestaña "Hoy" (pantalla de inicio).
  static const String hoy = '/hoy';
  static const String crearRutina = '/rutinas/crear';
  static const String detalleRutina = '/rutinas/detalle';
  static const String calendario = '/calendario';
  static const String alimentacion = '/alimentacion';
  static const String plantillasAlimentacion = '/alimentacion/plantillas';
  static const String nuevoPlanAlimentacion = '/alimentacion/plan/nuevo';
  static const String planAlimentacion = '/alimentacion/plan/:id';
  static const String crearEjercicio = '/ejercicio/crear';

  /// Catálogo público de ejercicios (API REST de wger).
  static const String catalogoEjercicios = '/ejercicio/catalogo';
  static const String resumen = '/entrenamiento/resumen';
}

class AppRouter {
  AppRouter(this._authProvider);

  final AuthProvider _authProvider;
  final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

  /// Registro y recuperación de contraseña son modales sobre `/login`.
  static const Set<String> _publicRoutes = {'/login'};

  /// Rutas antiguas (en inglés) que se conservan como alias, para no romper
  /// enlaces guardados. Redirigen a la ruta equivalente y mantienen `extra`.
  static const Map<String, String> _legacyRoutes = {
    '/routines': AppRoutes.rutinas,
    '/routines/create': AppRoutes.crearRutina,
    '/workout': AppRoutes.entrenamiento,
    '/workout/summary': AppRoutes.resumen,
    '/exercises': AppRoutes.ejercicio,
    '/exercises/create': AppRoutes.crearEjercicio,
    '/progress': AppRoutes.progreso,
    // El Panel pasó a ser la pestaña "Hoy".
    AppRoutes.panel: AppRoutes.hoy,
    // Antes eran páginas; ahora son modales que se abren desde el Login.
    '/register': '/login',
    '/forgot-password': '/login',
  };

  late final GoRouter _router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _authProvider,
    redirect: _redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.logros,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      // Alimentación. `/alimentacion/plan/nuevo` va antes que `:id` para que
      // no se interprete "nuevo" como identificador.
      GoRoute(
        path: AppRoutes.plantillasAlimentacion,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NutritionTemplatesScreen(),
      ),
      GoRoute(
        path: AppRoutes.nuevoPlanAlimentacion,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => NutritionPlanFormScreen(
          plan: state.extra is NutritionPlan
              ? state.extra as NutritionPlan
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.planAlimentacion,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            NutritionPlanScreen(planId: state.pathParameters['id'] ?? ''),
      ),
      // Recibe la rutina (relacionada con sus ejercicios) y devuelve con
      // `pop` el día elegido para entrenar o 'edit'.
      GoRoute(
        path: AppRoutes.detalleRutina,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => RoutineDetailScreen(
          routine: state.extra is WorkoutRoutine
              ? state.extra as WorkoutRoutine
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.crearRutina,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => CreateRoutineScreen(
          routine: state.extra is WorkoutRoutine
              ? state.extra as WorkoutRoutine
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.crearEjercicio,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => CreateExerciseScreen(
          exercise: state.extra is ExerciseModel
              ? state.extra as ExerciseModel
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.catalogoEjercicios,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ExerciseCatalogScreen(),
      ),
      // Recibe el resultado del entrenamiento recién guardado.
      GoRoute(
        path: AppRoutes.resumen,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => WorkoutSummaryScreen(
          result: state.extra is WorkoutSaveResult
              ? state.extra as WorkoutSaveResult
              : null,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        // Las 5 primeras ramas son las pestañas visibles (en el mismo orden
        // que la barra de MainShell); las 3 últimas no tienen pestaña propia
        // y la barra marca su pestaña "madre" (ver MainShell.parentTab).
        branches: [
          StatefulShellBranch(
            routes: [
              // Pantalla de inicio: lo de hoy, la semana y el resumen.
              GoRoute(
                path: AppRoutes.hoy,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Pestaña "Entrenar". Recibe la sesión completada al volver
              // del entrenamiento.
              GoRoute(
                path: AppRoutes.rutinas,
                builder: (context, state) => RoutinesScreen(
                  completedSession: state.extra is WorkoutSession
                      ? state.extra as WorkoutSession
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.alimentacion,
                builder: (context, state) => const NutritionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progreso,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.perfil,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Recibe la rutina elegida en Rutinas.
              GoRoute(
                path: AppRoutes.entrenamiento,
                builder: (context, state) => WorkoutScreen(
                  routine: state.extra is WorkoutRoutine
                      ? state.extra as WorkoutRoutine
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ejercicio,
                builder: (context, state) => const ExercisesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Calendario semanal. Puede recibir el día a mostrar.
              GoRoute(
                path: AppRoutes.calendario,
                builder: (context, state) => CalendarScreen(
                  initialDay: state.extra is DateTime
                      ? state.extra as DateTime
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  GoRouter get router => _router;

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final legacy = _legacyRoutes[state.uri.path];
    if (legacy != null) return legacy;

    if (_authProvider.status == AuthStatus.initializing) {
      return null;
    }
    final loggedIn = _authProvider.status == AuthStatus.authenticated;

    if (!loggedIn) {
      if (location == '/splash' || _publicRoutes.contains(location)) {
        return null;
      }
      return '/login';
    }

    if (location == '/splash') {
      return null;
    }

    // Durante el registro la cuenta ya existe, pero el modal "Crear cuenta"
    // (abierto sobre el Login) debe terminar su flujo antes de pasar a
    // `/verify-email`.
    if (_authProvider.registering && location == '/login') {
      return null;
    }

    if (!_authProvider.isAccountVerified) {
      // Un usuario sin verificar (correo y, si se le exige, teléfono) solo
      // puede permanecer en la pantalla de verificación: cualquier otra
      // ruta lo devolvería allí.
      if (location == '/verify-email') return null;
      return '/verify-email';
    }

    // Correo verificado pero sin contraseña definitiva: el Login muestra el
    // modal "Crear contraseña" en lugar de entrar a la aplicación.
    if (_authProvider.needsPasswordSetup) {
      return location == '/login' ? null : '/login';
    }

    if (_publicRoutes.contains(location)) {
      return AppRoutes.hoy;
    }
    return null;
  }
}
