# CLAUDE.md — FitProgress

Guía del proyecto para trabajar con Claude Code. Aplicación Flutter de gimnasio
(paquete `fitprogress`) para Android, Web y Windows, con Firebase como backend.
Textos de interfaz y comentarios del código en **español**.

## Comandos

```bash
flutter pub get
flutter analyze          # debe quedar en "No issues found!"
flutter test             # 110 pruebas; todas deben pasar
dart format lib test
flutter run -d chrome    # o -d windows / dispositivo Android
```

## Reglas de trabajo

- No borrar ni renombrar archivos, clases, rutas o funciones existentes sin
  acuerdo previo: solo añadir o extender.
- Reutilizar el tema (`AppTheme`, `AppPalette`, `AppColors`) y los widgets
  comunes de `lib/widgets/`. No crear temas nuevos.
- Mismo gestor de estado (Provider + ChangeNotifier), misma navegación
  (go_router) y misma capa de datos (Firestore vía `AppFirebase`).
- Consultar antes de añadir paquetes a `pubspec.yaml`.
- Diseño adaptativo: `Breakpoints.isWide` / `LayoutBuilder`.
- Tras cada cambio: `dart format`, `flutter analyze` y `flutter test`.

## Arquitectura

Capas simples, sin inyección de dependencias externa:

```
UI (screens/, widgets/)
  └─ estado: providers/ (ChangeNotifier) + setState para estado local
       └─ datos: services/ (FirestoreService, AuthService, GoogleAuthService)
            └─ AppFirebase (instancias de Auth/Firestore, sobreescribibles en tests)
models/ (clases de dominio con toMap/fromMap)
core/ (constantes, rutas, tema, utilidades)
```

- `main.dart` inicializa Firebase, lee el tema guardado y crea los providers
  en `_FitProgressAppState` (se registran con `ChangeNotifierProvider.value`
  dentro de un `MultiProvider`). `MaterialApp.router` usa `AppRouter`.
- `providers/session_cleanup.dart` (`bindSessionCleanup`) resetea
  `WorkoutProvider` y `ProgressProvider` cuando cambia el usuario.

## Gestor de estado

**Provider 6 + ChangeNotifier.**

| Provider | Responsabilidad |
|---|---|
| `AuthProvider` | Sesión de Firebase Auth, perfil (`UserModel`), registro, verificación, contraseña. Es el `refreshListenable` del router. |
| `WorkoutProvider` | Entrenamiento en curso: rutina, ejercicios, series por ejercicio (`Map<String, List<WorkoutSet>>`), guardado (`finishWorkout`). |
| `ProgressProvider` | Historial, récords, progreso semanal, estadísticas, metas semanales (SharedPreferences por usuario). `agregarSesion()` actualiza todo y notifica. |
| `ScheduleProvider` | Entrenamientos programados del calendario personal (`scheduled_workouts`). |
| `ThemeProvider` | Modo claro/oscuro/sistema (SharedPreferences). |

- Estado local con `setState` (p. ej. `WorkoutScreen`: serie actual, reps en
  curso, cronómetro, descanso).
- Lectura en UI: `Consumer<ProgressProvider>` (Progreso, metas),
  `context.watch` / `context.read` en el resto.
- Los providers aceptan dependencias opcionales para tests
  (`FirestoreService? firestore`, `currentUid`).

## Estructura de carpetas

```
lib/
├── main.dart, firebase_options.dart
├── core/
│   ├── constants/app_constants.dart   AppColors, AppConstants (Sets de grupos
│   │                                  musculares/objetivos/niveles, metas, colecciones)
│   ├── routes/app_router.dart         AppRoutes + AppRouter (GoRouter)
│   ├── theme/app_theme.dart           AppPalette (ThemeExtension) + AppTheme.light/dark
│   └── utils/                         formatters.dart, validators.dart, firestore_utils.dart
├── models/                            exercise, routine, workout (sesión), workout_set,
│                                      personal_record, progress (semana/estadísticas),
│                                      goal (metas), user, routine_day (días y plan
│                                      por ejercicio), scheduled_workout (calendario)
├── providers/                         auth, workout, progress, schedule, theme,
│                                      session_cleanup
├── services/                          app_firebase, firestore_service, auth_service,
│                                      google_auth_service
├── screens/
│   ├── splash/  auth/ (login, verify_email, change_password + modales
│   │            register_dialog, forgot_password_dialog)
│   ├── main/main_shell.dart           barra inferior / NavigationRail
│   ├── routines/ (lista + detalle + editor por días)   exercises/ (lista + crear/editar)
│   ├── workout/ (entrenamiento + resumen)  progress/   calendar/   home/ (Panel)
│   ├── profile/
└── widgets/                           componentes reutilizables (ver abajo)
test/                                  app_logic, firestore_logic, rubric_logic,
                                       personal_training (días, récords, calendario),
                                       auth_widgets, screens_smoke (app completa con
                                       FakeFirebaseFirestore + MockFirebaseAuth), widget_test
```

## Navegación (go_router 18)

`AppRouter` en `lib/core/routes/app_router.dart`; constantes en `AppRoutes`.

- Inicial: `/splash` → `/login` o `/rutinas` (pantalla principal).
- `StatefulShellRoute.indexedStack` (`MainShell`) con 6 ramas:
  `/rutinas` · `/entrenamiento` · `/ejercicio` · `/progreso` · `/calendario` ·
  `/profile`. Móvil: `NavigationBar` (con < 420 px solo se rotula el destino
  elegido); ancho ≥ 840: `NavigationRail`.
- Rutas a pantalla completa (`parentNavigatorKey: _rootKey`): `/home` (Panel),
  `/rutinas/crear`, `/rutinas/detalle` (devuelve con `pop` el `RoutineDay` a
  entrenar o `'edit'`), `/ejercicio/crear`, `/entrenamiento/resumen`,
  `/profile/edit`, `/change-password`.
- Varios FAB conviven en el `IndexedStack`: cada FAB nuevo necesita un
  `heroTag` propio.
- Públicas: `/login` (registro y "olvidé mi contraseña" son **modales** sobre
  el Login), `/verify-email`.
- Paso de datos con `extra`: `WorkoutRoutine` → `/entrenamiento`,
  `WorkoutSaveResult` → `/entrenamiento/resumen`, `WorkoutSession` →
  `/rutinas`, modelos a editar → `/rutinas/crear`, `/ejercicio/crear`.
- `_redirect`: alias de rutas antiguas en inglés (`_legacyRoutes`),
  autenticación, verificación de correo, contraseña pendiente.
- Las pestañas se recargan al volver a ser visibles con
  `TickerMode.valuesOf(context).enabled` en `didChangeDependencies`.

## Tema y paleta

Material 3, tipografía por defecto (sin `fontFamily`). Acceso: `context.palette`.

- **Marca** (`AppColors`): primario naranja `#FF6D00` (+ `primaryLight`
  `#FFAB66`, `primaryGradientEnd` `#FF9E40`), navy `#14213D`, success
  `#2E9E57`, error `#D64545`, amber `#F5A524`, teal `#0F9D8A`, violet `#6C5CE7`.
- **Neutros** (`AppPalette.light/dark`): `background`, `surface`,
  `surfaceMuted`, `textPrimary`, `textSecondary`, `border`, `primarySoft`,
  `secondary`, `secondaryContainer`, `onSecondaryContainer`, `shadow`.
- **Radios**: tarjetas 20, diálogos/date picker 24 (modales de auth 28),
  campos y botones 16, popups/snackbars 14, chips 12. Botones de 54 px de alto.
- **Espaciados habituales**: padding de pantalla 20 (formularios 24), separación
  entre secciones 16–18, entre campos 14–16.
- `Breakpoints`: `rail` 840, `content` 980, `form` 560.

## Widgets reutilizables (`lib/widgets/`)

| Widget | Uso |
|---|---|
| `CustomButton` (`ButtonVariant.primary/secondary/outline/text`, `loading`) | Botón principal de la app |
| `CustomTextField`, `CustomDropdown` | Campos de formulario con icono |
| `ConfirmationDialog.show(...)` | Confirmaciones (destructivas o no) |
| `AuthModal`, `showAuthModal`, `AuthModalSection`, `AuthModalError` | Modal centrado animado con icono en degradado |
| `CreatePasswordDialog` | Modal "Crear contraseña" |
| `showAppMessage(context, msg, type:)` (`app_feedback.dart`) | SnackBars de éxito/error |
| `EmptyState`, `ErrorState`, `LoadingWidget` | Estados vacíos, error con reintento, carga |
| `ProgressCard`, `StatGrid`, `SectionHeader` | Tarjetas de estadística y rejilla adaptativa |
| `RoutineCard`, `WorkoutCard` | Tarjetas de rutina y de entrenamiento |
| `WeeklyGoalsCard` | Metas semanales (`Consumer<ProgressProvider>`) |
| `MonthCalendar`, `DayMarkers` | Calendario mensual (L–D) con indicadores por día |
| `showExerciseHistorySheet` | Historial de un ejercicio |
| `MaxWidth`, `FormScrollView`, `Breakpoints` (`responsive.dart`) | Layout adaptativo |
| `AppLogo`, `showFreeWorkoutSheet` | Logo; hoja de entrenamiento libre |

Utilidades: `Formatters` (números, peso, volumen, duración, fechas en `es`),
`Validators` (correo, requerido, contraseña, números), `firestoreDateFrom`.

## Capa de datos

- **Firebase Auth** (correo/contraseña y Google) — `AuthService`.
- **Cloud Firestore** — `FirestoreService`. Todo cuelga de `users/{uid}`:
  `exercises`, `routines` (con `days` y, por compatibilidad, la lista plana
  `exercises`), `workouts` (con `routineDayId`), `personal_records` (peso ×
  reps y `bestVolume`), `weekly_progress`, `scheduled_workouts`.
  `saveWorkout` usa una transacción (sesión + semana + récords).
- Compatibilidad: una rutina sin `days` se lee como un único "Día 1"
  (`RoutineDay.fromExerciseIds`); un récord sin `bestVolume` no anuncia un
  récord de volumen.
- **Reglas** (`firestore.rules`): cada usuario solo lee/escribe
  `users/{uid}` y sus subcolecciones. No hay datos compartidos entre cuentas.
- **SharedPreferences**: tema y metas semanales.
- Sin Firebase Storage ni API externa. Fechas como `Timestamp` →
  `firestoreDateFrom`.
- Modelos **encapsulados**: campos privados con getters, parámetros nombrados
  privados (`required this._name`, llamado como `name:`), listas inmutables;
  los cambios se hacen con `copyWith` u otros métodos.
- Tests: `AppFirebase.firestoreOverride = FakeFirebaseFirestore()` y
  `AppFirebase.authOverride = MockFirebaseAuth(...)`.

## Paquetes

firebase_core, firebase_auth, cloud_firestore, google_sign_in, provider,
go_router, fl_chart (gráficos de barras/líneas/tarta), intl, shared_preferences,
flutter_localizations. Dev: flutter_lints, fake_cloud_firestore,
firebase_auth_mocks.

## Funcionalidades existentes

- Autenticación: registro (modal), verificación de correo, creación de
  contraseña (modal), login con correo o Google, recuperar contraseña (modal),
  cambiar contraseña, cierre de sesión con limpieza de estado.
- Perfil: datos, objetivo y nivel, actividad reciente, tema claro/oscuro/sistema.
- Ejercicios: catálogo propio con grupo muscular y equipamiento, búsqueda,
  filtros por grupo (Set), crear/editar/eliminar.
- Ejercicios: además, el uso real de cada uno (mejor marca, último peso,
  series, sesiones) y su historial.
- Rutinas: por días (`RoutineDay`) con plan por ejercicio (`RoutineExercise`:
  series, reps, peso, descanso, notas). Editor con días (añadir, renombrar,
  duplicar, mover, eliminar) y ejercicios reordenables; detalle de rutina;
  "Comenzar" pregunta el día si hay varios. La rutina (un día, con
  `forDay`) viaja por `extra`. Entrenamiento libre.
- Entrenamiento: objetivo del plan, "Serie X / N", ejercicios completos /
  total, precarga de peso, reps y descanso desde el plan, "Siguiente
  ejercicio"; series con estado local, cronómetro, descanso con pausa,
  finalizar/descartar. El resumen muestra ejercicios realizados, récords
  (más peso, más reps con el mismo peso, mejor volumen) y la comparación con
  la sesión anterior equivalente; la sesión vuelve a Rutinas.
- Progreso: estadísticas (Consumer) con tiempo entrenado y racha, metas
  semanales editables, semana actual (entrenamientos, series, volumen,
  tiempo, por día y comparación), historial de 12 semanas (do-while),
  progreso por ejercicio (Map) con mejor peso por semana, récords.
- Calendario (`/calendario`): mes con días entrenados y entrenamientos
  programados (repetición semanal opcional), panel del día con sesiones y
  programados (entrenar, quitar, completado/no realizado).
- Panel (`/home`): resumen semanal, racha, último entrenamiento (repite el
  mismo día de la rutina), último récord, accesos rápidos.

**Alcance:** aplicación **personal**. Cada usuario ve y gestiona solo su
entrenamiento. Fuera de alcance por decisión: gestión de otros usuarios,
clientes, entrenadores/staff, asignaciones, invitaciones, calendarios de
equipo, asistencia, capacidad de clases y nutrición.
