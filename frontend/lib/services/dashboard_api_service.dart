import '../core/network/api_client.dart';
import '../models/dashboard_preference.dart';

class DashboardApiService {
  final ApiClient _client;
  DashboardApiService({ApiClient? client}) : _client = client ?? ApiClient();

  Future<DashboardPreference> load(String profileId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      'dashboard/preferences/', queryParameters: {'profile_id': profileId});
    return DashboardPreference.fromJson(response.data!);
  }

  Future<DashboardPreference> save(DashboardPreference preference) async {
    final response = await _client.dio.put<Map<String, dynamic>>(
      'dashboard/preferences/', data: preference.toJson());
    return DashboardPreference.fromJson(response.data!);
  }
}
