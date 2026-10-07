import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/auth_modal.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/responsive.dart';
import '../../widgets/custom_button.dart';

/// Verificación de la cuenta (`/verify-email`).
///
/// Siempre pide confirmar el correo. Si la cuenta debe verificar también su
/// teléfono (`AuthProvider.requiresPhoneVerification`), muestra dos tarjetas
/// —correo y teléfono— que se pueden completar en cualquier orden; cuando
/// ambas están listas el router pasa al modal "Crear contraseña".
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app (por ejemplo, desde Gmail tras abrir el enlace) se
  /// comprueba sola la verificación, sin tener que pulsar el botón.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerification(silent: true);
    }
  }

  /// Con [silent] (comprobación automática) no se avisa si el correo aún no
  /// está verificado ni si falla la consulta.
  Future<void> _checkVerification({bool silent = false}) async {
    if (_checking) return;
    final authProvider = context.read<AuthProvider>();
    if (silent && authProvider.isEmailVerified) return;
    setState(() => _checking = true);
    try {
      final verified = await authProvider.checkEmailVerification();
      if (!mounted) return;
      if (verified) {
        _continueIfVerified(
          authProvider,
          done: 'Correo verificado.',
          pending: 'Correo verificado. Ahora verifica tu teléfono.',
        );
      } else if (!silent) {
        _showMessage(
          'Tu correo aún no figura como verificado. Abre el enlace del '
          'correo más reciente que te enviamos y vuelve a intentarlo.',
          AppColors.error,
        );
      }
    } catch (error) {
      if (!mounted || silent) return;
      _showMessage(AuthErrorMapper.friendlyMessage(error), AppColors.error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Lleva al paso siguiente si la cuenta ya está verificada por completo;
  /// si aún falta una verificación, se queda en esta pantalla.
  void _continueIfVerified(
    AuthProvider authProvider, {
    required String done,
    required String pending,
  }) {
    if (!authProvider.isAccountVerified) {
      _showMessage(pending, AppColors.success);
      return;
    }
    // Un usuario recién registrado aún no tiene contraseña: vuelve al
    // Login, donde aparece el modal "Crear contraseña".
    if (authProvider.needsPasswordSetup) {
      context.go('/login');
      _showMessage('$done Ahora crea tu contraseña.', AppColors.success);
    } else {
      context.go('/hoy');
      _showMessage(
        '$done ¡Bienvenido a ${AppConstants.appName}!',
        AppColors.success,
      );
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
    final requiresPhone = authProvider.requiresPhoneVerification;
    final name = profile?.name ?? authProvider.displayName;

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
                child: Icon(
                  requiresPhone
                      ? Icons.verified_user_outlined
                      : Icons.mark_email_unread_outlined,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                requiresPhone ? 'Verifica tu cuenta' : 'Verifica tu correo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (requiresPhone)
                _Paragraph(
                  'Hola $name,\nconfirma tu correo y tu teléfono para '
                  'acceder a ${AppConstants.appName}. Puedes hacerlo en cualquier orden.',
                )
              else ...[
                _Paragraph(
                  'Hola $name,\n'
                  'Enviamos un enlace de verificación a:\n$email',
                ),
                const SizedBox(height: 8),
                const _Paragraph(
                  'Abre tu bandeja de entrada y confirma tu correo '
                  'para acceder a ${AppConstants.appName}.',
                  fontSize: 14,
                ),
              ],
              const SizedBox(height: 32),
              if (requiresPhone) ...[
                _VerificationCard(
                  icon: Icons.alternate_email_rounded,
                  title: 'Correo electrónico',
                  detail: email,
                  verified: authProvider.isEmailVerified,
                  child: authProvider.isEmailVerified
                      ? null
                      : _emailActions(
                          hint:
                              'Abre el enlace que enviamos a tu bandeja '
                              'de entrada.',
                        ),
                ),
                const SizedBox(height: 16),
                const _PhoneVerificationCard(),
              ] else
                _emailActions(),
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

  Widget _emailActions({String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null) ...[
          _Paragraph(hint, fontSize: 13.5, align: TextAlign.start),
          const SizedBox(height: 14),
        ],
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
      ],
    );
  }
}

/// Tarjeta "Teléfono": pide el código SMS y lo confirma, vinculando el
/// número a la cuenta actual.
class _PhoneVerificationCard extends StatefulWidget {
  const _PhoneVerificationCard();

  @override
  State<_PhoneVerificationCard> createState() => _PhoneVerificationCardState();
}

class _PhoneVerificationCardState extends State<_PhoneVerificationCard> {
  static const int _resendSeconds = 60;

  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  final _codeController = TextEditingController();

  PhoneCodeRequest? _request;
  String? _sentTo;
  bool _sending = false;
  bool _confirming = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      // Solo los 9 dígitos: el `+51` va como prefijo fijo del campo.
      text: Validators.localPhone(context.read<AuthProvider>().profile?.phone),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_phoneFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final phone = Validators.normalizePhone(
      resend ? _sentTo : _phoneController.text,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    final authProvider = context.read<AuthProvider>();
    try {
      final request = await authProvider.sendPhoneCode(
        phone,
        resendToken: resend ? _request?.resendToken : null,
      );
      if (!mounted) return;
      if (request.autoVerified) {
        _onVerified(authProvider);
        return;
      }
      setState(() {
        _request = request;
        _sentTo = phone;
        _codeController.clear();
      });
      _startCooldown();
      showAppMessage(
        context,
        'Te enviamos un código por SMS.',
        type: FeedbackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthErrorMapper.phoneMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _confirming = true;
      _error = null;
    });
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.confirmPhoneCode(
        verificationId: _request?.verificationId,
        smsCode: _codeController.text,
      );
      if (!mounted) return;
      _onVerified(authProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthErrorMapper.phoneMessage(error));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _onVerified(AuthProvider authProvider) {
    _timer?.cancel();
    if (!authProvider.isAccountVerified) {
      showAppMessage(
        context,
        'Teléfono verificado. Falta confirmar tu correo.',
        type: FeedbackType.success,
      );
      return;
    }
    if (authProvider.needsPasswordSetup) {
      context.go('/login');
      showAppMessage(
        context,
        'Teléfono verificado. Ahora crea tu contraseña.',
        type: FeedbackType.success,
      );
    } else {
      context.go('/hoy');
      showAppMessage(
        context,
        'Teléfono verificado. ¡Bienvenido a ${AppConstants.appName}!',
        type: FeedbackType.success,
      );
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _request = null;
      _cooldown = 0;
      _error = null;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final verified = authProvider.isPhoneVerified;
    final busy = _sending || _confirming;
    final codeSent = _request != null;

    return _VerificationCard(
      icon: Icons.phone_iphone_rounded,
      title: 'Teléfono',
      detail: verified
          ? (authProvider.user?.phoneNumber ?? authProvider.profile?.phone)
          : (codeSent ? _sentTo : null),
      verified: verified,
      child: verified
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!codeSent)
                  Form(
                    key: _phoneFormKey,
                    child: CustomTextField(
                      controller: _phoneController,
                      label: 'Teléfono',
                      hint: '987 654 321',
                      prefixText: '${AppConstants.defaultPhoneCountryCode} ',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                      onSubmitted: (_) => _sendCode(),
                    ),
                  )
                else ...[
                  _Paragraph(
                    'Escribe el código de 6 dígitos que enviamos por SMS.',
                    fontSize: 13.5,
                    align: TextAlign.start,
                  ),
                  const SizedBox(height: 14),
                  Form(
                    key: _codeFormKey,
                    child: CustomTextField(
                      controller: _codeController,
                      label: 'Código SMS',
                      hint: '123456',
                      icon: Icons.sms_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      validator: Validators.validateSmsCode,
                      onSubmitted: (_) => _confirmCode(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AuthModalError(_error!),
                ],
                const SizedBox(height: 14),
                if (!codeSent)
                  CustomButton(
                    label: 'Enviar código',
                    icon: Icons.sms_rounded,
                    loading: _sending,
                    onPressed: _sendCode,
                  )
                else ...[
                  CustomButton(
                    label: 'Verificar teléfono',
                    icon: Icons.verified_outlined,
                    loading: _confirming,
                    onPressed: _confirmCode,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: busy ? null : _changeNumber,
                        child: const Text('Cambiar número'),
                      ),
                      TextButton(
                        onPressed: busy || _cooldown > 0
                            ? null
                            : () => _sendCode(resend: true),
                        child: Text(
                          _cooldown > 0
                              ? 'Reenviar en $_cooldown s'
                              : 'Reenviar código',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Tarjeta de un paso de verificación con su estado (pendiente/verificado).
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.icon,
    required this.title,
    required this.verified,
    this.detail,
    this.child,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final bool verified;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final statusColor = verified ? AppColors.success : AppColors.amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (detail != null && detail!.isNotEmpty)
                        Text(
                          detail!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        verified
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        size: 15,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        verified ? 'Verificado' : 'Pendiente',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 16), child!],
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(
    this.text, {
    this.fontSize = 15,
    this.align = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.5,
        color: context.palette.textSecondary,
      ),
    );
  }
}
