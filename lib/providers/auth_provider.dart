import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  User? _user;
  UserModel? _profile;
  AuthStatus _status = AuthStatus.initializing;
  bool _processing = false;
  bool _registering = false;
  final Completer<void> _ready = Completer<void>();

  // Estado del paso "crear contraseña". Solo en memoria: la clave interna
  // del registro nunca se escribe en disco ni en Firestore.
  String? _setupUid;
  String? _setupSecret;
  bool _passwordConfirmed = false;
  String? _loginEmail;

  AuthProvider() {
    _subscriptions.add(
      _authService.authStateChanges.listen(_onAuthStateChanged),
    );
  }

  /// Se completa cuando Firebase ya resolvió el estado de autenticación
  /// inicial. Permite que la pantalla de splash espere ese resultado en
  /// lugar de competir contra un temporizador, que expulsaba a usuarios
  /// que sí tenían sesión activa.
  Future<void> get ready => _ready.future;

  User? get user => _user;
  UserModel? get profile => _profile;
  AuthStatus get status => _status;
  bool get processing => _processing;

  /// `true` desde que se inicia el registro hasta que la pantalla de
  /// registro termina y navega a `/verify-email`. Mientras tanto el router
  /// no debe sacar al usuario de `/register`.
  bool get registering => _registering;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  /// `true` si la cuenta puede iniciar sesión con correo y contraseña (y
  /// por tanto cambiarla). Se consulta a Firebase Auth, no al perfil.
  bool get hasPasswordSignIn =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  /// `true` si la cuenta está vinculada a Google.
  bool get hasGoogleSignIn =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  String? get uid => _user?.uid;
  String get displayName => _profile?.name ?? _user?.displayName ?? 'Usuario';

  /// `true` si el usuario con sesión se registró con correo y todavía no
  /// creó su contraseña definitiva. El router lo retiene en `/login`, donde
  /// se muestra el modal "Crear contraseña".
  bool get needsPasswordSetup {
    final current = _user;
    if (current == null || _passwordConfirmed) return false;
    return _setupUid == current.uid || (_profile?.passwordPending ?? false);
  }

  /// Correo que el Login debe mostrar ya escrito (el del registro).
  String? get loginEmail =>
      _loginEmail ?? (needsPasswordSetup ? _user?.email : null);

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _user = firebaseUser;
    if (firebaseUser == null) {
      _profile = null;
      _status = AuthStatus.unauthenticated;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
      return;
    }
    // El perfil se carga ANTES de marcar la sesión como iniciada: el router
    // necesita saber si falta crear la contraseña para no enviar al usuario
    // directamente al Dashboard.
    await _loadProfile(firebaseUser.uid, notify: false);
    if (_user?.uid != firebaseUser.uid) return;
    _status = AuthStatus.authenticated;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> _loadProfile(String userId, {bool notify = true}) async {
    try {
      _profile = await _firestore.getUserProfile(userId);
    } catch (_) {
      _profile = null;
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshProfile() async {
    final userId = uid;
    if (userId == null) return;
    await _loadProfile(userId);
  }

  Future<RegisterResult> register({
    required String name,
    required String email,
    String? birthDate,
    String? goal,
    String? level,
  }) async {
    // Se activa antes de crear la cuenta: `authStateChanges` notifica al
    // router en cuanto Firebase crea el usuario y, sin esta marca, la
    // pantalla de registro se destruía antes de terminar su flujo.
    _registering = true;
    _passwordConfirmed = false;
    final RegisterResult result;
    try {
      result = await _authService.registerWithEmail(
        name: name.trim(),
        email: email.trim(),
      );
    } catch (_) {
      finishRegistration();
      rethrow;
    }
    _setupUid = result.user.uid;
    _setupSecret = result.setupSecret;
    _loginEmail = email.trim();
    // La cuenta ya está creada. Si falla el perfil en Firestore no se
    // propaga el error: se informa dentro del resultado.
    String? profileError;
    try {
      await _firestore.createUserProfile(
        UserModel(
          uid: result.user.uid,
          name: name.trim(),
          email: email.trim(),
          birthDate: birthDate,
          goal: goal,
          level: level,
          provider: 'email',
          passwordPending: true,
        ),
      );
    } catch (error) {
      debugPrint('No se pudo crear el perfil de Firestore: $error');
      profileError = _profileErrorMessage(error);
    }
    await refreshProfile();
    return result.withProfileError(profileError);
  }

  /// Libera la marca de registro y deja que el router vuelva a aplicar sus
  /// redirecciones (por ejemplo, hacia `/verify-email`).
  void finishRegistration() {
    if (!_registering) return;
    _registering = false;
    notifyListeners();
  }

  String _profileErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Las reglas de Firestore no permiten guardar tu perfil.';
        case 'unavailable':
          return 'No hay conexión con Firestore.';
        case 'not-found':
          return 'La base de datos de Firestore no existe en el proyecto.';
        default:
          return 'Firestore respondió con el error "${error.code}".';
      }
    }
    return 'Error inesperado: $error';
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _processing = true;
    // Entrar con correo y contraseña demuestra que la contraseña ya existe.
    // Se marca antes de iniciar sesión para que el router no muestre el
    // modal de "Crear contraseña" mientras se carga el perfil.
    _passwordConfirmed = true;
    notifyListeners();
    try {
      final credential = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      _loginEmail = null;
      final userId = credential.user?.uid;
      if (userId != null && (_profile?.passwordPending ?? false)) {
        // Caso del enlace de respaldo: la contraseña se creó desde el
        // correo de Firebase y el indicador quedó pendiente.
        await _clearPasswordPending(userId);
      }
    } catch (_) {
      _passwordConfirmed = false;
      rethrow;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  /// Crea la contraseña definitiva del usuario recién verificado y cierra
  /// su sesión para que vuelva a entrar desde el Login con ella.
  Future<void> createPassword(String newPassword) async {
    final current = _user;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay una sesión activa.',
      );
    }
    await _authService.setInitialPassword(
      newPassword: newPassword,
      setupSecret: _setupUid == current.uid ? _setupSecret : null,
    );
    _passwordConfirmed = true;
    _loginEmail = current.email;
    await _clearPasswordPending(current.uid);
    await logout();
  }

  /// Respaldo cuando Firebase exige un inicio de sesión reciente y ya no se
  /// tiene la clave interna (la app se reinició): se envía el enlace de
  /// Firebase para que el usuario cree su contraseña desde el correo.
  Future<void> sendPasswordSetupLink() async {
    final email = _user?.email;
    if (email == null) return;
    await _authService.sendPasswordResetEmail(email);
    _passwordConfirmed = true;
    _loginEmail = email;
    await logout();
  }

  Future<void> _clearPasswordPending(String userId) async {
    try {
      await _firestore.updateUserProfile(userId, {'passwordPending': false});
      _profile = _profile?.copyWith(passwordPending: false);
    } catch (error) {
      debugPrint('No se pudo actualizar passwordPending: $error');
    }
  }

  Future<void> loginWithGoogle() async {
    _processing = true;
    notifyListeners();
    try {
      final credential = await _authService.signInWithGoogle();
      await _ensureUserProfile(credential.user!);
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<void> _ensureUserProfile(User firebaseUser) async {
    final existing = await _firestore.getUserProfile(firebaseUser.uid);
    if (existing == null) {
      final provider = await _authService.getProviderId();
      await _firestore.createUserProfile(
        UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          provider: provider,
          emailVerified: firebaseUser.emailVerified,
        ),
      );
    } else {
      await _firestore.updateUserProfile(firebaseUser.uid, {
        'name': firebaseUser.displayName ?? existing.name,
        'email': firebaseUser.email ?? existing.email,
        'photoUrl': firebaseUser.photoURL ?? existing.photoUrl,
        'emailVerified': firebaseUser.emailVerified,
      });
    }
    await refreshProfile();
  }

  Future<void> sendVerificationEmail() {
    return _authService.sendVerificationEmail();
  }

  Future<void> sendPasswordReset(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<bool> checkEmailVerification() async {
    final user = await _authService.reloadUser();
    // `reload()` crea un `User` nuevo y solo lo emite por `userChanges()`,
    // no por `authStateChanges()`. Sin esta asignación `_user` conservaba
    // `emailVerified == false` y el router devolvía al usuario a
    // `/verify-email` aunque ya hubiera verificado su correo.
    _user = user;
    if (user.emailVerified) {
      final userId = uid;
      if (userId != null) {
        // La verificación la decide Firebase Auth: si falla esta copia en
        // Firestore no debe impedir que el usuario continúe.
        try {
          await _firestore.updateUserProfile(userId, {'emailVerified': true});
        } catch (error) {
          debugPrint('No se pudo marcar emailVerified en Firestore: $error');
        }
      }
    }
    await refreshProfile();
    return user.emailVerified;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _processing = true;
    notifyListeners();
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? birthDate,
    String? goal,
    String? level,
  }) async {
    final userId = uid;
    if (userId == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No hay una sesión activa.',
      );
    }
    final safeName = (name ?? _profile?.name ?? _user?.displayName)
        ?.trim()
        .toString();

    // Se escribe primero en Firestore: si `updateDisplayName` falla, el
    // perfil ya quedó guardado en lugar de perder la escritura.
    await _firestore.updateUserProfile(userId, {
      'name': safeName,
      'birthDate': birthDate,
      'goal': goal,
      'level': level,
    });

    if (safeName != null && safeName.isNotEmpty) {
      try {
        await _authService.updateDisplayName(safeName);
      } catch (error) {
        debugPrint('No se pudo actualizar el nombre en Auth: $error');
      }
    }
    await refreshProfile();
  }

  Future<void> logout() async {
    // La clave interna del registro se descarta al salir.
    _setupUid = null;
    _setupSecret = null;
    await _authService.logout();
    _passwordConfirmed = false;
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
