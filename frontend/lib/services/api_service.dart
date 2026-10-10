import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

class ApiService {
  static const String baseUrl = apiBaseUrl;
  static const Duration _loginTimeout = Duration(seconds: 15);

  static Future<http.Response> _send(Future<http.Response> request) =>
      request.timeout(_loginTimeout);

  static String? _token;
  static final ApiService instance = ApiService();

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _send(http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ));
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
      final response = await _send(http.patch(
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
      ));
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

  Future<String> login(String account, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login/');
    developer.log('Login request to $uri', name: 'ApiService');

    final response = await _send(
      http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'account': account, 'password': password}),
        ),
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode,
          'Server trả về nội dung không phải JSON.',
        );
      }
      rethrow;
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('API login response must be a JSON object.');
    }

    if (response.statusCode != 200) {
      final detail = decoded['detail'] ?? decoded['message'];
      throw ApiException(
        response.statusCode,
        detail is String ? detail : 'Yêu cầu đăng nhập không thành công.',
      );
    }

    final accessToken = decoded['access'] ?? decoded['token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException(
        'API login response does not contain an access token.',
      );
    }
    return accessToken;
  }

  Future<String?> loginWithGoogle(String accessToken) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    ));
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
      final response = await _send(http.post(
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
      ));

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

  static Future<bool> sendHealthMeasurements(
    List<Map<String, dynamic>> measurements,
  ) async {
    try {
      final response = await _send(
        http.post(
            Uri.parse('$baseUrl/medical/measurements/batch/'),
            headers: {
              'Content-Type': 'application/json',
              if (_token != null) 'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({'measurements': measurements}),
          ),
      );

      if (response.statusCode == 201) {
        developer.log(
          '[API] Đã đồng bộ ${measurements.length} bản ghi sức khỏe.',
          name: 'ApiService',
        );
        return true;
      }
      developer.log(
        '[API] Lỗi đồng bộ batch (${response.statusCode}): ${response.body}',
        name: 'ApiService',
        level: 900,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '[API] Lỗi kết nối batch API: $e',
        name: 'ApiService',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHealthMeasurements() async {
    final response = await _send(
      http.get(
        Uri.parse('$baseUrl/medical/measurements/'),
        headers: {
          'Accept': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không thể tải nhật ký sức khỏe.');
    }

    final payload = jsonDecode(response.body);
    final records = payload is List
        ? payload
        : payload is Map<String, dynamic>
        ? payload['results']
        : null;
    if (records is! List) {
      throw const FormatException('Measurement response must contain a list.');
    }
    return records.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}
