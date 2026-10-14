import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/views/home/dashboard_screen.dart';

void main() {
  testWidgets('Health dashboard loads and shows metric cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    // Kiem tra tieu de man hinh
    expect(find.text('Chào mừng bạn!'), findsOneWidget);

    // Kiem tra cac the chi so suc khoe
    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('Bước đi · bước'), findsOneWidget);
    expect(find.text('Calo · kcal'), findsOneWidget);

    // Kiem tra icons
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });
}
