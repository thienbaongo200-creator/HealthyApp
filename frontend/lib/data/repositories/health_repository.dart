import 'package:dio/dio.dart';
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
      print("Lỗi gửi batch đo lường: $e");
      return false;
    }
  }

  // Lấy kết quả đánh giá rủi ro sức khỏe từ AI Service
  Future<Map<String, dynamic>?> fetchAiRiskAssessment(String profileId) async {
    try {
      final response = await _apiClient.dio.get('ai/assess-risk/$profileId/');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print("Lỗi lấy dữ liệu đánh giá rủi ro AI: $e");
    }
    return null;
  }
}