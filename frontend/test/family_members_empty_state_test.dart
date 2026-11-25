import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/home/family_members_screen.dart';

void main() {
  testWidgets('empty household state offers household and dependent actions', (
    tester,
  ) async {
    var householdPressed = false;
    var dependentPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HouseholdEmptyState(
            onCreateHousehold: () async {
              householdPressed = true;
              return true;
            },
            onCreateDependent: () async {
              dependentPressed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Chưa có hộ gia đình'), findsOneWidget);
    expect(find.text('Tạo hộ gia đình'), findsOneWidget);
    expect(find.text('Thêm hồ sơ phụ thuộc'), findsOneWidget);

    await tester.tap(find.text('Tạo hộ gia đình'));
    await tester.pump();
    expect(householdPressed, isTrue);

    await tester.tap(find.text('Thêm hồ sơ phụ thuộc'));
    await tester.pump();
    expect(dependentPressed, isTrue);
  });

  testWidgets('empty invitation area has an explicit empty message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PendingInvitationsEmptyState()),
      ),
    );

    expect(
      find.text('Hiện không có lời mời nào đang chờ.'),
      findsOneWidget,
    );
  });
}
