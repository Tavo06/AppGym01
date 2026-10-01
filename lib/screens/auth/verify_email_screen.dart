import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/responsive.dart';
import '../../widgets/custom_button.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _sending = false;

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    final authProvider = context.read<AuthProvider>();
    try {
      final verified = await authProvider.checkEmailVerification();
      if (!mounted) return;
      if (verified) {
        // Un usuario recién registrado aún no tiene contraseña: vuelve al
        // Login, donde aparece el modal "Crear contraseña".
        if (authProvider.needsPasswordSetup) {
          context.go('/login');
          _showMessage(
            'Correo verificado. Ahora crea tu contraseña.',
            AppColors.success,
          );
        } else {
          context.go('/rutinas');
          _showMessage(
            'Correo verificado. ¡Bienvenido a FitProgress!',
            AppColors.success,
          );
        }
      } else {
        _showMessage(
          'Debes verificar tu correo electrónico antes de continuar.',
          AppColors.error,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(AuthErrorMapper.friendlyMessage(error), AppColors.error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _sending = true);
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.sendVerificationEmail();
      if (!mounted) return;
      _showMessage(
        'Te enviamos un nuevo correo de verificación.',
        AppColors.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(AuthErrorMapper.friendlyMessage(error), AppColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _goToLogin() async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.logout();
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      _showMessage(AuthErrorMapper.friendlyMessage(error), AppColors.error);
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    showAppMessage(
      context,
      message,
      type: color == AppColors.success
          ? FeedbackType.success
          : FeedbackType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final UserModel? profile = authProvider.profile;
    final email = authProvider.user?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: FormScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: context.palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verifica tu correo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hola ${profile?.name ?? authProvider.displayName},\n'
                'Enviamos un enlace de verificación a:\n$email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Abre tu bandeja de entrada y confirma tu correo '
                'para acceder a FitProgress.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Ya verifiqué mi correo',
                icon: Icons.verified_outlined,
                loading: _checking,
                onPressed: _checkVerification,
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Reenviar correo',
                icon: Icons.send_rounded,
                variant: ButtonVariant.secondary,
                loading: _sending,
                onPressed: _resendEmail,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _checking || _sending ? null : _goToLogin,
                // Esta acción cierra la sesión: el texto anterior decía
                // "Volver al inicio" pero en realidad salía de la cuenta.
                child: const Text('Usar otra cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
