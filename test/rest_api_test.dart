import 'dart:convert';

import 'package:fitprogress/services/open_food_facts_service.dart';
import 'package:fitprogress/services/rest_client.dart';
import 'package:fitprogress/services/wger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Respuesta JSON de prueba (UTF-8, como las de las API reales).
http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> wgerItem({
  required int id,
  required int category,
  List<Map<String, dynamic>> translations = const [],
  List<String> muscles = const [],
  List<String> equipment = const [],
}) => {
  'id': id,
  'category': {'id': category, 'name': 'x'},
  'muscles': [
    for (final m in muscles) {'name': m, 'name_en': m},
  ],
  'equipment': [
    for (final e in equipment) {'name': e},
  ],
  'translations': translations,
};

void main() {
  late List<Uri> requests;

  void mock(http.Response Function(http.Request request) handler) {
    requests = [];
    RestClient.clientOverride = MockClient((request) async {
      requests.add(request.url);
      return handler(request);
    });
  }

  tearDown(() => RestClient.clientOverride = null);

  group('wger', () {
    test('prefiere el español, limpia el HTML y adapta grupo y equipo', () {
      final exercise = WgerExercise.fromJson(
        wgerItem(
          id: 1,
          category: 8,
          muscles: ['Triceps'],
          equipment: ['Barbell', 'Bench'],
          translations: [
            {'language': 2, 'name': 'Close-grip bench press'},
            {
              'language': 4,
              'name': ' Press cerrado ',
              'description':
                  '<p>Agarre <b>estrecho</b>.</p><p>Codos&nbsp;'
                  'pegados.</p>',
            },
          ],
        ),
      )!;
      expect(exercise.name, 'Press cerrado');
      expect(exercise.description, 'Agarre estrecho.\nCodos pegados.');
      expect(exercise.muscleGroup, 'Tríceps');
      expect(exercise.categoryLabel, 'Brazos');
      expect(exercise.equipment, 'Barra, Banco');

      final model = exercise.toExercise('nuevo-id');
      expect(model.id, 'nuevo-id');
      expect(model.muscleGroup, 'Tríceps');
      expect(model.equipment, 'Barra, Banco');
    });

    test('sin español usa el inglés; sin nombre se omite', () {
      final english = WgerExercise.fromJson(
        wgerItem(
          id: 2,
          category: 9,
          muscles: ['Glutes', 'Quads'],
          translations: [
            {'language': 1, 'name': ''},
            {'language': 2, 'name': 'Hip thrust'},
          ],
        ),
      )!;
      expect(english.name, 'Hip thrust');
      // Piernas con glúteos como músculo principal.
      expect(english.muscleGroup, 'Glúteos');
      expect(english.equipment, isEmpty);

      expect(WgerExercise.fromJson(wgerItem(id: 3, category: 11)), isNull);
      expect(WgerExercise.muscleGroupFor(8, const ['Biceps']), 'Bíceps');
      expect(WgerExercise.muscleGroupFor(14, const []), 'Piernas');
      expect(WgerExercise.muscleGroupFor(15, const []), 'Cardio');
    });

    test('pide la categoría y pagina con `next`', () async {
      mock(
        (_) => jsonResponse({
          'count': 2,
          'next': 'https://wger.de/api/v2/exerciseinfo/?limit=1&offset=1',
          'results': [
            wgerItem(
              id: 1,
              category: 11,
              translations: [
                {'language': 4, 'name': 'Press de banca'},
              ],
            ),
            // Sin traducciones: se omite sin romper la página.
            wgerItem(id: 2, category: 11),
          ],
        }),
      );
      final page = await WgerService().fetchExercises(categoryId: 11);
      expect(requests.single.path, '/api/v2/exerciseinfo/');
      expect(requests.single.queryParameters['category'], '11');
      expect(requests.single.queryParameters['limit'], '20');
      expect(page.items.map((e) => e.name), ['Press de banca']);
      expect(page.count, 2);
      expect(page.next?.queryParameters['offset'], '1');

      await WgerService().fetchExercises(next: page.next);
      expect(requests.last, page.next);
    });

    test('errores del servidor, de formato y de red en español', () async {
      mock((_) => http.Response('error', 503));
      await expectLater(
        WgerService().fetchExercises(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', contains('no está')),
        ),
      );

      // Página HTML de mantenimiento con código 200.
      mock((_) => http.Response('<html>Mantenimiento</html>', 200));
      await expectLater(
        WgerService().fetchExercises(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('formato inesperado'),
          ),
        ),
      );

      RestClient.clientOverride = MockClient(
        (_) => throw http.ClientException('sin red'),
      );
      await expectLater(
        WgerService().fetchExercises(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('conexión'),
          ),
        ),
      );
    });
  });

  group('Open Food Facts', () {
    test(
      'búsqueda: marca, números como texto y sin calorías se omite',
      () async {
        mock(
          (_) => jsonResponse({
            'hits': [
              {
                'code': '7790199603306',
                'product_name': 'Avena tradicional',
                'brands': ['Morixe'],
                'nutriments': {
                  'energy-kcal_100g': 373,
                  'proteins_100g': '13',
                  'carbohydrates_100g': 63.3,
                  'fat_100g': 8.33,
                },
              },
              {
                'product_name': 'Sin datos',
                'nutriments': {'proteins_100g': 5},
              },
              {
                'product_name': 'Avena instantánea',
                'brands': 'Quaker, PepsiCo',
                'nutriments': {'energy-kcal_100g': '380'},
              },
            ],
          }),
        );
        final results = await OpenFoodFactsService().search(' avena ');
        final uri = requests.single;
        expect(uri.host, 'search.openfoodfacts.org');
        expect(uri.queryParameters['q'], 'avena');
        expect(uri.queryParameters['fields'], contains('nutriments'));

        expect(results, hasLength(2));
        expect(results.first.displayName, 'Avena tradicional (Morixe)');
        expect(results.first.protein, 13);
        expect(results.last.displayName, 'Avena instantánea (Quaker)');
        expect(results.last.kcal, 380);
        expect(results.last.fat, 0);

        // Alimento de 100 g, que el formulario recalcula al cambiar cantidad.
        final food = results.first.toFood();
        expect(food.quantity, 100);
        expect(food.kcal, 373);
        expect(food.withQuantity(50).kcal, closeTo(186.5, 0.01));
      },
    );

    test('código de barras: encontrado, inexistente y sin calorías', () async {
      mock((request) {
        final code = request.url.pathSegments.last;
        if (code == '3017624010701') {
          return jsonResponse({
            'code': code,
            'product': {
              'product_name': 'Nutella',
              'brands': 'Ferrero',
              'nutriments': {'energy-kcal_100g': 539, 'fat_100g': 30.9},
            },
          });
        }
        if (code == '1111111111111') {
          return jsonResponse({
            'code': code,
            'product': {'product_name': 'Sin calorías', 'nutriments': {}},
          });
        }
        return jsonResponse({'status': 0}, status: 404);
      });
      final service = OpenFoodFactsService();
      final nutella = await service.byBarcode('3017624010701');
      expect(nutella!.displayName, 'Nutella (Ferrero)');
      expect(nutella.code, '3017624010701');
      expect(requests.last.host, 'world.openfoodfacts.org');
      expect(await service.byBarcode('0000000000000'), isNull);
      expect(await service.byBarcode('1111111111111'), isNull);

      expect(OpenFoodFactsService.isBarcode('3017624010701'), isTrue);
      expect(OpenFoodFactsService.isBarcode('12345678'), isTrue);
      expect(OpenFoodFactsService.isBarcode('avena'), isFalse);
      expect(OpenFoodFactsService.isBarcode('1234'), isFalse);
    });

    test('demasiadas consultas: aviso de esperar', () async {
      mock((_) => http.Response('{}', 429));
      await expectLater(
        OpenFoodFactsService().search('arroz'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
      );
    });
  });
}
