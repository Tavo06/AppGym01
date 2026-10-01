import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'custom_button.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.showCancel = true,
    this.destructive = false,
    this.onConfirm,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool showCancel;
  final bool destructive;
  final VoidCallback? onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool showCancel = true,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: showCancel,
      builder: (dialogContext) => ConfirmationDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        showCancel: showCancel,
        destructive: destructive,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
  }

  static Future<void> showInfo(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String buttonLabel = 'Entendido',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: buttonLabel,
        showCancel: false,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.error : AppColors.success;
    return Dialog(
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
                color:
                    (destructive
                            ? AppColors.error
                            : context.palette.primarySoft)
                        .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            if (showCancel) ...[
              CustomButton(label: confirmLabel, onPressed: onConfirm),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: context.palette.textSecondary,
                  ),
                  child: Text(cancelLabel),
                ),
              ),
            ] else
              CustomButton(label: confirmLabel, onPressed: onConfirm),
          ],
        ),
      ),
    );
  }
}
