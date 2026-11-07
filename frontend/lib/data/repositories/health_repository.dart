import 'dart:developer' as developer;

import '../../core/network/api_client.dart';

class HealthRepository {
  final ApiClient _apiClient = ApiClient();

  // Gửi gói đo lường hàng loạt (Đồng bộ từ Wear OS hoặc App)
  Future<bool> sendBatchMeasurements(List<Map<String, dynamic>> measurements) async {
    try {
      final response = await _apiClient.dio.post(
        'medical/measurements/batch/',
        data: {'measurements': measurements},
      );
      return response.statusCode == 201;
    } catch (e) {
      developer.log('Lỗi gửi batch đo lường: $e', name: 'HealthRepository');
      return false;
    }
  }

  // Tạo và lưu nhận định rủi ro qua API AIInsight hiện hành.
  Future<Map<String, dynamic>?> fetchAiRiskAssessment(String profileId) async {
    try {
      final response = await _apiClient.dio.post(
        'ai-insights/analyze/',
        data: {'profile_id': profileId},
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      developer.log('Lỗi lấy dữ liệu đánh giá rủi ro AI: $e', name: 'HealthRepository');
    }
    return null;
  }
}
