import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/validators.dart';
import '../services/auth_service.dart';
import 'custom_button.dart';
import 'custom_text_field.dart';

enum CreatePasswordOutcome { created, linkSent }

/// Modal que aparece sobre el Login para que un usuario con el correo ya
/// verificado cree su contraseña definitiva.
class CreatePasswordDialog extends StatefulWidget {
  const CreatePasswordDialog({
    super.key,
    required this.email,
    required this.onCreate,
    required this.onSendLink,
  });

  final String email;
  final Future<void> Function(String password) onCreate;
  final Future<void> Function() onSendLink;

  static Future<CreatePasswordOutcome?> show(
    BuildContext context, {
    required String email,
    required Future<void> Function(String password) onCreate,
    required Future<void> Function() onSendLink,
  }) {
    return showDialog<CreatePasswordOutcome>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => CreatePasswordDialog(
        email: email,
        onCreate: onCreate,
        onSendLink: onSendLink,
      ),
    );
  }

  @override
  State<CreatePasswordDialog> createState() => _CreatePasswordDialogState();
}

class _CreatePasswordDialogState extends State<CreatePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _needsLink = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    try {
      await widget.onCreate(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(CreatePasswordOutcome.created);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'requires-recent-login') {
          _needsLink = true;
          _error =
              'Por seguridad, Firebase necesita confirmar tu identidad. '
              'Te enviaremos un enlace a tu correo para crear la contraseña.';
        } else {
          _error = _messageFor(error);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear la contraseña: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendLink() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSendLink();
      if (!mounted) return;
      Navigator.of(context).pop(CreatePasswordOutcome.linkSent);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(Object error) {
    final friendly = AuthErrorMapper.friendlyMessage(error);
    if (friendly != AuthErrorMapper.genericMessage) return friendly;
    if (error is FirebaseAuthException) {
      return 'No se pudo crear la contraseña (${error.code}).';
    }
    return friendly;
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;
    final strength = PasswordStrength.of(password);
    final longEnough = password.length >= 8;
    final matches = password.isNotEmpty && password == _confirmController.text;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: context.palette.surface,
        elevation: 16,
        shadowColor: context.palette.secondary.withValues(alpha: 0.35),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: context.palette.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Crear contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu correo ${widget.email} ya está verificado. Crea la '
                    'contraseña con la que iniciarás sesión.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Nueva contraseña',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    showObscureToggle: true,
                    validator: Validators.validatePassword,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (password.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: strength.score / 4,
                        minHeight: 6,
                        backgroundColor: context.palette.surfaceMuted,
                        color: strength.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Seguridad: ${strength.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: strength.color,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _confirmController,
                    label: 'Confirmar contraseña',
                    icon: Icons.lock_rounded,
                    obscure: true,
                    showObscureToggle: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirma tu contraseña.';
                      }
                      return Validators.validatePasswordMatch(
                        _passwordController.text,
                        v,
                      );
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _Requirement(met: longEnough, text: 'Al menos 8 caracteres'),
                  const SizedBox(height: 6),
                  _Requirement(
                    met: matches,
                    text: 'Ambas contraseñas coinciden',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recomendado: combina mayúsculas, minúsculas, números y '
                    'símbolos.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_needsLink)
                    CustomButton(
                      label: 'Enviar enlace a mi correo',
                      icon: Icons.mark_email_read_outlined,
                      loading: _saving,
                      onPressed: _sendLink,
                    )
                  else
                    CustomButton(
                      label: 'Crear contraseña',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _submit,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.text});

  final bool met;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : context.palette.textSecondary;
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: met ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
