import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 là địa chỉ IP localhost của máy chủ host từ góc nhìn của Android Emulator
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  static Future<bool> sendHealthData({
    required int heartRate,
    required int steps,
    required double calories,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/health/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'heart_rate': heartRate,
          'steps': steps,
          'calories': calories,
        }),
      );

      if (response.statusCode == 201) {
        developer.log('[API] Đã lưu bản ghi sức khỏe lên Django thành công!', name: 'ApiService');
        return true;
      } else {
        developer.log('[API] Lỗi server: ${response.body}', name: 'ApiService', level: 900);
        return false;
      }
    } catch (e, st) {
      developer.log('[API] Lỗi kết nối API: $e', name: 'ApiService', level: 1000, error: e, stackTrace: st);
      return false;
    }
  }
}