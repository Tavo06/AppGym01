import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Se espera un mínimo para que la animación se vea, pero la decisión de
    // navegación depende de que Firebase haya resuelto el estado real, no
    // de un temporizador que pudiera expirar antes de tiempo.
    Future.delayed(const Duration(milliseconds: 1200), () {
      _resolveNavigation();
    });
  }

  Future<void> _resolveNavigation() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.ready;
    if (!mounted) return;

    if (authProvider.status != AuthStatus.authenticated) {
      context.go('/login');
      return;
    }

    // `emailVerified` puede estar desactualizado en el dispositivo si el
    // usuario confirmó el enlace desde otro navegador, así que se
    // revalida contra el servidor antes de decidir.
    if (!authProvider.isEmailVerified) {
      try {
        await authProvider.checkEmailVerification();
      } catch (_) {
        // Si la revalidación falla se conserva el valor local.
      }
      if (!mounted) return;
    }

    context.go(authProvider.isEmailVerified ? '/rutinas' : '/verify-email');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.palette.background, context.palette.primarySoft],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 110),
              const SizedBox(height: 24),
              Text(
                AppConstants.appTagline,
                style: TextStyle(
                  fontSize: 15,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
