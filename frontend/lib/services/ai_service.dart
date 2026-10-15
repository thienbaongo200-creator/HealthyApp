import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class AiApiService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> assessRisk({
    required String profileId,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final response = await http.get(
      Uri.parse('$apiBaseUrl/ai/assess-risk/$profileId/'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không thể tải đánh giá nguy cơ (HTTP ${response.statusCode}).',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Risk API phải trả về JSON object.');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    final token = await _storage.read(key: 'access_token');
    final authorization = token == null ? null : 'Bearer $token';
    final response = await http.get(
      Uri.parse('$apiBaseUrl/profiles/'),
      headers: {
        'Accept': 'application/json',
        'Authorization': ?authorization,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Không thể tải hồ sơ (HTTP ${response.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final results = body is List ? body : (body is Map ? body['results'] : null);
    if (results is! List) throw const FormatException('Profile API phải trả về danh sách.');
    return results.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String profileId,
    required String message,
    String? conversationId,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final authorization = token == null ? null : 'Bearer $token';
    final url = Uri.parse('$apiBaseUrl/ai/chat/$profileId/');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': ?authorization,
      },
      body: jsonEncode({
        'message': message,
        'conversation_id': ?conversationId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) return data;
      throw const FormatException('Chat API phải trả về JSON object.');
    } else {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Không thể gửi tin nhắn (HTTP ${response.statusCode}): $body');
    }
  }
}
