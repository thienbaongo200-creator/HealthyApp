import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/token_storage.dart';
import 'api_config.dart';

typedef AuthenticatedRequest =
    Future<http.Response> Function(String? accessToken);

class AuthenticatedHttpClient {
  AuthenticatedHttpClient({
    http.Client? client,
    Future<String?> Function()? readAccessToken,
    Future<String?> Function()? readRefreshToken,
    Future<void> Function(String token)? saveAccessToken,
    Future<void> Function(String token)? saveRefreshToken,
    Future<void> Function()? clearTokens,
  }) : _client = client ?? http.Client(),
       _readAccessToken = readAccessToken ?? TokenStorage.getAccessToken,
       _readRefreshToken = readRefreshToken ?? TokenStorage.getRefreshToken,
       _saveAccessToken = saveAccessToken ?? TokenStorage.saveAccessToken,
       _saveRefreshToken = saveRefreshToken ?? TokenStorage.saveRefreshToken,
       _clearTokens = clearTokens ?? TokenStorage.clearTokens;

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final Future<String?> Function() _readAccessToken;
  final Future<String?> Function() _readRefreshToken;
  final Future<void> Function(String token) _saveAccessToken;
  final Future<void> Function(String token) _saveRefreshToken;
  final Future<void> Function() _clearTokens;

  static Future<String?>? _refreshInFlight;

  Future<http.Response> send(
    AuthenticatedRequest request, {
    bool retryUnauthorized = true,
    bool includeAccessToken = true,
  }) async {
    final accessToken = includeAccessToken ? await _readAccessToken() : null;
    final response = await request(accessToken).timeout(_timeout);
    if (response.statusCode != 401 || !retryUnauthorized) return response;

    final refreshedToken = await _refreshAccessToken();
    if (refreshedToken == null) return response;
    return request(refreshedToken).timeout(_timeout);
  }

  Future<http.Response> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    bool retryUnauthorized = true,
  }) {
    final isPublicAuthEndpoint = _isPublicAuthEndpoint(uri);
    return send(
      (accessToken) async {
        final request = http.Request(method, uri)
          ..headers.addAll(headersWithToken(headers, accessToken));
        if (body != null) request.body = body;
        final response = await _client.send(request).timeout(_timeout);
        return http.Response.fromStream(response);
      },
      retryUnauthorized: retryUnauthorized && !isPublicAuthEndpoint,
      includeAccessToken: !isPublicAuthEndpoint,
    );
  }

  Future<String?> _refreshAccessToken() async {
    final ongoingRefresh = _refreshInFlight;
    if (ongoingRefresh != null) {
      await ongoingRefresh;
      return _readAccessToken();
    }

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/auth/token/refresh/'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode == 400 || response.statusCode == 401) {
      await _clearTokens();
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Token refresh failed with HTTP ${response.statusCode}.',
      );
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic> ||
        payload['access'] is! String ||
        (payload['access'] as String).isEmpty) {
      throw const FormatException(
        'Token refresh response must contain a non-empty access token.',
      );
    }

    final accessToken = payload['access'] as String;
    await _saveAccessToken(accessToken);
    final rotatedRefreshToken = payload['refresh'];
    if (rotatedRefreshToken is String && rotatedRefreshToken.isNotEmpty) {
      await _saveRefreshToken(rotatedRefreshToken);
    }
    return accessToken;
  }

  static Map<String, String> headersWithToken(
    Map<String, String>? headers,
    String? accessToken,
  ) {
    final result = <String, String>{...?headers};
    if (accessToken != null && accessToken.isNotEmpty) {
      result['Authorization'] = 'Bearer $accessToken';
    } else {
      result.remove('Authorization');
    }
    return result;
  }

  static bool _isPublicAuthEndpoint(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final pathSegments = segments.toList(growable: false);
    if (pathSegments.length < 2 ||
        pathSegments[pathSegments.length - 2] != 'auth') {
      return false;
    }
    final endpoint = pathSegments.last;
    return endpoint == 'login' || endpoint == 'register';
  }
}
