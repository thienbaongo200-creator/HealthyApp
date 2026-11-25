import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'watch_sync_config.dart';
import 'package:http/http.dart' as http;

enum WatchSendDisposition { accepted, retryableFailure, permanentFailure }

class WatchSendResult {
  const WatchSendResult(this.disposition, this.message);

  final WatchSendDisposition disposition;
  final String message;
}

class WatchSenderService {
  static const String _syncUrl = String.fromEnvironment(
    'WATCH_SYNC_URL',
    defaultValue: 'http://localhost:8080/sync',
  );

  Future<WatchSendResult> sendDataToPhone(
    Map<String, dynamic> healthData,
  ) async {
    final key = healthData['idempotency_key']?.toString();
    final identifier = healthData['device_identifier']?.toString().trim();
    final hasMeasurements =
        healthData['heart_rate'] is num &&
        healthData['steps'] is num &&
        healthData['calories'] is num;
    if (key == null || key.isEmpty || identifier == null || identifier.isEmpty || !hasMeasurements) {
      return const WatchSendResult(
        WatchSendDisposition.permanentFailure,
        'Payload thiếu idempotency_key, device_identifier hoặc chỉ số bắt buộc.',
      );
    }
    if (kDebugMode) {
      debugPrint('SYNC URL = $_syncUrl');
      debugPrint('TOKEN LENGTH = ${watchSyncToken.length}');
      debugPrint(
        'TOKEN DIAGNOSTIC ID = ${watchSyncTokenDiagnosticId(watchSyncToken)}',
      );
    }
    if (watchSyncToken.length < 32) {
      if (kDebugMode) {
        debugPrint('Request blocked: WATCH_SYNC_TOKEN must be at least 32 characters.');
      }
      // Mock/demo mode is intentionally usable offline. Keep samples queued;
      // a real sync token can be supplied later without noisy console errors.
      if (!useMockWearOs) {
        debugPrint('[Wear OS] WATCH_SYNC_TOKEN is not configured.');
      }
      return const WatchSendResult(
        WatchSendDisposition.permanentFailure,
        'WATCH_SYNC_TOKEN chưa được cấu hình đúng.',
      );
    }
    try {
      if (kDebugMode) {
        debugPrint('Sending request...');
      }
      final response = await http
          .post(
            Uri.parse(_syncUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Watch-Token': watchSyncToken,
            },
            body: jsonEncode(healthData),
          )
          .timeout(const Duration(seconds: 3));

      if (kDebugMode) {
        debugPrint('Response status = ${response.statusCode}');
        debugPrint('Response body = ${response.body}');
      }
      if (response.statusCode == 200) {
        return const WatchSendResult(
          WatchSendDisposition.accepted,
          'Điện thoại đã nhận mẫu vào hàng đợi.',
        );
      }
      if (response.statusCode == 408 ||
          response.statusCode == 429 ||
          response.statusCode >= 500) {
        return WatchSendResult(
          WatchSendDisposition.retryableFailure,
          'Điện thoại/API tạm thời lỗi HTTP ${response.statusCode}.',
        );
      }
      return WatchSendResult(
        WatchSendDisposition.permanentFailure,
        'Điện thoại từ chối mẫu với HTTP ${response.statusCode}.',
      );
    } on Exception catch (error) {
      debugPrint('[Wear OS] Data sync failed: $error');
      return WatchSendResult(
        WatchSendDisposition.retryableFailure,
        'Mất kết nối tới điện thoại: $error',
      );
    }
  }
}
