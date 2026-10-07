// Se oculta `AuthProvider` de firebase_auth para no colisionar con el
// `AuthProvider` de la aplicación.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_modal.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';

/// Modal "Crear cuenta", centrado sobre el Login.
///
/// Devuelve el [RegisterResult] si la cuenta se creó. Quien lo abre debe
/// navegar a `/verify-email` y luego llamar a
/// `AuthProvider.finishRegistration()`.
class RegisterDialog extends StatefulWidget {
  const RegisterDialog({super.key});

  static Future<RegisterResult?> show(BuildContext context) =>
      showAuthModal<RegisterResult>(
        context,
        builder: (_) => const RegisterDialog(),
      );

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailConfirmController = TextEditingController();
  final _phoneController = TextEditingController();
  // La fecha se muestra como texto real del campo y no como `hint`: el
  // `hint` solo se ve con el campo enfocado, por lo que la fecha parecía
  // borrarse al tocar otro campo. El valor real vive en `_birthDate`.
  final _birthDateController = TextEditingController();

  DateTime? _birthDate;
  String? _goal;
  String? _level;
  bool _registering = false;
  String? _error;

  bool get _phoneRequired => AuthService.phoneSupported;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailConfirmController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  String _formatBirthDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = _formatBirthDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _registering = true;
      _error = null;
    });
    final authProvider = context.read<AuthProvider>();
    try {
      final result = await authProvider.register(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        birthDate: _birthDate?.toIso8601String().split('T').first,
        goal: _goal,
        level: _level,
      );
      if (!mounted) {
        // Nadie recibirá el resultado: se libera el registro aquí para que
        // el router pueda llevar al usuario a verificar su correo.
        authProvider.finishRegistration();
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      // `register` ya liberó el estado de registro al fallar.
      if (!mounted) return;
      setState(() => _error = _registerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  String _registerErrorMessage(Object error) {
    final friendly = AuthErrorMapper.friendlyMessage(error);
    if (friendly != AuthErrorMapper.genericMessage) return friendly;
    if (error is FirebaseException) {
      return 'No se pudo crear la cuenta (${error.code}). '
              '${error.message ?? ''}'
          .trim();
    }
    return 'No se pudo crear la cuenta: $error';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No se puede cerrar mientras se crea la cuenta.
      canPop: !_registering,
      child: AuthModal(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Crear cuenta',
        subtitle: 'Completa tus datos para comenzar a entrenar.',
        maxWidth: 480,
        onClose: _registering ? null : () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthModalSection('Tus datos'),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Nombre completo',
                    hint: 'Ej: Ana García',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validators.validateRequired(
                      v,
                      message: 'Ingresa tu nombre completo.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    hint: 'tucorreo@ejemplo.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _emailConfirmController,
                    label: 'Confirmar correo electrónico',
                    hint: 'Repite tu correo',
                    icon: Icons.mark_email_read_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    validator: (v) =>
                        Validators.validateEmailMatch(_emailController.text, v),
                  ),
                  const SizedBox(height: 14),
                  // Obligatorio donde se puede verificar por SMS; en
                  // Windows es opcional y se verifica luego en móvil o web.
                  CustomTextField(
                    controller: _phoneController,
                    label: _phoneRequired ? 'Teléfono' : 'Teléfono (opcional)',
                    // Basta con los 9 dígitos: el código de país se añade
                    // solo (ver `Validators.normalizePhone`).
                    hint: '987 654 321',
                    prefixText: '${AppConstants.defaultPhoneCountryCode} ',
                    icon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    validator: (v) =>
                        Validators.validatePhone(v, required: _phoneRequired),
                  ),
                  const SizedBox(height: 22),
                  const AuthModalSection('Tu entrenamiento (opcional)'),
                  CustomTextField(
                    controller: _birthDateController,
                    label: 'Fecha de nacimiento (opcional)',
                    hint: 'Selecciona una fecha',
                    icon: Icons.cake_outlined,
                    readOnly: true,
                    onTap: _pickBirthDate,
                  ),
                  const SizedBox(height: 14),
                  CustomDropdown(
                    items: AppConstants.goals.toList(),
                    value: _goal,
                    label: 'Objetivo principal (opcional)',
                    icon: Icons.flag_outlined,
                    onChanged: (v) => setState(() => _goal = v),
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 14),
                  CustomDropdown(
                    items: AppConstants.levels.toList(),
                    value: _level,
                    label: 'Nivel (opcional)',
                    icon: Icons.trending_up_rounded,
                    onChanged: (v) => setState(() => _level = v),
                    validator: (_) => null,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthModalError(_error!),
            ],
            const SizedBox(height: 22),
            CustomButton(
              label: 'Crear cuenta',
              icon: Icons.person_add_alt_1_rounded,
              loading: _registering,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              _phoneRequired
                  ? 'Te enviaremos un correo y un SMS de verificación. '
                        'Cuando confirmes ambos, crearás tu contraseña.'
                  : 'Te enviaremos un correo de verificación. Cuando lo '
                        'confirmes, crearás tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.palette.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
