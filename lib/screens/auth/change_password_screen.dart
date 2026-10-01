import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/responsive.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AuthErrorMapper.friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: context.palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Contraseña actualizada correctamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A partir de ahora usa tu nueva contraseña para iniciar '
                'sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Listo',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.of(_newController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: FormScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Utiliza al menos 8 caracteres con mayúsculas, minúsculas '
                'y números para una contraseña segura.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _currentController,
                      label: 'Contraseña actual',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      showObscureToggle: true,
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _newController,
                      label: 'Nueva contraseña',
                      icon: Icons.lock_reset_rounded,
                      obscure: true,
                      showObscureToggle: true,
                      validator: Validators.validatePassword,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (_newController.text.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: strength.score / 4,
                          minHeight: 8,
                          backgroundColor: context.palette.surfaceMuted,
                          color: strength.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Seguridad: ${strength.label}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: strength.color,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmController,
                      label: 'Confirmar nueva contraseña',
                      icon: Icons.lock_rounded,
                      obscure: true,
                      showObscureToggle: true,
                      validator: (v) => Validators.validatePasswordMatch(
                        _newController.text,
                        v,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              CustomButton(
                label: 'Cambiar contraseña',
                icon: Icons.https_outlined,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
