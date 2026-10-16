import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.body = const {}});

  final int statusCode;
  final String message;

  /// Cuerpo JSON del error (p. ej. `suggestion` en un 409 de nickname tomado).
  final Map<String, dynamic> body;

  bool get isNetwork => statusCode == 0;
  bool get isConflict => statusCode == 409;

  String? get suggestion => body['suggestion']?.toString();

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = AppConfig.apiBaseUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  String? token;

  Map<String, String> _headers({required bool auth}) => {
        'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _guard(
      _client.post(
        _uri(path),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _guard(_client.get(_uri(path, query), headers: _headers(auth: auth)));
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _guard(
      _client.put(
        _uri(path),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _guard(_client.delete(_uri(path), headers: _headers(auth: true)));
  }

  Future<Map<String, dynamic>> _guard(Future<http.Response> future) async {
    http.Response res;
    try {
      res = await future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const ApiException(0, 'Sin conexión con el servidor');
    } catch (_) {
      throw const ApiException(0, 'Sin conexión con el servidor');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      body = const {};
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        body['error']?.toString() ?? 'Error del servidor',
        body: body,
      );
    }
    return body;
  }
}
