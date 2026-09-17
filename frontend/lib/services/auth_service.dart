import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Hàm Đăng nhập
  Future<bool> login(String username, String password) async {
    try {
      final response = await _apiClient.dio.post(
        'auth/login/', // Điều chỉnh đường dẫn endpoint login của Django nếu cần
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        // Giả sử Django trả về access và refresh token trong response.data
        final accessToken = response.data['access'];
        final refreshToken = response.data['refresh'];

        // Lưu vào secure storage
        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);
        return true;
      }
    } catch (e) {
      print("Lỗi đăng nhập: $e");
    }
    return false;
  }

  // Hàm Đăng xuất
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // Kiểm tra xem đã đăng nhập chưa
  Future<bool> isLoggedIn() async {
    String? token = await _storage.read(key: 'access_token');
    return token != null;
  }
}
