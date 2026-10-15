import 'package:dio/dio.dart';
import 'token_storage.dart'; // Nơi lưu trữ Access & Refresh Token cục bộ (ví dụ: flutter_secure_storage)

class ApiClient {
  // 👉 MỖI KHI ĐỔI MẠNG (Ở nhà, trường học, quán cà phê), bạn chỉ cần sửa đúng dòng này!
  static const String currentIp = "192.168.1.5"; // Thay IP mới vào đây khi đổi mạng

  final String baseUrl = "http://$currentIp:8000/api/";
  
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor(dio));
  }
}

class AuthInterceptor extends Interceptor {
  final Dio dio;
  AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Lấy Access Token từ bộ nhớ bảo mật
    String? accessToken = await TokenStorage.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    return super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Nếu lỗi 401 Unauthorized (Access Token hết hạn)
    if (err.response?.statusCode == 401) {
      // Thực hiện logic gọi API làm mới token (Refresh Token Rotation) tại đây
      bool success = await _refreshToken();
      if (success) {
        // Thử lại request ban đầu với Token mới
        try {
          final opts = err.requestOptions;
          String? newToken = await TokenStorage.getAccessToken();
          opts.headers['Authorization'] = 'Bearer $newToken';
          
          final response = await dio.fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          return super.onError(err, handler);
        }
      }
    }
    return super.onError(err, handler);
  }

  Future<bool> _refreshToken() async {
    try {
      String? refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) return false;

      // Gọi endpoint cấp lại Access Token của SimpleJWT (Django)
      final response = await Dio().post(
        "http://10.0.2.2:8000/api/accounts/token/refresh/",
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        String newAccessToken = response.data['access'];
        await TokenStorage.saveAccessToken(newAccessToken);
        return true;
      }
    } catch (e) {
      // Nếu refresh token cũng hết hạn -> Đăng xuất người dùng
      await TokenStorage.clearTokens();
    }
    return false;
  }
}