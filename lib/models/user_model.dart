import '../core/utils/firestore_utils.dart';

/// Perfil del usuario guardado en Firestore.
///
/// Encapsulado: campos privados de solo lectura. Para cambiar el perfil se
/// crea una copia con [copyWith].
class UserModel {
  UserModel({
    required this._uid,
    required this._name,
    required this._email,
    this._photoUrl,
    this._birthDate,
    this._goal,
    this._level,
    this._provider = 'email',
    this._emailVerified = false,
    this._passwordPending = false,
    this._createdAt,
    this._updatedAt,
  });

  final String _uid;
  final String _name;
  final String _email;
  final String? _photoUrl;
  final String? _birthDate;
  final String? _goal;
  final String? _level;
  final String _provider;
  final bool _emailVerified;
  final bool _passwordPending;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  String get uid => _uid;
  String get name => _name;
  String get email => _email;
  String? get photoUrl => _photoUrl;
  String? get birthDate => _birthDate;
  String? get goal => _goal;
  String? get level => _level;
  String get provider => _provider;
  bool get emailVerified => _emailVerified;

  /// `true` mientras un usuario registrado con correo aún no creó su
  /// contraseña definitiva. No guarda ninguna contraseña.
  bool get passwordPending => _passwordPending;
  DateTime? get createdAt => _createdAt;
  DateTime? get updatedAt => _updatedAt;

  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'uid': _uid,
      'name': _name,
      'email': _email,
      'photoUrl': _photoUrl,
      'birthDate': _birthDate,
      'goal': _goal,
      'level': _level,
      'provider': _provider,
      'emailVerified': _emailVerified,
      'passwordPending': _passwordPending,
      'createdAt': _createdAt ?? now,
      'updatedAt': _updatedAt ?? now,
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      birthDate: map['birthDate'] as String?,
      goal: map['goal'] as String?,
      level: map['level'] as String?,
      provider: map['provider'] as String? ?? 'email',
      emailVerified: map['emailVerified'] as bool? ?? false,
      passwordPending: map['passwordPending'] as bool? ?? false,
      createdAt: firestoreDateFrom(map['createdAt']),
      updatedAt: firestoreDateFrom(map['updatedAt']),
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? birthDate,
    String? goal,
    String? level,
    String? provider,
    bool? emailVerified,
    bool? passwordPending,
  }) {
    return UserModel(
      uid: _uid,
      name: name ?? _name,
      email: email ?? _email,
      photoUrl: photoUrl ?? _photoUrl,
      birthDate: birthDate ?? _birthDate,
      goal: goal ?? _goal,
      level: level ?? _level,
      provider: provider ?? _provider,
      emailVerified: emailVerified ?? _emailVerified,
      passwordPending: passwordPending ?? _passwordPending,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
