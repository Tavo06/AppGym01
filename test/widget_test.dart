import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitprogress/core/utils/validators.dart';
import 'package:fitprogress/services/auth_service.dart';
import 'package:fitprogress/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('acepta correos válidos', () {
      expect(Validators.validateEmail('usuario@correo.com'), isNull);
      expect(Validators.validateEmail('ana.garcia@gmail.co'), isNull);
    });

    test('rechaza correos inválidos', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('hola'), isNotNull);
      expect(Validators.validateEmail('hola@'), isNotNull);
    });

    test('detecta correos que no coinciden', () {
      expect(Validators.validateEmailMatch('a@b.com', 'c@d.com'), isNotNull);
      expect(Validators.validateEmailMatch('a@b.com', 'a@b.com'), isNull);
    });

    test('normaliza y valida teléfonos en formato internacional', () {
      expect(Validators.normalizePhone('+51 987-654-321'), '+51987654321');
      expect(Validators.normalizePhone('+1 (555) 123.4567'), '+15551234567');
      expect(Validators.validatePhone('+51 987 654 321'), isNull);
      expect(Validators.validatePhone(''), isNotNull);
      expect(Validators.validatePhone('', required: false), isNull);
      expect(Validators.validatePhone('+0123456789'), isNotNull);
      expect(Validators.validatePhone('+51 98'), isNotNull);
    });

    test('un celular de 9 dígitos sin + recibe el código +51', () {
      expect(Validators.normalizePhone('987 654 321'), '+51987654321');
      expect(Validators.normalizePhone('926393329'), '+51926393329');
      expect(Validators.validatePhone('987 654 321'), isNull);
      // Debe tener 9 dígitos y empezar con 9.
      expect(Validators.validatePhone('98765432'), contains('9 dígitos'));
      expect(Validators.validatePhone('887654321'), contains('9 dígitos'));
      expect(Validators.validatePhone('9876543210'), contains('9 dígitos'));
      // Para mostrar en el campo junto al prefijo fijo.
      expect(Validators.localPhone('+51987654321'), '987654321');
      expect(Validators.localPhone('+15551234567'), '+15551234567');
      expect(Validators.localPhone(null), isEmpty);
    });

    test('operation-not-allowed en el SMS no culpa al correo', () {
      final error = FirebaseAuthException(code: 'operation-not-allowed');
      expect(AuthErrorMapper.phoneMessage(error), contains('SMS'));
      expect(AuthErrorMapper.phoneMessage(error), isNot(contains('correo')));
      expect(
        AuthErrorMapper.phoneMessage(
          FirebaseAuthException(code: 'invalid-verification-code'),
        ),
        contains('código no es correcto'),
      );
    });

    test('valida el código SMS de 6 dígitos', () {
      expect(Validators.validateSmsCode('123456'), isNull);
      expect(Validators.validateSmsCode(''), isNotNull);
      expect(Validators.validateSmsCode('12345'), isNotNull);
      expect(Validators.validateSmsCode('12a456'), isNotNull);
    });

    test('valida contraseñas', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('1234567'), isNotNull);
      expect(Validators.validatePassword('12345678'), isNull);
    });

    test('valida coincidencia de contraseñas', () {
      expect(
        Validators.validatePasswordMatch('12345678', '87654321'),
        isNotNull,
      );
      expect(Validators.validatePasswordMatch('12345678', '12345678'), isNull);
    });

    test('puntaje de seguridad', () {
      expect(Validators.passwordScore(''), 0);
      expect(Validators.passwordScore('Abc12345!'), greaterThanOrEqualTo(4));
    });
  });

  testWidgets('CustomButton muestra su etiqueta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomButton(label: 'Iniciar sesión', onPressed: _noop),
        ),
      ),
    );

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('CustomButton muestra loading y deshabilita', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomButton(label: 'Guardar', loading: true, onPressed: _noop),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
  });
}

void _noop() {}
