import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, text }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final SizedBox iconChild = icon == null
        ? const SizedBox.shrink()
        : SizedBox(width: 22, child: Icon(icon, size: 20));

    final filled =
        variant == ButtonVariant.primary || variant == ButtonVariant.secondary;
    final Widget child = loading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              // Blanco sobre botones rellenos; naranja sobre los de borde o
              // texto, donde el blanco era invisible.
              color: filled ? Colors.white : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[iconChild, const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    ButtonStyle? style;
    switch (variant) {
      case ButtonVariant.primary:
        style = null;
      case ButtonVariant.secondary:
        style = FilledButton.styleFrom(
          backgroundColor: context.palette.secondaryContainer,
        );
      case ButtonVariant.outline:
        style = OutlinedButton.styleFrom();
      case ButtonVariant.text:
        style = TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );
    }

    if (!expanded) {
      switch (variant) {
        case ButtonVariant.text:
          return TextButton(
            onPressed: disabled ? null : onPressed,
            child: child,
          );
        case ButtonVariant.outline:
          return OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: style,
            child: child,
          );
        default:
          return FilledButton(
            onPressed: disabled ? null : onPressed,
            style: style,
            child: child,
          );
      }
    }

    switch (variant) {
      case ButtonVariant.text:
        return SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: disabled ? null : onPressed,
            child: child,
          ),
        );
      case ButtonVariant.outline:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: style,
            child: child,
          ),
        );
      default:
        return FilledButton(
          onPressed: disabled ? null : onPressed,
          style: style,
          child: child,
        );
    }
  }
}
