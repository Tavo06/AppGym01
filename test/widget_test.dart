import 'package:fitprogress/core/utils/validators.dart';
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
