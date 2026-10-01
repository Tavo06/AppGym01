import '../core/utils/firestore_utils.dart';

/// Ejercicio del catálogo del usuario (el papel de `Ejercicio`).
///
/// Encapsulado: los campos son privados y de solo lectura (se exponen con
/// getters). Para modificar un ejercicio se crea una copia con [copyWith].
class ExerciseModel {
  ExerciseModel({
    required this._id,
    required this._name,
    this._description = '',
    required this._muscleGroup,
    this._equipment = '',
    this._createdAt,
    this._updatedAt,
  });

  final String _id;
  final String _name;
  final String _description;
  final String _muscleGroup;
  final String _equipment;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  String get id => _id;
  String get name => _name;
  String get description => _description;
  String get muscleGroup => _muscleGroup;
  String get equipment => _equipment;
  DateTime? get createdAt => _createdAt;
  DateTime? get updatedAt => _updatedAt;

  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'name': _name,
      'description': _description,
      'muscleGroup': _muscleGroup,
      'equipment': _equipment,
      'createdAt': _createdAt ?? now,
      'updatedAt': _updatedAt ?? now,
    };
  }

  factory ExerciseModel.fromMap(String id, Map<String, dynamic> map) {
    return ExerciseModel(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      muscleGroup: map['muscleGroup'] as String? ?? 'Pecho',
      equipment: map['equipment'] as String? ?? '',
      createdAt: firestoreDateFrom(map['createdAt']),
      updatedAt: firestoreDateFrom(map['updatedAt']),
    );
  }

  ExerciseModel copyWith({
    String? name,
    String? description,
    String? muscleGroup,
    String? equipment,
  }) {
    return ExerciseModel(
      id: _id,
      name: name ?? _name,
      description: description ?? _description,
      muscleGroup: muscleGroup ?? _muscleGroup,
      equipment: equipment ?? _equipment,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
