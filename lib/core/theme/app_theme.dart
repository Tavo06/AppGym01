import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Colores neutros que cambian entre modo claro y oscuro.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.primarySoft,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.shadow,
    required this.primaryText,
  });

  /// Fondo de las pantallas.
  final Color background;

  /// Fondo de tarjetas, diálogos y barras.
  final Color surface;

  /// Relleno de campos, chips y zonas secundarias.
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// Fondo suave de la marca (iconos, destacados).
  final Color primarySoft;

  /// Índigo de la marca usado como color de texto o icono.
  final Color secondary;

  /// Tinta de la marca usada como fondo (botón secundario, avisos).
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color shadow;

  /// Color primario para texto e iconos sobre las superficies: en oscuro
  /// es un índigo más claro para que se lea bien sobre fondos oscuros.
  final Color primaryText;

  static const light = AppPalette(
    background: Color(0xFFF5F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF0F8),
    textPrimary: Color(0xFF12131A),
    textSecondary: Color(0xFF5D6178),
    border: Color(0xFFE4E6F0),
    primarySoft: Color(0xFFECECFE),
    secondary: Color(0xFF3B3BC4),
    secondaryContainer: AppColors.navy,
    onSecondaryContainer: Color(0xFFFFFFFF),
    shadow: Color(0x242E3192),
    primaryText: Color(0xFF4B4BE0),
  );

  static const dark = AppPalette(
    background: Color(0xFF0B0C14),
    surface: Color(0xFF151726),
    surfaceMuted: Color(0xFF1F2236),
    textPrimary: Color(0xFFEEF0FF),
    textSecondary: Color(0xFFA3A8C3),
    border: Color(0xFF2A2E48),
    primarySoft: Color(0xFF25265A),
    secondary: Color(0xFFB4B6FF),
    secondaryContainer: Color(0xFF2A2C5A),
    onSecondaryContainer: Color(0xFFFFFFFF),
    shadow: Color(0x99000000),
    primaryText: Color(0xFF9B9CFF),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? primarySoft,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? shadow,
    Color? primaryText,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      primarySoft: primarySoft ?? this.primarySoft,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      shadow: shadow ?? this.shadow,
      primaryText: primaryText ?? this.primaryText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

/// Radios del diseño "suave y elevado".
abstract final class AppRadii {
  static const double card = 24;
  static const double dialog = 28;
  static const double field = 18;
  static const double popup = 16;
}

/// Formas biseladas de Vatio (esquinas cortadas en diagonal): botones,
/// chips, FAB e indicadores. Las tarjetas siguen redondeadas.
abstract final class AppShapes {
  /// Botones de 54 px y FAB.
  static const button = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  /// Botones de texto, indicadores de navegación y segmentos.
  static const small = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  /// Chips y etiquetas.
  static const chip = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
}

class AppTheme {
  AppTheme._();

  /// Tipografía de la marca (assets/fonts/outfit, declarada en pubspec).
  /// Se pone también en cada `TextStyle` del tema: los estilos de los
  /// componentes sustituyen al de por defecto y, sin ella, saldrían con la
  /// fuente del sistema.
  static const String fontFamily = 'Outfit';

  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: p.secondary,
          tertiary: AppColors.accent,
          onTertiary: AppColors.onAccent,
          error: AppColors.error,
          surface: p.surface,
          onSurface: p.textPrimary,
          onSurfaceVariant: p.textSecondary,
          surfaceContainerHighest: p.surfaceMuted,
          outline: p.border,
          outlineVariant: p.border,
          shadow: p.shadow,
        );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
    );

    // Tipografía por defecto, algo más compacta en los títulos.
    final textTheme = base.textTheme
        .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );

    // Formas biseladas (esquinas cortadas): la seña de identidad de Vatio.

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      // Tarjetas sin borde con sombra suave; en oscuro la sombra no se ve y
      // se sustituye por un borde muy tenue.
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 3,
        shadowColor: p.shadow,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: isDark
              ? BorderSide(color: p.border.withValues(alpha: 0.7))
              : BorderSide.none,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: p.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(fontFamily: fontFamily, color: p.textSecondary),
        labelStyle: TextStyle(fontFamily: fontFamily, color: p.textSecondary),
        // La etiqueta solo se resalta con el color de marca en el campo con
        // el foco.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            color: states.contains(WidgetState.error)
                ? AppColors.error
                : states.contains(WidgetState.focused)
                ? p.primaryText
                : p.textSecondary,
          ),
        ),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
      // Botones tipo píldora.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: AppShapes.button,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: p.border, width: 1.4),
          shape: AppShapes.button,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryText,
          shape: AppShapes.small,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        highlightElevation: 6,
        shape: AppShapes.button,
        extendedTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceMuted,
        selectedColor: AppColors.primary,
        side: BorderSide.none,
        checkmarkColor: AppColors.onPrimary,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: AppShapes.chip,
      ),
      // Barra inferior (flotante, ver MainShell): indicador lima con el
      // icono oscuro encima.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: AppColors.accent,
        indicatorShape: AppShapes.small,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            color: states.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textSecondary,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.onAccent
                : p.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: AppColors.accent,
        indicatorShape: AppShapes.small,
        selectedIconTheme: const IconThemeData(color: AppColors.onAccent),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(AppShapes.small),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.primarySoft
                : p.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.primaryText
                : p.textPrimary,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : p.surfaceMuted,
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.onSecondaryContainer,
          fontSize: 12.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.secondaryContainer,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.onSecondaryContainer,
        ),
        actionTextColor: AppColors.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
      ),
    );
  }
}
