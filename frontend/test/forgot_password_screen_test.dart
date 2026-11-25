import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/views/auth/forgot_password_screen.dart';

class _FakeApiService extends ApiService {
  Future<void> Function(String email)? onRequestPasswordReset;
  Future<void> Function({
    required String email,
    required String otp,
    required String newPassword,
  })?
  onResetPassword;

  @override
  Future<void> requestPasswordReset(String email) async {
    await onRequestPasswordReset?.call(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await onResetPassword?.call(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}

Widget _buildScreen(_FakeApiService api) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ForgotPasswordScreen(apiService: api),
  );
}

void main() {
  testWidgets('validates an empty email before requesting a code', (
    tester,
  ) async {
    final api = _FakeApiService();
    var requestCount = 0;
    api.onRequestPasswordReset = (_) async => requestCount++;
    await tester.pumpWidget(_buildScreen(api));

    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('validates an invalid email before requesting a code', (
    tester,
  ) async {
    final api = _FakeApiService();
    var requestCount = 0;
    api.onRequestPasswordReset = (_) async => requestCount++;
    await tester.pumpWidget(_buildScreen(api));
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');

    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('shows a loading indicator while requesting an OTP', (
    tester,
  ) async {
    final api = _FakeApiService();
    final request = Completer<void>();
    api.onRequestPasswordReset = (_) => request.future;
    await tester.pumpWidget(_buildScreen(api));
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );

    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    request.complete();
    await tester.pumpAndSettle();
    expect(find.text('Gửi lại mã sau 60 giây'), findsOneWidget);
  });

  testWidgets('shows a friendly message and cooldown on HTTP 429', (
    tester,
  ) async {
    final api = _FakeApiService();
    api.onRequestPasswordReset = (_) async {
      throw ApiException(429, 'Too many requests');
    };
    await tester.pumpWidget(_buildScreen(api));
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );

    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(
      find.text('Bạn đã yêu cầu quá nhiều lần, vui lòng thử lại sau ít phút.'),
      findsOneWidget,
    );
    expect(find.text('Gửi mã sau 60 giây'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'OTP boxes stay visible and interactive with the app input theme',
    (tester) async {
      final api = _FakeApiService()..onRequestPasswordReset = (_) async {};
      await tester.pumpWidget(_buildScreen(api));
      await tester.enterText(
        find.byType(TextFormField).first,
        'person@example.com',
      );
      await tester.tap(find.text('Gửi mã xác nhận'));
      await tester.pumpAndSettle();

      for (var index = 0; index < 6; index++) {
        expect(find.byKey(Key('otp-digit-$index')), findsOneWidget);
      }

      final otpField = tester.widget<TextField>(
        find.byKey(const Key('otp-input')),
      );
      expect(otpField.decoration?.filled, isFalse);
      expect(otpField.decoration?.fillColor, Colors.transparent);

      await tester.enterText(find.byKey(const Key('otp-input')), '123456');
      await tester.pump();

      for (final digit in '123456'.split('')) {
        expect(find.text(digit), findsOneWidget);
      }
    },
  );

  testWidgets('rejects mismatched new password confirmation', (tester) async {
    final api = _FakeApiService();
    api.onRequestPasswordReset = (_) async {};
    var resetCount = 0;
    api.onResetPassword =
        ({required email, required otp, required newPassword}) async {
          resetCount++;
        };
    await tester.pumpWidget(_buildScreen(api));
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-input')), '123456');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'StrongPassword!123',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'DifferentPassword!123',
    );
    await tester.ensureVisible(find.text('Cập nhật mật khẩu'));

    await tester.tap(find.text('Cập nhật mật khẩu'));
    await tester.pump();

    expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
    expect(resetCount, 0);
  });
}
