import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;

  Uri resolve(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).replace(
      path: normalizedPath,
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  ApiConfig copyWith({String? baseUrl}) =>
      ApiConfig(baseUrl: baseUrl ?? this.baseUrl);
}

class ApiClient {
  ApiClient({
    required this.config,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final ApiConfig config;
  final http.Client _http;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) async {
    final uri = config.resolve(path, query);
    final response = await _http.get(uri);
    return _parseResponse(response, parser);
  }

  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    T Function(dynamic json)? parser,
  }) async {
    final uri = config.resolve(path, query);
    final response = await _http.post(
      uri,
      headers: _jsonHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response, parser);
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(dynamic json)? parser,
  }) async {
    final uri = config.resolve(path);
    final response = await _http.put(
      uri,
      headers: _jsonHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response, parser);
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(dynamic json)? parser,
  }) async {
    final uri = config.resolve(path);
    final response = await _http.delete(
      uri,
      headers: _jsonHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response, parser);
  }

  Future<T> _parseResponse<T>(
    http.Response response,
    T Function(dynamic json)? parser,
  ) async {
    final status = response.statusCode;
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (status < 200 || status >= 300) {
      throw ApiException(
        statusCode: status,
        message: decoded?['message'] ?? 'Request failed',
        details: decoded,
      );
    }

    if (parser != null) {
      return parser(decoded);
    }

    if (decoded is T) {
      return decoded;
    }

    throw ApiException(
      statusCode: status,
      message: 'Unable to parse response body',
      details: decoded,
    );
  }

  Map<String, String> get _jsonHeaders =>
      const {'Content-Type': 'application/json'};

  void close() => _http.close();
}

