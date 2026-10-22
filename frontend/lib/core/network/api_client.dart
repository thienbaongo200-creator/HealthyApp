import 'package:dio/dio.dart';

import '../../services/api_config.dart';
import 'token_storage.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: '$apiBaseUrl/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor(dio));
  }
}

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this.dio);

  final Dio dio;
  Future<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthEndpoint(options.uri)) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }

    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isRefreshRequest = request.path.endsWith('/auth/token/refresh/');
    final isPublicAuthEndpoint = _isPublicAuthEndpoint(request.uri);
    final isUpload =
        request.data is FormData ||
        request.contentType?.toLowerCase().startsWith('multipart/') == true;
    final alreadyRetried = request.extra['authRetryCount'] == 1;

    if (err.response?.statusCode != 401 ||
        isRefreshRequest ||
        isPublicAuthEndpoint ||
        isUpload ||
        alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final refreshed = await _refreshTokens();
      if (!refreshed) {
        handler.next(err);
        return;
      }

      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        handler.next(err);
        return;
      }

      request
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra['authRetryCount'] = 1;
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (refreshError) {
      handler.next(refreshError);
    } on FormatException catch (refreshError) {
      handler.next(
        DioException(
          requestOptions: request,
          error: refreshError,
          message: 'Token refresh returned an invalid response.',
        ),
      );
    }
  }

  bool _isPublicAuthEndpoint(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final pathSegments = segments.toList(growable: false);
    if (pathSegments.length < 2 ||
        pathSegments[pathSegments.length - 2] != 'auth') {
      return false;
    }
    final endpoint = pathSegments.last;
    return endpoint == 'login' || endpoint == 'register';
  }

  Future<bool> _refreshTokens() async {
    final ongoingRefresh = _refreshInFlight;
    if (ongoingRefresh != null) return ongoingRefresh;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: '$apiBaseUrl/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        'auth/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final accessToken = response.data?['access'];
      if (response.statusCode != 200 ||
          accessToken is! String ||
          accessToken.isEmpty) {
        throw const FormatException(
          'Token refresh response must contain a non-empty access token.',
        );
      }
      await TokenStorage.saveAccessToken(accessToken);
      final rotatedRefreshToken = response.data?['refresh'];
      if (rotatedRefreshToken is String && rotatedRefreshToken.isNotEmpty) {
        await TokenStorage.saveRefreshToken(rotatedRefreshToken);
      }
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 401) {
        await TokenStorage.clearTokens();
        return false;
      }
      rethrow;
    }
  }
}
