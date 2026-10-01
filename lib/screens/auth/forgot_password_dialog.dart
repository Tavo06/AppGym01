// Se oculta `AuthProvider` de firebase_auth para no colisionar con el
// `AuthProvider` de la aplicación.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_modal.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Modal "Recuperar contraseña", centrado sobre el Login. Tras enviar el
/// enlace muestra la confirmación dentro del mismo modal.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  /// Correo que el usuario ya escribió en el Login.
  final String initialEmail;

  /// Devuelve `true` si se envió el enlace.
  static Future<bool?> show(BuildContext context, {String initialEmail = ''}) =>
      showAuthModal<bool>(
        context,
        builder: (_) => ForgotPasswordDialog(initialEmail: initialEmail),
      );

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendPasswordReset(
        _emailController.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      // No se revela si el correo está registrado: se muestra la misma
      // confirmación neutral para no filtrar qué correos tienen cuenta.
      if (error.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(() => _error = AuthErrorMapper.friendlyMessage(error));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthErrorMapper.friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _close() => Navigator.of(context).pop(_sent);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _sent ? _buildSent() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return AuthModal(
      key: const ValueKey('form'),
      icon: Icons.lock_reset_rounded,
      title: 'Recuperar contraseña',
      subtitle:
          'Escribe el correo de tu cuenta y te enviaremos un enlace para '
          'restablecer tu contraseña.',
      onClose: _sending ? null : _close,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: CustomTextField(
              controller: _emailController,
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              validator: Validators.validateEmail,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendResetLink(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AuthModalError(_error!),
          ],
          const SizedBox(height: 22),
          CustomButton(
            label: 'Enviar enlace',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _sendResetLink,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _sending ? null : _close,
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return AuthModal(
      key: const ValueKey('sent'),
      icon: Icons.mark_email_read_outlined,
      title: 'Revisa tu correo',
      subtitle:
          'Si existe una cuenta asociada a ${_emailController.text.trim()}, '
          'recibirás instrucciones para recuperar tu contraseña.',
      onClose: _close,
      child: CustomButton(label: 'Entendido', onPressed: _close),
    );
  }
}
