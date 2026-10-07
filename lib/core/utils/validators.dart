import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico.';
    if (!_emailRegExp.hasMatch(email)) return 'Ingresa un correo válido.';
    return null;
  }

  static String? validateEmailMatch(String? email, String? confirmation) {
    final a = email?.trim() ?? '';
    final b = confirmation?.trim() ?? '';
    if (a != b) return 'Los correos no coinciden.';
    return null;
  }

  /// Formato internacional E.164: `+`, código de país y número (8–15 cifras).
  static final RegExp _phoneRegExp = RegExp(r'^\+[1-9]\d{7,14}$');

  /// Celular peruano escrito sin código de país: 9 dígitos que empiezan
  /// por 9.
  static final RegExp _localPhoneRegExp = RegExp(r'^9\d{8}$');

  static String _cleanPhone(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[\s\-().]'), '');

  /// Devuelve el teléfono en E.164, el formato que exige Firebase Auth.
  /// Quita espacios, guiones, puntos y paréntesis y, si se escribió sin
  /// `+`, añade el código de país por defecto: `987 654 321` →
  /// `+51987654321`. Un número con `+` se respeta tal cual.
  static String normalizePhone(String? value) {
    final phone = _cleanPhone(value);
    if (phone.isEmpty || phone.startsWith('+')) return phone;
    return '${AppConstants.defaultPhoneCountryCode}$phone';
  }

  /// Parte local de un teléfono guardado, para mostrarla en el campo junto
  /// al prefijo fijo: `+51987654321` → `987654321`.
  static String localPhone(String? value) {
    final phone = _cleanPhone(value);
    const code = AppConstants.defaultPhoneCountryCode;
    return phone.startsWith(code) ? phone.substring(code.length) : phone;
  }

  static String? validatePhone(String? value, {bool required = true}) {
    final phone = _cleanPhone(value);
    if (phone.isEmpty) return required ? 'Ingresa tu celular.' : null;
    if (!phone.startsWith('+')) {
      if (!_localPhoneRegExp.hasMatch(phone)) {
        return 'Ingresa los 9 dígitos de tu celular (empieza con 9).';
      }
      return null;
    }
    if (!_phoneRegExp.hasMatch(phone)) return 'Ingresa un teléfono válido.';
    return null;
  }

  static String? validateSmsCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Ingresa el código que recibiste.';
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'El código tiene 6 dígitos.';
    }
    return null;
  }

  static String? validateRequired(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'Este campo es obligatorio.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Ingresa tu contraseña.';
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }

  static String? validatePasswordMatch(String? value, String? confirmation) {
    final a = value ?? '';
    final b = confirmation ?? '';
    if (a != b) return 'Las contraseñas no coinciden.';
    return null;
  }

  static String? validateNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa un valor.';
    final parsed = double.tryParse(v.replaceAll(',', '.'));
    if (parsed == null) return 'Ingresa un número válido.';
    if (parsed < 0) return 'El valor no puede ser negativo.';
    return null;
  }

  static String? validatePositiveNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa un valor.';
    final parsed = double.tryParse(v.replaceAll(',', '.'));
    if (parsed == null) return 'Ingresa un número válido.';
    if (parsed <= 0) return 'El valor debe ser mayor a cero.';
    return null;
  }

  static int passwordScore(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (score > 4) score = 4;
    return score;
  }
}

class PasswordStrength {
  const PasswordStrength._(this.label, this.color, this.score);

  final String label;
  final Color color;
  final int score;

  factory PasswordStrength.of(String? value) {
    final score = Validators.passwordScore(value);
    if (score <= 1) {
      return PasswordStrength._('Débil', AppColors.error, score);
    }
    if (score == 2) {
      return PasswordStrength._('Aceptable', AppColors.primary, score);
    }
    if (score == 3) {
      return PasswordStrength._('Buena', AppColors.amber, score);
    }
    return PasswordStrength._('Excelente', AppColors.success, score);
  }
}
