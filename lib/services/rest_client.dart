import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

/// Error de una API REST con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// Código HTTP de la respuesta, si la hubo.
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente común de las API REST externas (wger y Open Food Facts): GET con
/// tiempo máximo, decodificación JSON y errores en español.
///
/// En las pruebas se sustituye con [clientOverride] (un `MockClient`), igual
/// que `AppFirebase.firestoreOverride`.
abstract final class RestClient {
  static http.Client? clientOverride;

  static http.Client get client => clientOverride ?? _default;
  static final http.Client _default = http.Client();

  static const Duration timeout = Duration(seconds: 15);

  /// Identificación de la app que piden las API públicas (Open Food Facts lo
  /// exige). En la web el navegador no permite cambiar el User-Agent.
  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (!kIsWeb) 'User-Agent': '${AppConstants.appName}/1.0 (app de gimnasio)',
  };

  /// GET a [uri] y devuelve el JSON decodificado (un `Map`).
  ///
  /// [webBlockedMessage]: mensaje si la llamada falla en la web por la
  /// política CORS del servidor (el navegador no deja leer la respuesta).
  static Future<Map<String, dynamic>> getJson(
    Uri uri, {
    String? webBlockedMessage,
  }) async {
    final http.Response response;
    try {
      response = await client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } on http.ClientException catch (error) {
      debugPrint('Error de red con $uri: $error');
      if (kIsWeb && webBlockedMessage != null) {
        throw ApiException(webBlockedMessage);
      }
      throw const ApiException(
        'No se pudo conectar. Revisa tu conexión a Internet.',
      );
    } catch (error) {
      debugPrint('Error de red con $uri: $error');
      throw const ApiException(
        'No se pudo conectar. Revisa tu conexión a Internet.',
      );
    }

    if (response.statusCode == 404) {
      throw const ApiException('No se encontró.', statusCode: 404);
    }
    if (response.statusCode == 429) {
      throw const ApiException(
        'Demasiadas consultas seguidas. Espera un momento.',
        statusCode: 429,
      );
    }
    if (response.statusCode >= 500) {
      throw ApiException(
        'El servicio no está disponible ahora. Inténtalo más tarde.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Respuesta inesperada del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Cae al error de abajo (p. ej. una página HTML de mantenimiento).
    }
    throw const ApiException(
      'El servicio respondió con un formato inesperado. Inténtalo más tarde.',
    );
  }

  /// Número de un campo JSON que puede llegar como número o como texto.
  static double? number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
