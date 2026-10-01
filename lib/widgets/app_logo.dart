import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 84,
    this.radius = 24,
    this.withText = true,
    this.textSize = 26,
  });

  final double size;
  final double radius;
  final bool withText;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryGradientEnd],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
        if (withText) ...[
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w900,
              color: context.palette.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
