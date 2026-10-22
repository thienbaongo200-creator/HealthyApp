import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/home/dashboard_screen.dart';
import 'package:frontend/state/profile_selection.dart'; // Import state quản lý profile

void main() {
  testWidgets('Health dashboard loads and shows metric cards', (
    WidgetTester tester,
  ) async {
    // Bọc DashboardScreen trong ProfileSelectionScope và MaterialApp để cung cấp đủ context
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSelectionScope(
          controller: ProfileSelectionController(), // Khởi tạo controller giả lập cho test
          child: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kiểm tra các thẻ chỉ số sức khỏe và icon hệ thống
    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('Bước đi · bước'), findsOneWidget);
    expect(find.text('Calo · kcal'), findsOneWidget);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });
}