import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/home/dashboard_screen.dart';
import 'package:frontend/state/profile_selection.dart'; // Import state quản lý profile
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Health dashboard loads and shows metric cards', (
    WidgetTester tester,
  ) async {
    // Bọc DashboardScreen trong ProfileSelectionScope và MaterialApp để cung cấp đủ context
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSelectionScope(
          controller:
              ProfileSelectionController(), // Khởi tạo controller giả lập cho test
          child: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the metrics currently displayed on the dashboard.
    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('Giấc ngủ'), findsOneWidget);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
  });
}
