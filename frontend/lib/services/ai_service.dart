import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'authenticated_http.dart';
import 'api_config.dart';

class AiFallbackException implements Exception {
  const AiFallbackException({
    required this.conversationId,
    required this.message,
    required this.fallbackReply,
  });

  final String? conversationId;
  final String message;
  final String fallbackReply;

  @override
  String toString() => message;
}

class RiskAssessmentResult {
  const RiskAssessmentResult({
    required this.riskLevel,
    required this.analyzedCount,
    required this.warnings,
    required this.recommendation,
    required this.recommendations,
    required this.generatedBy,
    required this.interpretation,
    this.profileId,
  });

  final String? profileId;
  final String riskLevel;
  final int analyzedCount;
  final List<String> warnings;
  final String recommendation;
  final List<String> recommendations;
  final String generatedBy;
  final String? interpretation;

  factory RiskAssessmentResult.fromJson(Map<String, dynamic> json) {
    final riskLevel = json['risk_level'];
    if (riskLevel is! String ||
        !const {'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'}.contains(riskLevel)) {
      throw const FormatException('Risk API trả về risk_level không hợp lệ.');
    }

    final analyzedCount = json['analyzed_count'] ?? 0;
    if (analyzedCount is! num) {
      throw const FormatException(
        'Risk API trả về analyzed_count không hợp lệ.',
      );
    }

    List<String> stringList(String key) {
      final value = json[key] ?? const <dynamic>[];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Risk API trả về $key không hợp lệ.');
      }
      return List<String>.unmodifiable(value.cast<String>());
    }

    final recommendation = json['recommendation'] ?? '';
    final profileId = json['profile_id'];
    final generatedBy = json['generated_by'] ?? 'RULE_ONLY';
    final interpretation = json['interpretation'];
    if (recommendation is! String ||
        (profileId != null && profileId is! String) ||
        generatedBy is! String ||
        !const {'RULE_ONLY', 'RULE_AND_AI'}.contains(generatedBy) ||
        (interpretation != null && interpretation is! String)) {
      throw const FormatException('Risk API trả về trường không hợp lệ.');
    }

    return RiskAssessmentResult(
      profileId: profileId as String?,
      riskLevel: riskLevel,
      analyzedCount: analyzedCount.toInt(),
      warnings: stringList('warnings'),
      recommendation: recommendation,
      recommendations: stringList('recommendations'),
      generatedBy: generatedBy,
      interpretation: interpretation as String?,
    );
  }
}

class AiApiService {
  final _storage = const FlutterSecureStorage();
  final _httpClient = AuthenticatedHttpClient();

  Future<RiskAssessmentResult> assessRisk({required String profileId}) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$apiBaseUrl/ai/assess-risk/$profileId/'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    return parseRiskResponse(
      statusCode: response.statusCode,
      payload: jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }

  static RiskAssessmentResult parseRiskResponse({
    required int statusCode,
    required Object? payload,
  }) {
    final body = payload;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Risk API phải trả về JSON object.');
    }
    if (statusCode == 422 && body['risk_level'] == 'UNKNOWN') {
      return RiskAssessmentResult.fromJson(body);
    }
    if (statusCode != 200) {
      throw Exception('Không thể tải đánh giá nguy cơ (HTTP $statusCode).');
    }
    return RiskAssessmentResult.fromJson(body);
  }

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    final token = await _storage.read(key: 'access_token');
    final authorization = token == null ? null : 'Bearer $token';
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$apiBaseUrl/profiles/'),
      headers: {'Accept': 'application/json', 'Authorization': ?authorization},
    );
    if (response.statusCode != 200) {
      throw Exception('Không thể tải hồ sơ (HTTP ${response.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final results = body is List
        ? body
        : (body is Map ? body['results'] : null);
    if (results is! List) {
      throw const FormatException('Profile API phải trả về danh sách.');
    }
    return results.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchConversations({
    required String profileId,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _httpClient.request(
      'GET',
      Uri.parse(
        '$apiBaseUrl/ai/conversations/',
      ).replace(queryParameters: {'profile': profileId}),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không thể tải lịch sử hội thoại (HTTP ${response.statusCode}).',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final results = body is List
        ? body
        : body is Map<String, dynamic>
        ? body['results']
        : null;
    if (results is! List) {
      throw const FormatException('Conversation API phải trả về danh sách.');
    }
    return results.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchConversationMessages({
    required String conversationId,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$apiBaseUrl/ai/conversations/$conversationId/messages/'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Không thể tải tin nhắn hội thoại (HTTP ${response.statusCode}).',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final results = body is List
        ? body
        : body is Map<String, dynamic>
        ? body['results']
        : null;
    if (results is! List) {
      throw const FormatException('Message API phải trả về danh sách.');
    }
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

    final response = await _httpClient.request(
      'POST',
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
      if (response.statusCode == 503) {
        final payload = jsonDecode(body);
        if (payload is Map<String, dynamic> &&
            payload['fallback'] == true &&
            payload['retryable'] == true &&
            (payload['conversation_id'] == null ||
                payload['conversation_id'] is String) &&
            payload['message'] is String &&
            payload['fallback_reply'] is String) {
          throw AiFallbackException(
            conversationId: payload['conversation_id'] as String?,
            message: payload['message'] as String,
            fallbackReply: payload['fallback_reply'] as String,
          );
        }
      }
      throw Exception(
        'Không thể gửi tin nhắn (HTTP ${response.statusCode}): $body',
      );
    }
  }
}
