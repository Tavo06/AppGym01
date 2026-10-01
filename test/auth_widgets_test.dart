import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitprogress/core/theme/app_theme.dart';
import 'package:fitprogress/screens/auth/register_dialog.dart';
import 'package:fitprogress/widgets/create_password_dialog.dart';
import 'package:fitprogress/widgets/custom_dropdown.dart';
import 'package:fitprogress/widgets/error_state.dart';
import 'package:fitprogress/widgets/progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

String _textOf(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    )
    .controller
    .text;

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  group('Registro', () {
    testWidgets('la fecha persiste al cambiar de campo y no hay contraseña '
        'temporal', (tester) async {
      _useTallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => RegisterDialog.show(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      // Es un modal centrado, no una página.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Crear cuenta'), findsWidgets);
      expect(find.text('Nivel (opcional)'), findsOneWidget);
      expect(find.textContaining('contraseña temporal'), findsNothing);

      await tester.tap(_field('Fecha de nacimiento (opcional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final expected = '01/01/${DateTime.now().year - 25}';
      expect(_textOf(tester, 'Fecha de nacimiento (opcional)'), expected);

      await tester.tap(_field('Nombre completo'));
      await tester.enterText(_field('Nombre completo'), 'Ana');
      await tester.enterText(_field('Correo electrónico'), 'ana@x.com');
      await tester.pumpAndSettle();
      expect(_textOf(tester, 'Fecha de nacimiento (opcional)'), expected);
    });
  });

  group('Modal "Crear contraseña"', () {
    Future<List<Object?>> pumpDialog(
      WidgetTester tester,
      Future<void> Function(String) onCreate,
    ) async {
      _useTallView(tester);
      final results = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await CreatePasswordDialog.show(
                      context,
                      email: 'ana@x.com',
                      onCreate: onCreate,
                      onSendLink: () async {},
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return results;
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.widgetWithText(FilledButton, 'Crear contraseña');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('valida vacíos y coincidencia, y crea la contraseña', (
      tester,
    ) async {
      String? created;
      final results = await pumpDialog(tester, (p) async => created = p);
      expect(find.textContaining('ana@x.com'), findsOneWidget);

      await submit(tester);
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
      expect(find.text('Confirma tu contraseña.'), findsOneWidget);

      await tester.enterText(_field('Nueva contraseña'), 'Segura123!');
      await tester.enterText(_field('Confirmar contraseña'), 'Otra123!!');
      await submit(tester);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(created, isNull);

      await tester.enterText(_field('Confirmar contraseña'), 'Segura123!');
      await submit(tester);
      expect(created, 'Segura123!');
      expect(find.byType(CreatePasswordDialog), findsNothing);
      expect(results, [CreatePasswordOutcome.created]);
    });

    testWidgets('si Firebase pide un inicio reciente ofrece el enlace', (
      tester,
    ) async {
      await pumpDialog(tester, (p) async {
        throw FirebaseAuthException(code: 'requires-recent-login');
      });
      await tester.enterText(_field('Nueva contraseña'), 'Segura123!');
      await tester.enterText(_field('Confirmar contraseña'), 'Segura123!');
      await submit(tester);
      expect(find.byType(CreatePasswordDialog), findsOneWidget);
      expect(find.text('Enviar enlace a mi correo'), findsOneWidget);
    });

    testWidgets('muestra el error de contraseña débil', (tester) async {
      await pumpDialog(tester, (p) async {
        throw FirebaseAuthException(code: 'weak-password');
      });
      await tester.enterText(_field('Nueva contraseña'), 'Segura123!');
      await tester.enterText(_field('Confirmar contraseña'), 'Segura123!');
      await submit(tester);
      expect(find.text('La contraseña es demasiado débil.'), findsOneWidget);
    });
  });

  group('CustomDropdown', () {
    testWidgets('muestra el valor guardado y permite cambiarlo', (
      tester,
    ) async {
      const items = ['Sin especificar', 'Fuerza', 'Resistencia'];
      String? value = 'Fuerza';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CustomDropdown(
                items: items,
                value: value,
                label: 'Objetivo',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      // El valor guardado se ve (antes se excluía de la lista).
      expect(find.text('Fuerza'), findsOneWidget);

      await tester.tap(find.text('Fuerza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resistencia').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(value, 'Resistencia');
      expect(find.text('Resistencia'), findsOneWidget);
    });
  });

  group('Estados y tema oscuro', () {
    testWidgets('ErrorState muestra el mensaje y reintenta', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorState(message: 'Sin conexión', onRetry: () => retries++),
          ),
        ),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);
    });

    testWidgets('ProgressCard usa los colores del tema oscuro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ProgressCard(
              icon: Icons.fitness_center,
              value: '12',
              label: 'Entrenamientos',
            ),
          ),
        ),
      );
      final value = tester.widget<Text>(find.text('12'));
      expect(value.style?.color, AppPalette.dark.textPrimary);
    });
  });
}
