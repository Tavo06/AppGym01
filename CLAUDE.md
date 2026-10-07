# CLAUDE.md — Vatio

Guía del proyecto para trabajar con Claude Code. Aplicación Flutter de gimnasio
**Vatio** ("Pura energía para entrenar"; antes FitProgress) para Android, Web y
Windows, con Firebase como backend. Textos de interfaz y comentarios del código
en **español**.

- El nombre visible sale de `AppConstants.appName` y está en
  `AndroidManifest.xml`, `web/index.html`, `web/manifest.json` y
  `windows/runner` (`main.cpp`, `Runner.rc`). El **paquete** sigue siendo
  `fitprogress` (y el applicationId de Android): la configuración de Firebase
  depende de ellos, no cambiarlos.
- Logo: `AppLogo` / `VatioMarkPainter` (`lib/widgets/app_logo.dart`), loseta
  biselada con degradado índigo→violeta y rayo lima. Los iconos de Android,
  web y Windows se generaron desde ese mismo painter.

## Comandos

```bash
flutter pub get
flutter analyze          # debe quedar en "No issues found!"
flutter test             # 230 pruebas; todas deben pasar
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
  dentro de un `MultiProvider`). `MaterialApp.router` usa `AppRouter`; su
  `builder` envuelve la app en `AchievementAnnouncer` (avisos de logros).
- `providers/session_cleanup.dart` (`bindSessionCleanup`) resetea
  `WorkoutProvider`, `ProgressProvider`, calendario, alimentación y logros
  cuando cambia el usuario.
- `providers/achievement_binding.dart` (`bindAchievements`) recalcula las
  métricas de logros cuando cambian progreso, calendario o alimentación, y al
  iniciar sesión carga el progreso y los logros guardados.

## Gestor de estado

**Provider 6 + ChangeNotifier.**

| Provider | Responsabilidad |
|---|---|
| `AuthProvider` | Sesión de Firebase Auth, perfil (`UserModel`), registro, verificación, contraseña. Es el `refreshListenable` del router. |
| `WorkoutProvider` | Entrenamiento en curso: rutina, ejercicios, series por ejercicio (`Map<String, List<WorkoutSet>>`), guardado (`finishWorkout`). |
| `ProgressProvider` | Historial, récords, progreso semanal, estadísticas, metas semanales (SharedPreferences por usuario). `agregarSesion()` actualiza todo y notifica. |
| `ScheduleProvider` | Entrenamientos programados del calendario personal (`scheduled_workouts`). |
| `NutritionProvider` | Comida: objetivo diario (`setDailyGoal`, guardado en el plan activo), planes, comidas, alimentos, consumo diario, agua (`addWater`/`setWater`, `waterGoal`) y estadísticas. `ensureLoaded()` carga bajo demanda. Los cambios del día pasan por `_updateDay` (memoria primero, revierte si falla). |
| `AchievementProvider` | Logros conseguidos (`achievements`), métricas (`updateStats`), anuncios (`takeAnnouncements`, `announcedSince`). Lo conseguido en la primera evaluación de cada fuente se guarda sin anunciar. |
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
│                                      por ejercicio), scheduled_workout (calendario),
│                                      nutrition (plan, comida, alimento, consumo diario),
│                                      achievement (métricas AchievementStats, logro conseguido)
├── providers/                         auth, workout, progress, schedule, nutrition,
│                                      achievement, theme, session_cleanup,
│                                      achievement_binding
├── services/                          app_firebase, firestore_service, nutrition_service,
│                                      achievement_service, auth_service, google_auth_service,
│                                      rest_client, wger_service, open_food_facts_service
│   (core/constants/nutrition_catalog.dart: alimentos comunes y 4 plantillas;
│    core/constants/achievement_catalog.dart: definiciones de logros)
├── screens/
│   ├── splash/  auth/ (login, verify_email, change_password + modales
│   │            register_dialog, forgot_password_dialog)
│   ├── main/main_shell.dart           barra inferior / NavigationRail
│   ├── routines/ (lista + detalle + editor por días)   exercises/ (lista + crear/editar)
│   ├── workout/ (entrenamiento + resumen)  progress/   calendar/   home/ (Panel)
│   ├── nutrition/ (principal, plantillas, formulario de plan, detalle de plan)
│   ├── profile/ (perfil, editar, achievements_screen)
└── widgets/                           componentes reutilizables (ver abajo)
test/                                  app_logic, firestore_logic, rubric_logic,
                                       personal_training (días, récords, calendario),
                                       nutrition (modelos, plantillas, provider, UID),
                                       achievements (catálogo, rachas, métricas, provider),
                                       auth_widgets, screens_smoke (app completa con
                                       FakeFirebaseFirestore + MockFirebaseAuth), widget_test
```

## Navegación (go_router 18)

`AppRouter` en `lib/core/routes/app_router.dart`; constantes en `AppRoutes`.

- Inicial: `/splash` → `/login` o `/hoy` (pantalla de inicio).
- `StatefulShellRoute.indexedStack` (`MainShell`) con 8 ramas. Las **5
  primeras son las pestañas** (mismo orden que la barra): `/hoy` (Hoy) ·
  `/rutinas` (Entrenar) · `/alimentacion` (Comida) · `/progreso` ·
  `/profile`. Las **3 últimas no tienen pestaña**: `/entrenamiento` y
  `/ejercicio` marcan "Entrenar" y `/calendario` marca "Hoy"
  (`MainShell.parentTab`, índices en `ShellBranch`). Se llega a ellas con
  `go`. **Rutinas y Ejercicios** comparten el selector `TrainSectionTabs`
  ("Rutinas | Ejercicios") en lo alto de la pestaña Entrenar; entrenamiento
  y calendario tienen `TabBackButton` para volver a su pestaña. El
  calendario se abre desde la franja semanal de Hoy; los logros, desde
  Progreso y Perfil.
- "Entrenar" con un entrenamiento en curso lleva a `/entrenamiento`, que se
  muestra en modo foco sin barra de navegación.
- Móvil: `NavigationBar` flotante con las 5 etiquetas; ancho ≥ 840:
  `NavigationRail`.
- Alimentación (pantalla completa, **sin acceso desde la interfaz** desde la
  simplificación a "objetivo diario"; se conservan las rutas):
  `/alimentacion/plantillas`, `/alimentacion/plan/nuevo` y
  `/alimentacion/plan/:id`.
- Rutas a pantalla completa (`parentNavigatorKey: _rootKey`):
  `/rutinas/crear`, `/rutinas/detalle` (devuelve con `pop` el `RoutineDay` a
  entrenar o `'edit'`), `/ejercicio/crear`, `/ejercicio/catalogo` (catálogo
  wger), `/entrenamiento/resumen`,
  `/profile/edit`, `/profile/logros` (Mis logros), `/change-password`.
  `/home` (antiguo Panel) es un alias de `/hoy`.
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

Material 3. Acceso: `context.palette`.

- **Tipografía Outfit** (`AppTheme.fontFamily`): archivos estáticos de 300 a
  900 en `assets/fonts/outfit/` (licencia SIL OFL en `OFL.txt`), declarados
  en `pubspec.yaml`. Va en `ThemeData` **y en cada `TextStyle` del tema**
  (los estilos de los componentes sustituyen al de por defecto). Los textos
  de las pantallas la heredan: no poner `inherit: false` ni otra
  `fontFamily`. En las pruebas no se cargan fuentes (el texto sale como
  bloques en capturas salvo que se cargue con `FontLoader`).
Diseño **índigo + lima, "suave y elevado"**.

- **Marca** (`AppColors`, igual en claro y oscuro): primario índigo `#5B5BF0`
  (+ `primaryLight` `#A9AAF9`, `primaryGradientEnd` violeta `#8B5CF6` para el
  degradado de marca), acento lima `accent` `#A3E635` con `onAccent`
  `#1A2E05` (solo como relleno: indicador de navegación, racha, día de hoy),
  `navy` (tinta índigo `#1C1D3F`), success `#16A34A`, error `#EF4444`, amber
  `#F59E0B`, teal `#0D9488`, violet `#A855F7`.
- **Neutros** (`AppPalette.light/dark`): `background`, `surface`,
  `surfaceMuted`, `textPrimary`, `textSecondary`, `border`, `primarySoft`,
  `secondary`, `secondaryContainer`, `onSecondaryContainer`, `shadow` y
  `primaryText` (primario para **texto** sobre superficies: en oscuro es un
  índigo más claro; usar este y no `AppColors.primary` en textos).
- **Superficies**: tarjetas redondeadas sin borde con sombra suave (en
  oscuro, borde tenue sin sombra). **Botones, chips, FAB, indicadores y días
  de la semana biselados** (esquinas cortadas, `AppShapes.button/small/chip`:
  la seña de identidad de Vatio). Barra inferior flotante y redondeada
  (`MainShell`) con indicador lima. "Esta semana" (Hoy) es la tarjeta
  protagonista con el degradado de marca.
- **Radios** (`AppRadii`): tarjetas 24, diálogos/hojas/date picker 28, campos
  18, popups/snackbars 16. Botones de 54 px de alto y **ancho mínimo
  infinito** (`Size.fromHeight(54)`): dentro de una `Row` o un `Wrap` hay que
  darles `minimumSize: Size(0, …)`.
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
| `WeekStrip`, `dayMarkersFor` | Semana en franja de 7 días (L–D) con marcas; marcas por día desde progreso, calendario y comida |
| `MonthCalendar`, `DayMarkers` | Calendario mensual (ya no se usa en pantalla) y marcas por día (entrenado, programado, completado, alimentación) |
| `TabBackButton` | "Volver" de las pantallas sin pestaña propia (va a su pestaña con `go`) |
| `TrainSectionTabs` | Selector "Rutinas / Ejercicios" de la pestaña Entrenar |
| `startScheduledWorkout` | Entrenar un programado (Calendario y Hoy) |
| `DayNutritionSummary` | kcal y agua de un día frente al objetivo y la meta (+250 ml opcional) |
| `showDailyGoalSheet` | Hoja "Tu objetivo diario" (plantilla o personalizado; kcal y proteína) |
| `showExerciseHistorySheet` | Historial de un ejercicio |
| `NutritionProgressPanel`, `MacroRing`, `MacroSummaryText`, `MacroColors` | Calorías y macros frente a objetivos |
| `showFoodFormSheet`, `FoodRow` | Agregar/editar/registrar alimento (Open Food Facts, catálogo local o manual); fila de alimento |
| `showFoodSearchSheet` | Buscar en Open Food Facts por nombre o código de barras |
| `WaterTrackerCard` | Agua de hoy frente a la meta: +250/+500 ml, otra cantidad, quitar, editar meta (`Consumer<NutritionProvider>`) |
| `AchievementBadge`, `AchievementTile`, `AchievementColors`, `AchievementAnnouncer` | Insignia por nivel, fila con avance o fecha, colores bronce/plata/oro, aviso global (arriba) de logro nuevo |
| `MaxWidth`, `FormScrollView`, `Breakpoints` (`responsive.dart`) | Layout adaptativo |
| `AppLogo`, `VatioMarkPainter`, `showFreeWorkoutSheet` | Logo de Vatio (y su dibujo, para iconos); hoja de entrenamiento libre |

Utilidades: `Formatters` (números, peso, volumen, duración, fechas en `es`),
`Validators` (correo, requerido, contraseña, números), `firestoreDateFrom`.

## Capa de datos

- **Firebase Auth** (correo/contraseña y Google) — `AuthService`.
- **Cloud Firestore** — `FirestoreService`. Todo cuelga de `users/{uid}`:
  `exercises`, `routines` (con `days` y, por compatibilidad, la lista plana
  `exercises`), `workouts` (con `routineDayId`), `personal_records` (peso ×
  reps y `bestVolume`), `weekly_progress`, `scheduled_workouts`,
  `achievements/{id}` (`unlockedAt`; el ID es el del catálogo y no debe
  cambiar).
  `saveWorkout` usa una transacción (sesión + semana + récords).
- **Alimentación** — `NutritionService`, también bajo `users/{uid}`:
  `nutrition_plans/{id}` (comidas y alimentos incrustados, campo `active`;
  activar es un batch que desactiva el resto) y `nutrition_days/{yyyy-MM-dd}`
  (consumo real, separado del plan, con `waterMl` para el agua). Un día sin
  alimentos ni agua (`hasNoData`) borra su documento; `isEmpty` solo mira
  los alimentos (un día con solo agua no cuenta en las estadísticas de comidas).
- Compatibilidad: una rutina sin `days` se lee como un único "Día 1"
  (`RoutineDay.fromExerciseIds`); un récord sin `bestVolume` no anuncia un
  récord de volumen; un día sin `waterMl` se lee con 0 ml.
- **Reglas** (`firestore.rules`): cada usuario solo lee/escribe
  `users/{uid}` y sus subcolecciones. No hay datos compartidos entre cuentas.
- **SharedPreferences**: tema, metas semanales y meta diaria de agua
  (`water_goal_{uid}`, 2000 ml por defecto).
- Sin Firebase Storage. Fechas como `Timestamp` → `firestoreDateFrom`.
- **API REST externas** (públicas, sin clave), con `package:http` a través de
  `RestClient` (`services/rest_client.dart`: GET con tiempo máximo de 15 s,
  JSON, `ApiException` con mensaje en español, User-Agent fuera de la web):
  - **wger** (`WgerService`, `https://wger.de/api/v2/exerciseinfo/`):
    catálogo de ejercicios. El servidor ignora los filtros de idioma y la
    búsqueda; sí respeta `category`, `limit/offset` y `next`. Se prefiere la
    traducción en español (idioma 4), luego inglés (2); categoría → grupo
    muscular de la app; equipamiento traducido. Licencia CC-BY-SA.
  - **Open Food Facts** (`OpenFoodFactsService`): búsqueda por nombre en
    `search.openfoodfacts.org/search` (no envía CORS: en la **web** el
    navegador la bloquea y se muestra un aviso) y producto por código de
    barras en `world.openfoodfacts.org/api/v2/product/{código}` (con CORS).
    Valores por 100 g. Licencia ODbL.
  - Tests: `RestClient.clientOverride = MockClient(...)`
    (`package:http/testing.dart`); nunca contra la red real.
- Modelos **encapsulados**: campos privados con getters, parámetros nombrados
  privados (`required this._name`, llamado como `name:`), listas inmutables;
  los cambios se hacen con `copyWith` u otros métodos.
- Tests: `AppFirebase.firestoreOverride = FakeFirebaseFirestore()` y
  `AppFirebase.authOverride = MockFirebaseAuth(...)`.

## Paquetes

firebase_core, firebase_auth, cloud_firestore, google_sign_in, provider,
go_router, fl_chart (gráficos de barras/líneas/tarta), intl, shared_preferences,
flutter_localizations, http (API REST de wger y Open Food Facts). Dev:
flutter_lints, fake_cloud_firestore, firebase_auth_mocks.

## Funcionalidades existentes

- Autenticación: registro (modal), verificación de correo, creación de
  contraseña (modal), login con correo o Google, recuperar contraseña (modal),
  cambiar contraseña, cierre de sesión con limpieza de estado.
  - Verificación de correo: `AuthService.reloadEmailVerification` recarga el
    usuario y, si `emailVerified` sigue en `false` (pasa en escritorio),
    renueva el token y usa su claim `email_verified`. `AuthProvider` lo
    recuerda (`_emailVerifiedUid`) y **todo** debe leer
    `isEmailVerified`, nunca `User.emailVerified` directamente. La pantalla
    `/verify-email` comprueba sola al volver a la app (`resumed`).
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
- Entrenamiento en **modo foco** (`WorkoutScreen`): siempre oscuro
  (`Theme` con `AppTheme.dark`; los métodos usan la paleta `_p` fijada en
  `build`) y sin barra de navegación mientras hay un entrenamiento en curso
  (`MainShell`); se sale con "volver" y se retoma con "Entrenar". Barra de
  progreso por segmentos (uno por ejercicio, lima = completo; tocar = ir),
  un ejercicio por página (`PageView`: deslizar o flechas), contador de
  serie grande ("Serie X / N"), objetivo del plan, mandos grandes de peso
  (±2,5 kg) y reps (±1), precarga de peso, reps y descanso desde el plan,
  descanso con anillo (pausar, +15 s, saltar), series hechas, "Siguiente
  ejercicio", cronómetro en la barra superior, "Finalizar entrenamiento"
  fijo abajo y "Descartar" en el menú. El resumen muestra ejercicios realizados, récords
  (más peso, más reps con el mismo peso, mejor volumen) y la comparación con
  la sesión anterior equivalente; la sesión vuelve a Rutinas.
- Progreso: estadísticas (Consumer) con tiempo entrenado y racha, metas
  semanales editables, semana actual (entrenamientos, series, volumen,
  tiempo, por día y comparación), historial de 12 semanas (do-while),
  progreso por ejercicio (Map) con mejor peso por semana, récords.
- Calendario semanal ("Mi semana", `/calendario`): franja de 7 días
  (`WeekStrip`, flechas o deslizar) con días entrenados, programados
  (repetición semanal opcional) y alimentación (marca violeta: comida
  registrada o meta de agua cumplida); resumen de la semana; panel del día
  con sesiones, programados (entrenar, quitar, completado/no realizado) y
  kcal/agua. Puede abrirse en un día concreto (`extra: DateTime`).
- Hoy (`/hoy`, inicio; antes el Panel): franja de la semana actual (tocar un
  día abre el calendario), "Plan de hoy" (programados con "Entrenar", kcal y
  agua con +250 ml si usa Comida), "Esta semana" (tarjeta protagonista),
  metas, último entrenamiento (repite el mismo día de la rutina), último
  récord, accesos rápidos.
- Comida (`/alimentacion`). Orden: **primero "Tus comidas"**, solo
  **Desayuno, Almuerzo y Cena** (`MealType.daily`): una tarjeta por comida
  con franja de color (ámbar, índigo, violeta), franja del día, kcal,
  alimentos (catálogo local o manual) y "Añadir". Las comidas antiguas
  (media mañana, merienda, snack) siguen en el enum para leer datos
  guardados y se muestran agrupadas (`MealType.dailyGroup`,
  `DailyNutritionRecord.entriesInGroup`): media mañana → desayuno, merienda →
  almuerzo, snack → cena. Después, el **objetivo diario**: anillo de kcal (lo
  que queda o lo que se pasó) y proteína; "Definir/Editar objetivo"
  (`showDailyGoalSheet`: punto de partida de las 4 plantillas, con la del
  objetivo del perfil preseleccionada, o personalizado; kcal y proteína
  editables) que se guarda con `NutritionProvider.setDailyGoal` en el plan
  activo (o en uno nuevo "Mi objetivo diario"); luego agua y "Tu semana" (promedios de 7 días,
  días registrados, cumplimiento ±10 %, agua). Ya no hay lista de planes ni
  editor de comidas por plan en la interfaz (las pantallas y los datos se
  conservan). El resumen del entrenamiento muestra "Alimentación de hoy".
- Hidratación (dentro de Comida): agua de hoy con cantidades rápidas, otra
  cantidad y deshacer; meta diaria editable; media de 7 días y días con la
  meta cumplida.
- Logros (`/profile/logros`): 28 logros en 6 categorías (constancia, fuerza,
  volumen, planificación, alimentación, hidratación) con nivel bronce/plata/
  oro, calculados con los datos existentes. Pantalla con resumen y avance de
  cada uno, acceso desde Progreso y Perfil, sección en el resumen del
  entrenamiento y aviso global arriba "¡Logro desbloqueado!" con "Ver"
  (`AchievementAnnouncer`: encolado, 4 s, por encima de hojas modales).

**Alcance:** aplicación **personal**. Cada usuario ve y gestiona solo su
entrenamiento y su alimentación. Fuera de alcance por decisión: gestión de
otros usuarios, clientes, entrenadores/staff/nutricionistas, asignaciones,
invitaciones, calendarios de equipo, asistencia, capacidad de clases y
recomendaciones médicas. (La API externa de alimentos, antes fuera de
alcance, se incorporó con Open Food Facts.)
