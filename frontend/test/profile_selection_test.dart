import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/state/profile_selection.dart';

void main() {
  test('labels only the authenticated account profile as Tôi', () {
    final currentUserProfile = {
      'id': 'current-user',
      'profile_type': 'SELF',
      'is_current_user': true,
      'full_name': 'Nguyen An',
      'household_role': 'OWNER',
    };
    final invitedOwnerProfile = {
      'id': 'invited-owner',
      'profile_type': 'SELF',
      'is_current_user': false,
      'full_name': 'Tran Binh',
      'household_role': 'OWNER',
      'viewer_role': 'CAREGIVER',
    };
    final caregiverProfile = {
      'id': 'caregiver',
      'profile_type': 'DEPENDENT',
      'is_current_user': false,
      'full_name': 'Le Chi',
      'household_role': 'CAREGIVER',
      'viewer_role': 'OWNER',
    };

    expect(profileDisplayName(currentUserProfile), 'Tôi');
    expect(profileRoleLabel(currentUserProfile), isNull);
    expect(profileDisplayName(invitedOwnerProfile), 'Tran Binh');
    expect(profileRoleLabel(invitedOwnerProfile), 'Người chăm sóc');
    expect(profileDisplayName(caregiverProfile), 'Le Chi');
    expect(profileRoleLabel(caregiverProfile), 'Người chăm sóc');
  });

  test('profile selection defaults to the current account profile', () {
    final controller = ProfileSelectionController()
      ..setProfiles([
        {
          'id': 'shared-self',
          'profile_type': 'SELF',
          'is_current_user': false,
          'full_name': 'Shared account',
          'viewer_role': 'MEMBER',
        },
        {
          'id': 'current-self',
          'profile_type': 'SELF',
          'is_current_user': true,
          'full_name': 'Current account',
        },
      ]);

    expect(controller.selectedProfileId, 'current-self');
    expect(profileDisplayName(controller.selectedProfile!), 'Tôi');
    controller.dispose();
  });
}
