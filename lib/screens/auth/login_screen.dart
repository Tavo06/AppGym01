import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/create_password_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'forgot_password_dialog.dart';
import 'register_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordDialogOpen = false;

  // Tras el primer intento, los errores se actualizan mientras se escribe.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // El correo del registro llega ya escrito; el usuario puede cambiarlo.
    final email = context.read<AuthProvider>().loginEmail;
    if (email != null) _emailController.text = email;
  }

  /// Abre el modal "Crear contraseña" sobre el Login cuando el usuario ya
  /// verificó su correo pero aún no tiene contraseña definitiva.
  void _maybeShowCreatePassword(AuthProvider authProvider) {
    if (_passwordDialogOpen || !authProvider.needsPasswordSetup) return;
    _passwordDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final email = authProvider.user?.email ?? '';
      if (email.isNotEmpty) _emailController.text = email;
      final outcome = await CreatePasswordDialog.show(
        context,
        email: email,
        onCreate: authProvider.createPassword,
        onSendLink: authProvider.sendPasswordSetupLink,
      );
      _passwordDialogOpen = false;
      if (!mounted) return;
      _passwordController.clear();
      if (email.isNotEmpty) _emailController.text = email;
      if (outcome == CreatePasswordOutcome.created) {
        _showMessage(
          'Contraseña creada. Ingresa tu contraseña para iniciar sesión.',
          AppColors.success,
        );
      } else if (outcome == CreatePasswordOutcome.linkSent) {
        _showMessage(
          'Te enviamos un enlace a $email para crear tu contraseña. '
          'Luego inicia sesión aquí.',
          AppColors.success,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_submitted) setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _showMessage('Bienvenido a ${AppConstants.appName}', AppColors.success);
      // La redirección real la aplica el router: si el correo no está
      // verificado, `/home` rebota a `/verify-email` por sí sola.
      context.go('/hoy');
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error), AppColors.error);
    }
  }

  Future<void> _loginWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.loginWithGoogle();
      if (!mounted) return;
      context.go('/hoy');
    } on AuthCancelledException {
      // El usuario canceló el diálogo de Google.
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error), AppColors.error);
    }
  }

  /// Abre el modal "Crear cuenta". Si se creó la cuenta, lleva a verificar
  /// el correo y recién entonces libera el estado de registro (hasta ese
  /// momento el router mantiene al usuario en el Login).
  Future<void> _openRegister() async {
    final authProvider = context.read<AuthProvider>();
    final result = await RegisterDialog.show(context);
    if (result == null) return;
    if (!mounted) {
      authProvider.finishRegistration();
      return;
    }
    context.go('/verify-email');
    if (result.profileError != null) {
      _showMessage(
        'Tu cuenta se creó, pero no se pudieron guardar tus datos de '
        'perfil: ${result.profileError}',
        AppColors.error,
      );
    } else {
      _showMessage(
        'Cuenta creada. Revisa tu correo para verificarla.',
        AppColors.success,
      );
    }
    authProvider.finishRegistration();
  }

  /// Abre el modal "Recuperar contraseña" con el correo ya escrito.
  Future<void> _openForgotPassword() =>
      ForgotPasswordDialog.show(context, initialEmail: _emailController.text);

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
    final loading = authProvider.processing;
    _maybeShowCreatePassword(authProvider);

    return Scaffold(
      // Imagen de fondo a pantalla completa con el formulario encima, en una
      // tarjeta translúcida centrada y desplazable (el teclado no tapa los
      // campos).
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LoginBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final vertical = compact ? 16.0 : 32.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 24,
                    vertical: vertical,
                  ),
                  child: ConstrainedBox(
                    // Centra la tarjeta en vertical cuando cabe entera.
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - vertical * 2,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.form - 100,
                        ),
                        child: _LoginCard(
                          compact: compact,
                          child: _buildForm(context, loading),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Contenido del Login (logo, campos y acciones), sin cambios de lógica.
  Widget _buildForm(BuildContext context, bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        const AppLogo(size: 90),
        const SizedBox(height: 8),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        const SizedBox(height: 28),
        Text(
          'Iniciar sesión',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 22),
        Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              CustomTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                hint: 'tucorreo@ejemplo.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                validator: Validators.validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                showObscureToggle: true,
                // Solo se exige que no esté vacía: Firebase admite
                // contraseñas de 6 caracteres y la validación de longitud
                // impedía entrar a esas cuentas.
                validator: (v) => Validators.validateRequired(
                  v,
                  message: 'Ingresa tu contraseña.',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitLogin(),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : _openForgotPassword,
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ),
        const SizedBox(height: 8),
        CustomButton(
          label: 'Iniciar sesión',
          icon: Icons.login_rounded,
          loading: loading,
          onPressed: _submitLogin,
        ),
        if (GoogleAuthService.isSupported) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'o continúa con',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: loading ? null : _loginWithGoogle,
            icon: const _GoogleG(),
            label: const Text('Continuar con Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: context.palette.surface,
              side: BorderSide(color: context.palette.border),
              foregroundColor: context.palette.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        // `Wrap` para que no se desborde con texto grande (accesibilidad).
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '¿No tienes una cuenta? ',
              style: TextStyle(color: context.palette.textSecondary),
            ),
            GestureDetector(
              onTap: loading ? null : _openRegister,
              child: Text(
                'Regístrate',
                style: TextStyle(
                  color: context.palette.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fondo del Login: `lib/img/fondo.png` cubriendo toda la pantalla (sin
/// deformarse) y un degradado sutil para que el formulario se lea bien. En
/// tema oscuro el degradado es algo más intenso.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  static const String asset = 'lib/img/fondo.png';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          // Si la imagen no se pudiera cargar, queda el fondo del tema.
          errorBuilder: (context, _, _) =>
              ColoredBox(color: context.palette.background),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                Colors.black.withValues(alpha: dark ? 0.6 : 0.35),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta translúcida con desenfoque que contiene el formulario.
class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 30,
              compact ? 24 : 30,
              compact ? 20 : 30,
              compact ? 20 : 26,
            ),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: dark ? 0.86 : 0.92),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.08 : 0.5),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.googleBlue,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
