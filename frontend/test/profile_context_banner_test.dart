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
  });
}
