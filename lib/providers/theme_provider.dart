import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema (claro, oscuro o del sistema), guardada en el
/// dispositivo para que se mantenga al cerrar y abrir la aplicación.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemeMode initialMode = ThemeMode.system})
    : _mode = initialMode;

  static const String _key = 'theme_mode';

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Lee la preferencia guardada. Si no se puede leer, usa la del sistema.
  static Future<ThemeMode> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _fromName(prefs.getString(_key));
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // Si no se puede guardar, el cambio sigue aplicado en esta sesión.
    }
  }

  static ThemeMode _fromName(String? name) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}
