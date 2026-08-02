import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WatchSenderService {
  static const String _defaultUrl = 'http://10.0.2.2:8080/sync';

  Future<bool> sendDataToPhone(Map<String, dynamic> healthData) async {
    try {
      debugPrint('[Wear OS] 📤 Gửi dữ liệu: $healthData');

      final response = await http
          .post(
            Uri.parse(_defaultUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(healthData),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        debugPrint('[Wear OS] ✅ Phone đã nhận thành công!');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Wear OS] ❌ Lỗi kết nối: $e');
      return false;
    }
  }
}
