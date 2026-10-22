import 'package:flutter/material.dart';

/// App-wide selection context. Backend permissions remain authoritative.
class ProfileSelectionController extends ChangeNotifier {
  List<Map<String, dynamic>> _profiles = const [];
  String? _selectedProfileId;

  List<Map<String, dynamic>> get profiles => List.unmodifiable(_profiles);
  String? get selectedProfileId => _selectedProfileId;
  Map<String, dynamic>? get selectedProfile {
    for (final profile in _profiles) {
      if (profile['id']?.toString() == _selectedProfileId) return profile;
    }
    return null;
  }

  void setProfiles(List<Map<String, dynamic>> profiles) {
    _profiles = List.unmodifiable(profiles);
    final currentIsValid = _profiles.any(
      (profile) => profile['id']?.toString() == _selectedProfileId,
    );
    if (!currentIsValid) {
      final self = _profiles.where((profile) => profile['profile_type'] == 'SELF').firstOrNull;
      _selectedProfileId = (self ?? _profiles.firstOrNull)?['id']?.toString();
    }
    notifyListeners();
  }

  void selectProfileId(String profileId) {
    if (!_profiles.any((profile) => profile['id']?.toString() == profileId)) return;
    if (_selectedProfileId == profileId) return;
    _selectedProfileId = profileId;
    notifyListeners();
  }
}

class ProfileSelectionScope extends InheritedNotifier<ProfileSelectionController> {
  const ProfileSelectionScope({
    required ProfileSelectionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ProfileSelectionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileSelectionScope>();
    assert(scope != null, 'ProfileSelectionScope is missing above this context.');
    return scope!.notifier!;
  }
}
