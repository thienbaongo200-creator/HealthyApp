import 'package:flutter/material.dart';

bool isCurrentUserProfile(Map<String, dynamic> profile) =>
    profile['is_current_user'] == true;

String? profileGenderLabel(dynamic value) {
  final gender = value?.toString().trim() ?? '';
  if (gender.isEmpty) return null;
  switch (gender.toLowerCase()) {
    case 'male':
    case 'm':
      return 'Nam';
    case 'female':
    case 'f':
      return 'Nữ';
    case 'khác':
    case 'other':
    case 'unknown':
      return 'Khác';
    default:
      return gender;
  }
}

String? profileDemographicSummary(
  Map<String, dynamic> profile, {
  DateTime? today,
}) {
  final details = <String>[];
  final gender = profileGenderLabel(profile['gender']);
  if (gender != null) details.add(gender);

  final birthDate = DateTime.tryParse(
    profile['date_of_birth']?.toString() ?? '',
  );
  if (birthDate != null) {
    final currentDate = today ?? DateTime.now();
    var age = currentDate.year - birthDate.year;
    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month &&
            currentDate.day < birthDate.day)) {
      age--;
    }
    if (age >= 0) details.add('$age tuổi');
  }
  return details.isEmpty ? null : details.join(' • ');
}

String profileDemographicSubtitle(
  Map<String, dynamic> profile, {
  DateTime? today,
}) {
  final gender = profileGenderLabel(profile['gender']) ?? 'Chưa rõ giới tính';
  final birthDate = DateTime.tryParse(
    profile['date_of_birth']?.toString() ?? '',
  );
  var ageLabel = 'Chưa cập nhật tuổi';
  if (birthDate != null) {
    final currentDate = today ?? DateTime.now();
    var age = currentDate.year - birthDate.year;
    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month &&
            currentDate.day < birthDate.day)) {
      age--;
    }
    if (age >= 0) ageLabel = '$age tuổi';
  }
  return '$gender • $ageLabel';
}

List<Map<String, dynamic>> normalizeProfiles(
  List<Map<String, dynamic>> profiles,
) {
  final result = <Map<String, dynamic>>[];
  var hasCurrentSelf = false;
  for (final profile in profiles) {
    if (isCurrentUserProfile(profile)) {
      if (hasCurrentSelf) continue;
      hasCurrentSelf = true;
    }
    result.add(profile);
  }
  return result;
}

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
    _profiles = List.unmodifiable(normalizeProfiles(profiles));
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
