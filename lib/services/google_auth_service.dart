import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'app_firebase.dart';

class AuthCancelledException implements Exception {
  AuthCancelledException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleAuthService {
  /// Cliente OAuth de tipo web del proyecto (`client_type: 3` en
  /// `google-services.json`). Android lo necesita para emitir el `idToken`
  /// que Firebase Auth acepta.
  static const String _serverClientId =
      '996263447499-6mgel4v0l9fnra39sbdrnl02hctgctlr.apps.googleusercontent.com';

  static Future<void>? _initialization;

  /// Plataformas donde el inicio de sesión con Google funciona: web (con la
  /// ventana emergente de Firebase), Android e iOS. En Windows/Linux/macOS
  /// el plugin no tiene implementación, así que el botón no se muestra.
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// `google_sign_in` 7 exige llamar a `initialize()` exactamente una vez
  /// antes de cualquier otro método.
  Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance
        .initialize(serverClientId: _serverClientId)
        .catchError((Object error) {
          // Permite reintentar si la inicialización falló.
          _initialization = null;
          throw error;
        });
  }

  Future<UserCredential> signIn() async {
    // En web `GoogleSignIn.authenticate()` no está soportado: Firebase Auth
    // abre directamente la ventana emergente de Google.
    if (kIsWeb) return _signInWeb();
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw FirebaseAuthException(code: 'google-unsupported-platform');
    }

    final GoogleSignInAccount account;
    try {
      await _ensureInitialized();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw AuthCancelledException('Autenticación de Google cancelada.');
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw FirebaseAuthException(
          code: 'google-config-error',
          message: e.description,
        );
      }
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    return AppFirebase.auth.signInWithCredential(credential);
  }

  Future<UserCredential> _signInWeb() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      return await AppFirebase.auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'user-cancelled') {
        throw AuthCancelledException('Autenticación de Google cancelada.');
      }
      if (e.code == 'operation-not-allowed') {
        throw FirebaseAuthException(
          code: 'google-provider-disabled',
          message: e.message,
        );
      }
      rethrow;
    }
  }

  /// En web la sesión de Google la gestiona Firebase Auth, así que basta con
  /// `FirebaseAuth.signOut()`; `GoogleSignIn.signOut()` se quedaría colgado
  /// esperando un `initialize()` que nunca ocurre.
  Future<void> signOut() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}
