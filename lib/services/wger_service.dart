import '../models/exercise_model.dart';
import 'rest_client.dart';

/// Categoría de ejercicios de wger, con su nombre en español.
class WgerCategory {
  const WgerCategory(this.id, this.label);

  final int id;
  final String label;

  /// Las 8 categorías de wger (`GET /exercisecategory/`).
  static const List<WgerCategory> all = [
    WgerCategory(11, 'Pecho'),
    WgerCategory(12, 'Espalda'),
    WgerCategory(9, 'Piernas'),
    WgerCategory(13, 'Hombros'),
    WgerCategory(8, 'Brazos'),
    WgerCategory(10, 'Abdomen'),
    WgerCategory(14, 'Gemelos'),
    WgerCategory(15, 'Cardio'),
  ];

  static String labelOf(int id) {
    for (final category in all) {
      if (category.id == id) return category.label;
    }
    return 'Otros';
  }
}

/// Ejercicio del catálogo público de wger, ya adaptado a la app.
class WgerExercise {
  const WgerExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.muscleGroup,
    required this.equipment,
    required this.muscles,
  });

  final int id;
  final String name;

  /// Descripción en texto plano (sin HTML).
  final String description;
  final int categoryId;

  /// Grupo muscular de la app (`AppConstants.muscleGroups`).
  final String muscleGroup;

  /// Equipamiento en español, separado por comas (vacío si no hay).
  final String equipment;

  /// Músculos principales (nombres en inglés de wger).
  final List<String> muscles;

  String get categoryLabel => WgerCategory.labelOf(categoryId);

  /// Ejercicio propio del usuario con estos datos.
  ExerciseModel toExercise(String id) => ExerciseModel(
    id: id,
    name: name,
    description: description,
    muscleGroup: muscleGroup,
    equipment: equipment,
  );

  /// Idiomas de wger: 4 = español, 2 = inglés.
  static const int _spanish = 4;
  static const int _english = 2;

  static const Map<String, String> _equipment = {
    'Barbell': 'Barra',
    'Bench': 'Banco',
    'Cable machine': 'Polea',
    'Dumbbell': 'Mancuernas',
    'Gym mat': 'Esterilla',
    'Incline bench': 'Banco inclinado',
    'Kettlebell': 'Kettlebell',
    'Pull-up bar': 'Barra de dominadas',
    'Resistance band': 'Banda elástica',
    'SZ-Bar': 'Barra Z',
    'Swiss Ball': 'Fitball',
    'none (bodyweight exercise)': 'Peso corporal',
  };

  /// Lee un elemento de `GET /exerciseinfo/`. Devuelve `null` si no tiene
  /// ningún nombre utilizable.
  static WgerExercise? fromJson(Map<String, dynamic> json) {
    final translations = [
      for (final t in (json['translations'] as List? ?? const []))
        if (t is Map<String, dynamic>) t,
    ];
    Map<String, dynamic>? pick(int language) {
      for (final t in translations) {
        final name = (t['name'] as String? ?? '').trim();
        if (t['language'] == language && name.isNotEmpty) return t;
      }
      return null;
    }

    // Preferencia: español, luego inglés, luego cualquiera con nombre.
    final translation =
        pick(_spanish) ??
        pick(_english) ??
        translations
            .where((t) => (t['name'] as String? ?? '').trim().isNotEmpty)
            .firstOrNull;
    if (translation == null) return null;

    final category = json['category'];
    final categoryId = category is Map ? (category['id'] as int? ?? 0) : 0;
    final muscles = [
      for (final m in (json['muscles'] as List? ?? const []))
        if (m is Map)
          ((m['name_en'] as String?)?.isNotEmpty ?? false)
              ? m['name_en'] as String
              : (m['name'] as String? ?? ''),
    ].where((m) => m.isNotEmpty).toList();
    final equipment = [
      for (final e in (json['equipment'] as List? ?? const []))
        if (e is Map && e['name'] is String)
          _equipment[e['name']] ?? e['name'] as String,
    ];

    return WgerExercise(
      id: json['id'] as int? ?? 0,
      name: (translation['name'] as String).trim(),
      description: stripHtml(translation['description'] as String? ?? ''),
      categoryId: categoryId,
      muscleGroup: muscleGroupFor(categoryId, muscles),
      equipment: equipment.join(', '),
      muscles: muscles,
    );
  }

  /// Grupo muscular de la app para una categoría de wger. "Brazos" se
  /// decide por los músculos (tríceps o bíceps) y "Piernas" puede ser
  /// glúteos si es el músculo principal.
  static String muscleGroupFor(int categoryId, List<String> muscles) {
    final lower = muscles.map((m) => m.toLowerCase()).toList();
    return switch (categoryId) {
      11 => 'Pecho',
      12 => 'Espalda',
      13 => 'Hombros',
      10 => 'Abdomen',
      15 => 'Cardio',
      8 => lower.any((m) => m.contains('tricep')) ? 'Tríceps' : 'Bíceps',
      9 when lower.isNotEmpty && lower.first.contains('glute') => 'Glúteos',
      _ => 'Piernas',
    };
  }

  /// Texto plano a partir del HTML de las descripciones de wger.
  static String stripHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n\s*\n+'), '\n')
      .trim();
}

/// Página de resultados de wger.
typedef WgerPage = ({List<WgerExercise> items, int count, Uri? next});

/// API REST pública de wger (https://wger.de/api/v2/), sin clave.
///
/// El servidor ignora los filtros de idioma y la búsqueda por texto; sí
/// respeta la categoría y la paginación (`limit`, `offset` y `next`).
class WgerService {
  static final Uri base = Uri.parse('https://wger.de/api/v2/');

  /// Primera página de ejercicios (de [categoryId] si se indica), o la
  /// página [next] devuelta por una consulta anterior.
  Future<WgerPage> fetchExercises({
    int? categoryId,
    Uri? next,
    int limit = 20,
  }) async {
    final uri =
        next ??
        base
            .resolve('exerciseinfo/')
            .replace(
              queryParameters: {
                'limit': '$limit',
                'offset': '0',
                'category': ?categoryId?.toString(),
              },
            );
    final json = await RestClient.getJson(uri);
    final results = json['results'] as List? ?? const [];
    final nextUrl = json['next'];
    return (
      items: [
        for (final item in results)
          if (item is Map<String, dynamic>) ?WgerExercise.fromJson(item),
      ],
      count: json['count'] as int? ?? 0,
      next: nextUrl is String ? Uri.tryParse(nextUrl) : null,
    );
  }
}
