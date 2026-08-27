import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Health dashboard loads and shows metric cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthApp());
    await tester.pumpAndSettle();

    // Kiem tra tieu de man hinh
    expect(find.text('Chào mừng bạn!'), findsOneWidget);

    // Kiem tra cac the chi so suc khoe
    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('Bước đi'), findsOneWidget);
    expect(find.text('Calo'), findsOneWidget);

    // Kiem tra icons
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);

    // Kiem tra text trang thai ket noi dong ho
    expect(find.text('Đang chờ kết nối...'), findsOneWidget);
  });
}
