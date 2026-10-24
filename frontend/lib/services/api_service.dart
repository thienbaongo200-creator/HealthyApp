import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/network/token_storage.dart';
import 'authenticated_http.dart';
import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

class BatchSyncResult {
  const BatchSyncResult({
    required this.acknowledgedKeys,
    required this.rejectedKeys,
    required this.retryKeys,
  });

  /// Keys that can be removed from the local queue: created or already present.
  final Set<String> acknowledgedKeys;

  /// Terminal validation failures; log/report these, then remove from the queue.
  final Set<String> rejectedKeys;

  /// Temporary server/database failures; keep these queued for a later retry.
  final Set<String> retryKeys;
}

class ApiService {
  static const String baseUrl = apiBaseUrl;
  static const Duration _loginTimeout = Duration(seconds: 15);

  static final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  static Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    bool retryUnauthorized = true,
  }) => _httpClient.request(
    method,
    uri,
    headers: headers,
    body: body,
    retryUnauthorized: retryUnauthorized,
  );

  static String? _token;
  static final ApiService instance = ApiService();

  static Future<Map<String, String>> _authHeaders() async {
    final token = _token ?? await TokenStorage.getAccessToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _send(
        'POST',
        Uri.parse('$baseUrl/auth/register/'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
        }),
        retryUnauthorized: false,
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
      final response = await _httpClient.request(
        'PATCH',
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

  Future<String> login(String account, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login/');
    developer.log('Login request to $uri', name: 'ApiService');

    final response = await _httpClient.request(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
      retryUnauthorized: false,
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
    final refreshToken = decoded['refresh'];
    if (refreshToken is String && refreshToken.isNotEmpty) {
      await TokenStorage.saveRefreshToken(refreshToken);
    }
    await TokenStorage.saveAccessToken(accessToken);
    _token = accessToken;
    return accessToken;
  }

  Future<String?> loginWithGoogle(String accessToken) async {
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
      retryUnauthorized: false,
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access'] as String? ?? data['token'] as String?;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await TokenStorage.saveAccessToken(token);
  }

  static Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final response = await _httpClient.send((accessToken) async {
          final currentRefreshToken = await TokenStorage.getRefreshToken();
          final headers = AuthenticatedHttpClient.headersWithToken(const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          }, accessToken);
          return http.post(
            Uri.parse('$baseUrl/auth/logout/'),
            headers: headers,
            body: jsonEncode({'refresh': currentRefreshToken ?? refreshToken}),
          );
        });
        if (response.statusCode != 205 &&
            response.statusCode != 200 &&
            response.statusCode != 401) {
          throw ApiException(
            response.statusCode,
            'Không thể đăng xuất khỏi máy chủ.',
          );
        }
      }
    } finally {
      _token = null;
      await TokenStorage.clearTokens();
    }
  }

  static Future<bool> sendHealthData({
    required int heartRate,
    required int steps,
    required double calories,
  }) async {
    try {
      final response = await _httpClient.request(
        'POST',
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
          '[API] Health request failed with HTTP ${response.statusCode}.',
          name: 'ApiService',
          level: 900,
        );
        return false;
      }
    } catch (_) {
      developer.log(
        '[API] Health request could not be completed.',
        name: 'ApiService',
        level: 1000,
      );
      return false;
    }
  }

  static Future<BatchSyncResult?> sendHealthMeasurements(
    List<Map<String, dynamic>> measurements, {
    required String profileId,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _httpClient.request(
        'POST',
        Uri.parse('$baseUrl/health-measurements/batch/'),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode({
          'measurements': measurements,
          'profile_id': profileId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        final rawResults = payload is Map<String, dynamic>
            ? payload['results']
            : null;
        final acknowledged = <String>{};
        final rejected = <String>{};
        final retry = <String>{};

        if (rawResults is List) {
          for (final raw in rawResults) {
            if (raw is! Map<String, dynamic>) continue;
            final key = raw['idempotency_key']?.toString();
            if (key == null || key.isEmpty) continue;
            switch (raw['status']) {
              case 'ĐÃ_TẠO':
              case 'TRÙNG_LẶP':
                acknowledged.add(key);
                break;
              case 'BỊ_TỪ_CHỐI':
                rejected.add(key);
                developer.log(
                  '[Batch] A measurement was rejected by validation.',
                  name: 'ApiService',
                  level: 900,
                );
                break;
              case 'CẦN_THỬ_LẠI':
              default:
                retry.add(key);
                break;
            }
          }
        } else if (response.statusCode == 201) {
          // Compatibility with older servers that returned no per-item results.
          acknowledged.addAll(
            measurements
                .map((item) => item['idempotency_key']?.toString())
                .whereType<String>(),
          );
        }

        final knownKeys = {...acknowledged, ...rejected, ...retry};
        for (final measurement in measurements) {
          final key = measurement['idempotency_key']?.toString();
          if (key != null && key.isNotEmpty && !knownKeys.contains(key)) {
            retry.add(key);
          }
        }
        return BatchSyncResult(
          acknowledgedKeys: acknowledged,
          rejectedKeys: rejected,
          retryKeys: retry,
        );
      }
      developer.log(
        '[API] Batch request failed with HTTP ${response.statusCode}.',
        name: 'ApiService',
        level: 900,
      );
      return null;
    } catch (_) {
      developer.log(
        '[API] Batch request could not be completed.',
        name: 'ApiService',
        level: 1000,
      );
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHealthMeasurements({
    String? profileId,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/medical/measurements/').replace(
      queryParameters: profileId == null ? null : {'profile_id': profileId},
    );
    final records = <Map<String, dynamic>>[];
    final visitedPages = <Uri>{};
    var nextPage = uri;

    while (true) {
      if (!visitedPages.add(nextPage)) {
        throw const FormatException(
          'Measurement API returned a pagination cycle.',
        );
      }

      final response = await _httpClient.request(
        'GET',
        nextPage,
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode,
          'Không thể tải nhật ký sức khỏe.',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is List) {
        records.addAll(payload.whereType<Map<String, dynamic>>());
        break;
      }
      if (payload is! Map<String, dynamic> || payload['results'] is! List) {
        throw const FormatException(
          'Measurement response must contain a list.',
        );
      }
      records.addAll(
        (payload['results'] as List).whereType<Map<String, dynamic>>(),
      );

      final next = payload['next'];
      if (next == null || next == '') break;
      if (next is! String) {
        throw const FormatException(
          'Measurement pagination URL must be a string.',
        );
      }

      final resolvedNext = nextPage.resolve(next);
      final apiUri = Uri.parse(baseUrl);
      final apiPath = apiUri.path.replaceFirst(RegExp(r'/$'), '');
      if (resolvedNext.scheme != apiUri.scheme ||
          resolvedNext.host != apiUri.host ||
          resolvedNext.port != apiUri.port ||
          !resolvedNext.path.startsWith('$apiPath/')) {
        throw const FormatException(
          'Measurement pagination URL must remain within the configured API.',
        );
      }
      nextPage = resolvedNext;
    }

    return records.toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> fetchProfiles() async {
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$baseUrl/profiles/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không thể tải hồ sơ gia đình.');
    }
    final payload = jsonDecode(response.body);
    final profiles = payload is List
        ? payload
        : payload is Map<String, dynamic>
        ? payload['results']
        : null;
    if (profiles is! List) {
      throw const FormatException('Profile response must contain a list.');
    }
    return profiles.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> fetchHouseholds() async {
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$baseUrl/households/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Không thể tải danh sách hộ gia đình.',
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const FormatException('Household response must be a list.');
    }
    return payload.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<Map<String, dynamic>> inviteHouseholdMember({
    required String householdId,
    required String email,
    String role = 'MEMBER',
    String shareLevel = 'VIEW_ONLY',
  }) async {
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/households/$householdId/members/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({
        'email': email,
        'role': role,
        'share_level': shareLevel,
      }),
    );
    if (response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể gửi lời mời.'),
      );
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invitation response must be an object.');
    }
    return payload;
  }

  static Future<List<Map<String, dynamic>>> fetchHouseholdInvitations() async {
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$baseUrl/households/invitations/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể tải lời mời.'),
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const FormatException('Invitation response must be a list.');
    }
    return payload.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<void> respondToHouseholdInvitation({
    required String memberId,
    required String action,
  }) async {
    if (action != 'accept' && action != 'decline') {
      throw ArgumentError.value(action, 'action', 'Must be accept or decline.');
    }
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/households/invitations/$memberId/respond/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({'action': action}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể phản hồi lời mời.'),
      );
    }
  }

  static Future<void> leaveHousehold(String householdId) async {
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/households/$householdId/leave/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: '{}',
    );
    if (response.statusCode != 204) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể rời hộ gia đình.'),
      );
    }
  }

  static Future<Map<String, dynamic>> createDependentProfile({
    required String fullName,
    required String relationType,
    String householdRole = 'MEMBER',
    String? dateOfBirth,
  }) async {
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/profiles/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({
        'profile_type': 'DEPENDENT',
        'full_name': fullName,
        'relation_type': relationType,
        'household_role': householdRole,
        'date_of_birth': ?dateOfBirth,
      }),
    );
    if (response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể thêm hồ sơ thành viên.'),
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfileDetails({
    required String profileId,
    required String fullName,
    required String relationType,
    String? householdRole,
    String? dateOfBirth,
  }) async {
    final response = await _httpClient.request(
      'PATCH',
      Uri.parse('$baseUrl/profiles/$profileId/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({
        'full_name': fullName,
        'relation_type': relationType,
        ...?(householdRole == null ? null : {'household_role': householdRole}),
        'date_of_birth': dateOfBirth,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể cập nhật hồ sơ thành viên.'),
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<void> archiveProfile(String profileId) async {
    final response = await _httpClient.request(
      'DELETE',
      Uri.parse('$baseUrl/profiles/$profileId/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể xóa hồ sơ thành viên.'),
      );
    }
  }

  static Future<bool> fetchAiConsent() async {
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$baseUrl/auth/ai-consent/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không thể tải tùy chọn AI.');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['ai_consent'] is! bool) {
      throw const FormatException(
        'AI consent response must contain a boolean.',
      );
    }
    return payload['ai_consent'] as bool;
  }

  static Future<bool> updateAiConsent(bool consent) async {
    final response = await _httpClient.request(
      'PATCH',
      Uri.parse('$baseUrl/auth/ai-consent/'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({'ai_consent': consent}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể cập nhật tùy chọn AI.'),
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['ai_consent'] is! bool) {
      throw const FormatException(
        'AI consent response must contain a boolean.',
      );
    }
    return payload['ai_consent'] as bool;
  }

  static Future<List<Map<String, dynamic>>> fetchMedicalDocuments({
    String? profileId,
  }) async {
    final uri = Uri.parse('$baseUrl/medical-records/documents/').replace(
      queryParameters: profileId == null ? null : {'profile_id': profileId},
    );
    final response = await _httpClient.request(
      'GET',
      uri,
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không thể tải hồ sơ y tế.');
    }

    final payload = jsonDecode(response.body);
    final documents = payload is List
        ? payload
        : payload is Map<String, dynamic>
        ? payload['results']
        : null;
    if (documents is! List) {
      throw const FormatException(
        'Medical document response must contain a list.',
      );
    }
    return documents.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<Map<String, dynamic>> uploadMedicalDocument({
    required String profileId,
    required String documentType,
    required String title,
    required String fileName,
    required Uint8List fileBytes,
    String description = '',
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/medical-records/documents/'),
          )
          ..headers.addAll(await _authHeaders())
          ..fields.addAll({
            'profile_id': profileId,
            'document_type': documentType,
            'title': title,
            'description': description,
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
          );
    final streamedResponse = await request.send().timeout(_loginTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể tải tài liệu lên.'),
      );
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Medical document response must be an object.',
      );
    }
    return payload;
  }

  static Future<Uint8List> downloadMedicalDocument(String documentId) async {
    final response = await _httpClient.request(
      'GET',
      Uri.parse('$baseUrl/medical-records/documents/$documentId/download/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể tải tài liệu xuống.'),
      );
    }
    return response.bodyBytes;
  }

  static Future<void> deleteMedicalDocument(String documentId) async {
    final response = await _httpClient.request(
      'DELETE',
      Uri.parse('$baseUrl/medical-records/documents/$documentId/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 204) {
      throw ApiException(
        response.statusCode,
        _responseMessage(response.body, 'Không thể xóa tài liệu.'),
      );
    }
  }

  static String _responseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail =
            decoded['detail'] ?? decoded['file'] ?? decoded['profile_id'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) return detail.first.toString();
      }
    } on FormatException {
      if (body.trim().isNotEmpty) return body;
    }
    return fallback;
  }

  /// Persist a manually entered measurement using the same API as device data.
  static Future<void> createManualMeasurements(
    List<Map<String, dynamic>> measurements, {
    String? profileId,
  }) async {
    final headers = await _authHeaders();
    final response = await _httpClient.request(
      'POST',
      Uri.parse('$baseUrl/medical/measurements/batch/'),
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode({
        'measurements': measurements,
        'profile_id': ?profileId,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(response.statusCode, 'Khong the luu chi so suc khoe.');
    }
  }
}
