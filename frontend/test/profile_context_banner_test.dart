import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/widgets/profile_context_banner.dart';

void main() {
  testWidgets('shows caregiver role and screening permissions', (
    WidgetTester tester,
  ) async {
    final controller = ProfileSelectionController()
      ..setProfiles([
        {
          'id': 'dependent-1',
          'profile_type': 'DEPENDENT',
          'full_name': 'Family member',
          'relation_type': 'FATHER',
          'household_role': 'CAREGIVER',
        },
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSelectionScope(
          controller: controller,
          child: const Scaffold(body: ProfileContextBanner()),
        ),
      ),
    );

    expect(
      find.text(
        'Đang xem với vai trò: Người chăm sóc · Quyền hạn: Xem chỉ số & Kết quả sàng lọc',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Đang xem hồ sơ của: Family member · Quan hệ: Bố'),
      findsOneWidget,
    );
  });

  testWidgets('shows invited SELF profile household role, not owner relation', (
    WidgetTester tester,
  ) async {
    final controller = ProfileSelectionController()
      ..setProfiles([
        {
          'id': 'invited-member',
          'profile_type': 'SELF',
          'is_current_user': false,
          'full_name': 'member',
          'household_role': 'MEMBER',
          'viewer_role': 'OWNER',
          'share_level': 'VIEW_ONLY',
        },
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSelectionScope(
          controller: controller,
          child: const Scaffold(body: ProfileContextBanner()),
        ),
      ),
    );

    expect(
      find.text('Đang xem hồ sơ của: member · Quan hệ: Thành viên gia đình'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Đang xem với vai trò: Thành viên · Quyền hạn: Chỉ xem dữ liệu được Owner chia sẻ',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows dependent profile saved relation', (
    WidgetTester tester,
  ) async {
    final controller = ProfileSelectionController()
      ..setProfiles([
        {
          'id': 'dependent-child',
          'profile_type': 'DEPENDENT',
          'is_current_user': false,
          'full_name': 'An',
          'relation_type': 'CHILD',
          'household_role': 'MEMBER',
          'viewer_role': 'OWNER',
        },
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSelectionScope(
          controller: controller,
          child: const Scaffold(body: ProfileContextBanner()),
        ),
      ),
    );

    expect(find.text('Đang xem hồ sơ của: An · Quan hệ: Con'), findsOneWidget);
  });
}
