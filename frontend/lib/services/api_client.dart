import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiClient {
  late final Dio dio;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: '$apiBaseUrl/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Thêm Interceptor để tự động gắn Token và xử lý Refresh
    dio.interceptors.add(AuthInterceptor(dio, storage));
  }
}

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final FlutterSecureStorage storage;

  AuthInterceptor(this.dio, this.storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Đính kèm Access Token vào request nếu có
    String? token = await storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Nếu lỗi 401 nghĩa là Access Token hết hạn
    if (err.response?.statusCode == 401) {
      try {
        String? refreshToken = await storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          return super.onError(err, handler);
        }

        // Gọi API lấy Access Token mới (dùng Dio riêng để tránh vòng lặp interceptor)
        final response = await Dio().post(
          '$apiBaseUrl/auth/token/refresh/',
          data: {'refresh': refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccessToken = response.data['access'];
          await storage.write(key: 'access_token', value: newAccessToken);

          // Nếu có rotation refresh token, cập nhật lại refresh token mới
          if (response.data['refresh'] != null) {
            await storage.write(
              key: 'refresh_token',
              value: response.data['refresh'],
            );
          }

          // Cập nhật lại header cho request cũ đang bị lỗi
          err.requestOptions.headers['Authorization'] =
              'Bearer $newAccessToken';

          // Gửi lại request ban đầu với token mới
          final cloneReq = await dio.fetch(err.requestOptions);
          return handler.resolve(cloneReq);
        }
      } catch (e) {
        // Refresh token cũng chết -> Xóa dữ liệu và chuyển về Login
        await storage.deleteAll();
      }
    }
    return super.onError(err, handler);
  }
}
