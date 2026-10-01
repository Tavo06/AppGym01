import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/session_cleanup.dart';
import 'providers/theme_provider.dart';
import 'providers/workout_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Se lee antes de arrancar para no mostrar un destello del tema claro.
  final themeMode = await ThemeProvider.loadSavedMode();
  runApp(FitProgressApp(initialThemeMode: themeMode));
}

class FitProgressApp extends StatefulWidget {
  const FitProgressApp({super.key, this.initialThemeMode = ThemeMode.system});

  final ThemeMode initialThemeMode;

  @override
  State<FitProgressApp> createState() => _FitProgressAppState();
}

class _FitProgressAppState extends State<FitProgressApp> {
  final AuthProvider _authProvider = AuthProvider();
  final WorkoutProvider _workoutProvider = WorkoutProvider();
  final ProgressProvider _progressProvider = ProgressProvider();
  final ScheduleProvider _scheduleProvider = ScheduleProvider();
  final NutritionProvider _nutritionProvider = NutritionProvider();
  late final ThemeProvider _themeProvider = ThemeProvider(
    initialMode: widget.initialThemeMode,
  );
  late final AppRouter _appRouter;
  late final void Function() _unbindCleanup;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(_authProvider);
    _unbindCleanup = bindSessionCleanup(
      auth: _authProvider,
      workout: _workoutProvider,
      progress: _progressProvider,
      schedule: _scheduleProvider,
      nutrition: _nutritionProvider,
    );
  }

  @override
  void dispose() {
    _unbindCleanup();
    _authProvider.dispose();
    _workoutProvider.dispose();
    _progressProvider.dispose();
    _scheduleProvider.dispose();
    _nutritionProvider.dispose();
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _workoutProvider),
        ChangeNotifierProvider.value(value: _progressProvider),
        ChangeNotifierProvider.value(value: _scheduleProvider),
        ChangeNotifierProvider.value(value: _nutritionProvider),
        ChangeNotifierProvider.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'FitProgress',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
