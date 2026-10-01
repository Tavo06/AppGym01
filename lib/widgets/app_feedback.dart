import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../services/auth_service.dart';

/// Mensaje legible para cualquier error de Firebase (Auth o Firestore).
String friendlyError(Object error) {
  final auth = AuthErrorMapper.friendlyMessage(error);
  if (auth != AuthErrorMapper.genericMessage) return auth;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción.';
      case 'unavailable':
        return 'No hay conexión con el servidor. Revisa tu Internet.';
      default:
        return 'Error de Firebase (${error.code}).';
    }
  }
  return AuthErrorMapper.genericMessage;
}

enum FeedbackType { success, error, info }

/// Muestra un mensaje breve (SnackBar) con el color según su tipo.
void showAppMessage(
  BuildContext context,
  String message, {
  FeedbackType type = FeedbackType.error,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (Color? color, IconData icon) = switch (type) {
    FeedbackType.success => (AppColors.success, Icons.check_circle_rounded),
    FeedbackType.error => (AppColors.error, Icons.error_outline_rounded),
    FeedbackType.info => (null, Icons.info_outline_rounded),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        // En escritorio el mensaje no ocupa todo el ancho de la ventana.
        width: MediaQuery.sizeOf(context).width > 640 ? 480 : null,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}
