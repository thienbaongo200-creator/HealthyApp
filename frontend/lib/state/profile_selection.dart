import 'package:flutter/material.dart';

bool isCurrentUserProfile(Map<String, dynamic> profile) =>
    profile['is_current_user'] == true;

String profileDisplayName(Map<String, dynamic> profile) {
  if (isCurrentUserProfile(profile)) return 'Tôi';
  final name = profile['full_name']?.toString().trim() ?? '';
  return name.isEmpty ? 'Thành viên' : name;
}

String? profileRoleLabel(Map<String, dynamic> profile) {
  if (isCurrentUserProfile(profile)) return null;

  final viewerRole = profile['viewer_role']?.toString();
  final householdRole = profile['household_role']?.toString();
  final role = viewerRole != null && viewerRole != 'OWNER'
      ? viewerRole
      : householdRole ?? viewerRole;
  return const {
    'OWNER': 'Chủ hộ',
    'CAREGIVER': 'Người chăm sóc',
    'MEMBER': 'Thành viên',
  }[role];
}

String profileRelationshipLabel(Map<String, dynamic> profile) {
  if (isCurrentUserProfile(profile)) return 'Chủ hồ sơ';

  if (profile['profile_type'] != 'SELF') {
    return const {
          'FATHER': 'Bố',
          'MOTHER': 'Mẹ',
          'SPOUSE': 'Vợ/Chồng',
          'CHILD': 'Con',
          'SIBLING': 'Anh/Chị/Em',
          'OTHER': 'Khác',
        }[profile['relation_type']?.toString()] ??
        'Chưa xác định';
  }

  final householdRole = profile['household_role']?.toString();
  if (householdRole == 'CAREGIVER') return 'Người chăm sóc';
  if (householdRole == 'MEMBER') return 'Thành viên gia đình';
  if (householdRole == 'OWNER') return 'Chủ hộ';

  final viewerRole = profile['viewer_role']?.toString();
  if (viewerRole == 'CAREGIVER') return 'Người chăm sóc';
  if (viewerRole == 'MEMBER') return 'Thành viên gia đình';
  return 'Thành viên gia đình';
}

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
      final self = _profiles.where(isCurrentUserProfile).firstOrNull;
      _selectedProfileId = (self ?? _profiles.firstOrNull)?['id']?.toString();
    }
    notifyListeners();
  }

  void selectProfileId(String profileId) {
    if (!_profiles.any((profile) => profile['id']?.toString() == profileId)) {
      return;
    }
    if (_selectedProfileId == profileId) return;
    _selectedProfileId = profileId;
    notifyListeners();
  }
}

class ProfileSelectionScope
    extends InheritedNotifier<ProfileSelectionController> {
  const ProfileSelectionScope({
    required ProfileSelectionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ProfileSelectionController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ProfileSelectionScope>();
    assert(
      scope != null,
      'ProfileSelectionScope is missing above this context.',
    );
    return scope!.notifier!;
  }
}
