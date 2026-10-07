import '../models/nutrition_model.dart';
import 'rest_client.dart';

/// Producto de Open Food Facts con sus valores por 100 g.
class OffProduct {
  const OffProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Código de barras.
  final String code;
  final String name;
  final String brand;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Nombre con la marca: "Avena tradicional (Morixe)".
  String get displayName => brand.isEmpty ? name : '$name ($brand)';

  /// Alimento de 100 g; al cambiar la cantidad en el formulario, los valores
  /// se recalculan en proporción.
  FoodItem toFood() => FoodItem(
    name: displayName,
    quantity: 100,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );

  /// Lee un producto (de la búsqueda o de la consulta por código). Devuelve
  /// `null` si no tiene nombre o calorías: sin ellas no sirve para
  /// registrar lo que se come.
  static OffProduct? fromJson(Map<String, dynamic> json) {
    final name = (json['product_name'] as String? ?? '').trim();
    final nutriments = json['nutriments'];
    if (name.isEmpty || nutriments is! Map) return null;
    final kcal = RestClient.number(nutriments['energy-kcal_100g']);
    if (kcal == null) return null;
    final brands = json['brands'];
    final brand = switch (brands) {
      final List list when list.isNotEmpty => '${list.first}',
      final String text => text.split(',').first,
      _ => '',
    }.trim();
    double value(String key) =>
        RestClient.number(nutriments['${key}_100g']) ?? 0;
    return OffProduct(
      code: '${json['code'] ?? ''}',
      name: name,
      brand: brand,
      kcal: kcal,
      protein: value('proteins'),
      carbs: value('carbohydrates'),
      fat: value('fat'),
    );
  }
}

/// API REST pública de Open Food Facts, sin clave.
///
/// - Búsqueda por nombre: `search.openfoodfacts.org/search`. Este servidor
///   no envía cabeceras CORS, así que en la web el navegador bloquea la
///   respuesta (en Android y Windows funciona).
/// - Producto por código de barras: `world.openfoodfacts.org/api/v2/product`
///   (con CORS: funciona en todas las plataformas).
class OpenFoodFactsService {
  static const _fields = 'code,product_name,brands,nutriments';

  static const String webSearchBlocked =
      'En la versión web, Open Food Facts no permite buscar por nombre '
      'desde el navegador. Escribe el código de barras del producto o usa '
      'la app de Android o Windows.';

  /// Busca productos por [query]. Omite los que no traen calorías.
  Future<List<OffProduct>> search(String query, {int pageSize = 20}) async {
    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': query.trim(),
      'page_size': '$pageSize',
      'fields': _fields,
      'langs': 'es',
    });
    final json = await RestClient.getJson(
      uri,
      webBlockedMessage: webSearchBlocked,
    );
    return [
      for (final hit in (json['hits'] as List? ?? const []))
        if (hit is Map<String, dynamic>) ?OffProduct.fromJson(hit),
    ];
  }

  /// Producto con el código de barras [code], o `null` si no existe o no
  /// tiene datos de calorías.
  Future<OffProduct?> byBarcode(String code) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/${code.trim()}',
      {'fields': _fields},
    );
    final Map<String, dynamic> json;
    try {
      json = await RestClient.getJson(uri);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;
    return OffProduct.fromJson({...product, 'code': json['code'] ?? code});
  }

  /// `true` si [text] parece un código de barras (EAN/UPC: 8 a 14 dígitos).
  static bool isBarcode(String text) =>
      RegExp(r'^\d{8,14}$').hasMatch(text.trim());
}
