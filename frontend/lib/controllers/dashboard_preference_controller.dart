import 'package:flutter/foundation.dart';
import '../models/dashboard_preference.dart';
import '../repositories/dashboard_repository.dart';
import '../services/error_mapper.dart';

class DashboardPreferenceController extends ChangeNotifier {
  final DashboardRepository repository;
  DashboardPreferenceController({DashboardRepository? repository})
      : repository = repository ?? DashboardRepository();

  DashboardPreference? preference;
  bool loading = false;
  bool saving = false;
  String? error;
  bool _isDisposed = false;
  int _requestGeneration = 0;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  void clear() {
    if (_isDisposed) return;
    _requestGeneration++;
    preference = null;
    loading = false;
    saving = false;
    error = null;
    _notifyIfActive();
  }

  Future<void> loadPreference(String profileId) async {
    if (_isDisposed) return;
    final generation = ++_requestGeneration;
    loading = true;
    error = null;
    _notifyIfActive();
    try {
      final result = await repository.loadPreference(profileId);
      if (_isDisposed || generation != _requestGeneration) return;
      preference = result;
    } catch (e) {
      if (_isDisposed || generation != _requestGeneration) return;
      error = ErrorMapper.toUserMessage(e.toString());
      preference = DashboardPreference(
        profileId: profileId,
        selectedMetrics: List.of(DashboardPreference.defaults),
        metricOrder: List.of(DashboardPreference.defaults),
      );
    } finally {
      if (!_isDisposed && generation == _requestGeneration) {
        loading = false;
        _notifyIfActive();
      }
    }
  }

  Future<bool> savePreference(List<String> selected, List<String> order) async {
    if (_isDisposed) return false;
    final current = preference;
    if (current == null) return false;
    final generation = ++_requestGeneration;
    saving = true;
    _notifyIfActive();
    try {
      final result = await repository.savePreference(
        DashboardPreference(
          profileId: current.profileId,
          selectedMetrics: List.of(selected),
          metricOrder: List.of(order),
        ),
      );
      if (_isDisposed || generation != _requestGeneration) return false;
      preference = result;
      return true;
    } catch (e) {
      if (_isDisposed || generation != _requestGeneration) return false;
      error = ErrorMapper.toUserMessage(e.toString());
      return false;
    } finally {
      if (!_isDisposed && generation == _requestGeneration) {
        saving = false;
        _notifyIfActive();
      }
    }
  }

  Future<bool> restoreDefault() => savePreference(
        List.of(DashboardPreference.defaults),
        List.of(DashboardPreference.defaults),
      );

  List<String> reorderMetrics(List<String> metrics, int oldIndex, int newIndex) {
    final result = List<String>.of(metrics);
    if (newIndex > oldIndex) newIndex--;
    final item = result.removeAt(oldIndex);
    result.insert(newIndex, item);
    return result;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
