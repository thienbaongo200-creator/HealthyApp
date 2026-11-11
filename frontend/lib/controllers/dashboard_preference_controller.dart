import 'package:flutter/foundation.dart';
import '../models/dashboard_preference.dart';
import '../repositories/dashboard_repository.dart';

class DashboardPreferenceController extends ChangeNotifier {
  final DashboardRepository repository;
  DashboardPreferenceController({DashboardRepository? repository}) : repository = repository ?? DashboardRepository();
  DashboardPreference? preference;
  bool loading = false;
  bool saving = false;
  String? error;

  void clear() {
    preference = null;
    error = null;
    notifyListeners();
  }

  Future<void> loadPreference(String profileId) async {
    loading = true; error = null; notifyListeners();
    try { preference = await repository.loadPreference(profileId); }
    catch (e) { error = e.toString(); preference = DashboardPreference(profileId: profileId, selectedMetrics: List.of(DashboardPreference.defaults), metricOrder: List.of(DashboardPreference.defaults)); }
    finally { loading = false; notifyListeners(); }
  }

  Future<bool> savePreference(List<String> selected, List<String> order) async {
    final current = preference;
    if (current == null) return false;
    saving = true; notifyListeners();
    try { preference = await repository.savePreference(DashboardPreference(profileId: current.profileId, selectedMetrics: List.of(selected), metricOrder: List.of(order))); return true; }
    catch (e) { error = e.toString(); return false; }
    finally { saving = false; notifyListeners(); }
  }

  Future<bool> restoreDefault() => savePreference(List.of(DashboardPreference.defaults), List.of(DashboardPreference.defaults));

  List<String> reorderMetrics(List<String> metrics, int oldIndex, int newIndex) {
    final result = List<String>.of(metrics);
    if (newIndex > oldIndex) newIndex--;
    final item = result.removeAt(oldIndex); result.insert(newIndex, item);
    return result;
  }
}
