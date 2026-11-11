import '../models/dashboard_preference.dart';
import '../services/dashboard_api_service.dart';

class DashboardRepository {
  final DashboardApiService api;
  DashboardRepository({DashboardApiService? api}) : api = api ?? DashboardApiService();
  Future<DashboardPreference> loadPreference(String id) => api.load(id);
  Future<DashboardPreference> savePreference(DashboardPreference preference) => api.save(preference);
}
