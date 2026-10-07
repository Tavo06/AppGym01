import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'google_auth_service.dart';
import 'app_firebase.dart';

class RegisterResult {
  const RegisterResult({
    required this.user,
    required this.setupSecret,
    this.profileError,
  });

  final User user;

  /// Clave interna aleatoria con la que Firebase exige crear la cuenta. Nunca
  /// se muestra ni se persiste: solo vive en memoria para reautenticar al
  /// usuario cuando crea su contraseña real, y luego se descarta.
  final String setupSecret;

  /// Motivo por el que no se pudo guardar `users/{uid}` en Firestore.
  /// La cuenta de Authentication existe igualmente.
  final String? profileError;

  RegisterResult withProfileError(String? error) =>
      RegisterResult(user: user, setupSecret: setupSecret, profileError: error);
}

/// Resultado de pedir el código SMS para vincular un teléfono.
class PhoneCodeRequest {
  const PhoneCodeRequest({
    this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  /// Identificador con el que se confirma el código (móvil). En web es
  /// `null`: la confirmación la guarda el propio [AuthService].
  final String? verificationId;

  /// Permite reenviar el SMS sin volver a pasar el control anti-abuso.
  final int? resendToken;

  /// `true` si Android leyó el SMS solo y el teléfono ya quedó vinculado.
  final bool autoVerified;
}

class AuthService {
  final FirebaseAuth _auth = AppFirebase.auth;

  /// Confirmación pendiente de `linkWithPhoneNumber` (solo web).
  ConfirmationResult? _webPhoneLink;

  /// Firebase Auth solo verifica teléfonos en Android, iOS y web (en web,
  /// con reCAPTCHA invisible). En Windows no está disponible.
  static bool get phoneSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String _generateSetupSecret() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        '0123456789!@#%^&*-_';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<RegisterResult> registerWithEmail({
    required String name,
    required String email,
  }) async {
    final setupSecret = _generateSetupSecret();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: setupSecret,
    );
    // La cuenta ya existe en este punto: el resultado se arma ANTES de los
    // pasos opcionales para que un fallo en ellos no impida continuar.
    final result = RegisterResult(
      user: credential.user!,
      setupSecret: setupSecret,
    );
    try {
      await credential.user?.updateDisplayName(name);
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      debugPrint('Registro parcial, pasos posteriores fallaron: ${error.code}');
    }
    return result;
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() {
    return GoogleAuthService().signIn();
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  /// Envía un SMS para VINCULAR [phone] a la cuenta con sesión. No inicia
  /// sesión con el teléfono: eso crearía una segunda cuenta con otro `uid`.
  Future<PhoneCodeRequest> startPhoneLink(
    String phone, {
    int? resendToken,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay una sesión activa.',
      );
    }
    if (kIsWeb) {
      _webPhoneLink = await user.linkWithPhoneNumber(phone);
      return const PhoneCodeRequest();
    }
    final completer = Completer<PhoneCodeRequest>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android leyó el SMS por su cuenta: se vincula directamente.
        try {
          await user.linkWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(const PhoneCodeRequest(autoVerified: true));
          }
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, token) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneCodeRequest(
              verificationId: verificationId,
              resendToken: token,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// Confirma el código SMS y vincula el teléfono a la cuenta actual.
  Future<void> confirmPhoneLink({
    String? verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay una sesión activa.',
      );
    }
    if (kIsWeb) {
      final pending = _webPhoneLink;
      if (pending == null) {
        throw FirebaseAuthException(code: 'session-expired', message: '');
      }
      await pending.confirm(smsCode);
      _webPhoneLink = null;
      return;
    }
    if (verificationId == null) {
      throw FirebaseAuthException(code: 'session-expired', message: '');
    }
    await user.linkWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      ),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() async {
    final usedGoogle =
        _auth.currentUser?.providerData.any(
          (p) => p.providerId == 'google.com',
        ) ??
        false;
    // Firebase se cierra PRIMERO: en web, `GoogleSignIn.signOut()` espera un
    // `initialize()` que nunca ocurre y se quedaba colgado para siempre,
    // de modo que la sesión de Firebase jamás llegaba a cerrarse.
    await _auth.signOut();
    if (!usedGoogle) return;
    try {
      await GoogleAuthService().signOut().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Si Google no está disponible no debe afectar el cierre de sesión.
    }
  }

  Future<User> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found', message: '');
    }
    await user.reload();
    return _auth.currentUser!;
  }

  /// Vuelve a leer el usuario y dice si su correo está verificado.
  ///
  /// `reload()` no siempre actualiza `emailVerified` (en escritorio, por
  /// ejemplo, el usuario seguía "sin verificar" después de abrir el enlace
  /// del correo). Si no lo hace, se renueva el token: su claim
  /// `email_verified` lo emite el servidor y sí refleja la verificación.
  Future<({User user, bool emailVerified})> reloadEmailVerification() async {
    final user = await reloadUser();
    if (user.emailVerified) return (user: user, emailVerified: true);
    try {
      final token = await user.getIdTokenResult(true);
      final claim = token.claims?['email_verified'] == true;
      // Con el token renovado, una segunda recarga suele traer ya el dato.
      if (claim) await user.reload();
      final fresh = _auth.currentUser ?? user;
      return (user: fresh, emailVerified: fresh.emailVerified || claim);
    } catch (error) {
      debugPrint('No se pudo renovar el token: $error');
      return (user: user, emailVerified: false);
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
    }
    await reloadUser();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No hay una sesión activa.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email ?? '',
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Establece la contraseña definitiva de un usuario recién verificado.
  ///
  /// `updatePassword` exige un inicio de sesión reciente: si se conoce la
  /// clave interna del registro se reautentica con ella antes; si no (la app
  /// se reinició), Firebase puede responder `requires-recent-login`.
  Future<void> setInitialPassword({
    required String newPassword,
    String? setupSecret,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay una sesión activa.',
      );
    }
    if (setupSecret != null) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email ?? '',
          password: setupSecret,
        ),
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<String> getProviderId() async {
    final user = _auth.currentUser;
    if (user == null) return 'email';
    final providerInfo = user.providerData
        .where((p) => p.providerId != 'firebase')
        .toList();
    if (providerInfo.isNotEmpty) {
      return providerInfo.first.providerId == 'google.com'
          ? 'google'
          : providerInfo.first.providerId;
    }
    return 'email';
  }
}

class AuthErrorMapper {
  AuthErrorMapper._();

  static const String genericMessage = 'Ocurrió un error. Intenta nuevamente.';

  /// Mensaje para los errores al enviar o confirmar el código SMS. Algunos
  /// códigos significan otra cosa que en el registro con correo: por
  /// ejemplo, `operation-not-allowed` al enviar un SMS indica que la región
  /// del número no está permitida (o que el proveedor Teléfono está
  /// desactivado), no que falte el método de correo y contraseña.
  static String phoneMessage(Object? error) {
    if (error is FirebaseAuthException) {
      debugPrint(
        'Error de verificación por SMS: ${error.code} ${error.message}',
      );
      switch (error.code) {
        case 'operation-not-allowed':
          return 'Firebase no permite enviar SMS a este número. Revisa que '
              'el proveedor Teléfono esté habilitado y que la región del '
              'número esté permitida (Authentication > Configuración > '
              'Política de la región de SMS).';
        case 'too-many-requests':
          return 'Demasiados intentos con este número. Espera unos minutos '
              'e inténtalo de nuevo.';
        case 'billing-not-enabled':
          return 'El envío de SMS requiere que el proyecto de Firebase tenga '
              'la facturación activada (plan Blaze).';
      }
      final friendly = friendlyMessage(error);
      if (friendly != genericMessage) return friendly;
      return 'No se pudo verificar el teléfono (${error.code}).';
    }
    return friendlyMessage(error);
  }

  static String friendlyMessage(Object? error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'password-does-not-meet-requirements':
          return 'La contraseña no cumple la política de contraseñas '
              'configurada en Firebase.';
        case 'operation-not-allowed':
          return 'El registro con correo y contraseña no está habilitado '
              'en Firebase (Authentication > Sign-in method).';
        case 'email-already-in-use':
          return 'Este correo ya está registrado.';
        case 'invalid-email':
          return 'Ingresa un correo válido.';
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
        case 'auth/invalid-credential':
          return 'El correo o la contraseña son incorrectos.';
        case 'user-not-found':
          return 'No se pudo iniciar sesión con los datos proporcionados.';
        case 'user-disabled':
          return 'Tu cuenta fue deshabilitada. Contacta al soporte.';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde.';
        case 'network-request-failed':
          return 'No hay conexión a Internet.';
        case 'requires-recent-login':
          return 'Vuelve a iniciar sesión para continuar.';
        case 'user-cancelled':
          return 'Inicio de sesión cancelado.';
        case 'no-current-user':
          return 'No hay una sesión activa.';
        case 'provider-already-linked':
          return 'La cuenta ya está vinculada.';
        case 'credential-already-in-use':
          // Al vincular un teléfono, la credencial en uso es ese número.
          if (error.credential is PhoneAuthCredential) {
            return 'Este teléfono ya está asociado a otra cuenta.';
          }
          return 'Ya existe una cuenta con este correo.';
        case 'invalid-phone-number':
          return 'El número de teléfono no es válido. Revisa los 9 dígitos '
              'de tu celular.';
        case 'missing-phone-number':
          return 'Ingresa tu teléfono.';
        case 'invalid-verification-code':
          return 'El código no es correcto. Revisa el SMS e inténtalo de '
              'nuevo.';
        case 'invalid-verification-id':
        case 'session-expired':
        case 'code-expired':
          return 'El código caducó. Pide uno nuevo.';
        case 'quota-exceeded':
          return 'Se alcanzó el límite de SMS. Intenta más tarde.';
        case 'captcha-check-failed':
          return 'No se pudo comprobar el reCAPTCHA. Recarga la página e '
              'inténtalo de nuevo.';
        case 'app-not-authorized':
        case 'missing-client-identifier':
          return 'La app no está autorizada para enviar SMS (revisa las '
              'huellas SHA-1/SHA-256 en Firebase).';
        case 'popup-blocked':
          return 'El navegador bloqueó la ventana de Google. Permite las '
              'ventanas emergentes para este sitio e intenta de nuevo.';
        case 'unauthorized-domain':
          return 'Este dominio no está autorizado en Firebase '
              '(Authentication > Settings > Authorized domains).';
        case 'google-provider-disabled':
          return 'El inicio de sesión con Google no está habilitado en '
              'Firebase (Authentication > Sign-in method).';
        case 'google-config-error':
          return 'Google Sign-In no está bien configurado para esta app '
              '(revisa la huella SHA-1 en Firebase).';
        case 'google-unsupported-platform':
          return 'El inicio de sesión con Google no está disponible en esta '
              'plataforma. Usa tu correo y contraseña.';
        case 'account-exists-with-different-credential':
          return 'Ya existe una cuenta con este correo usando otro método '
              'de inicio de sesión.';
        default:
          return genericMessage;
      }
    }
    return genericMessage;
  }
}
