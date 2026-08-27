import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 là địa chỉ IP localhost của máy chủ host từ góc nhìn của Android Emulator
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  static String? _token;
  static final ApiService instance = ApiService();

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 201,
        'message': data['detail'] ?? data['message'] ?? 'Đăng ký thất bại.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Mất kết nối server hoặc lỗi hệ thống.',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String gender,
    required String dob,
    required double height,
    required double weight,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'gender': gender,
          'date_of_birth': dob,
          'height': height,
          'weight': weight,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': data['detail'] ?? data['message'] ?? 'Cập nhật thất bại.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Mất kết nối server hoặc lỗi hệ thống.',
      };
    }
  }

  Future<String?> login(String account, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access'] as String? ?? data['token'] as String?;
  }

  Future<String?> loginWithGoogle(String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access'] as String? ?? data['token'] as String?;
  }

  void setToken(String token) {
    _token = token;
  }

  static Future<bool> sendHealthData({
    required int heartRate,
    required int steps,
    required double calories,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/health/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'heart_rate': heartRate,
          'steps': steps,
          'calories': calories,
        }),
      );

      if (response.statusCode == 201) {
        developer.log(
          '[API] Đã lưu bản ghi sức khỏe lên Django thành công!',
          name: 'ApiService',
        );
        return true;
      } else {
        developer.log(
          '[API] Lỗi server: ${response.body}',
          name: 'ApiService',
          level: 900,
        );
        return false;
      }
    } catch (e, st) {
      developer.log(
        '[API] Lỗi kết nối API: $e',
        name: 'ApiService',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
