import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'watch_sync_config.dart';
import 'package:http/http.dart' as http;

class WatchSenderService {
  static const String _syncUrl = String.fromEnvironment(
    'WATCH_SYNC_URL',
    defaultValue: 'http://localhost:8080/sync',
  );

  Future<bool> sendDataToPhone(Map<String, dynamic> healthData) async {
    if (kDebugMode) {
      debugPrint('SYNC URL = $_syncUrl');
      debugPrint('TOKEN LENGTH = ${watchSyncToken.length}');
      debugPrint('PAYLOAD = ${jsonEncode(healthData)}');
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
      return false;
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
        return true;
      }
      return false;
    } on Exception catch (error) {
      debugPrint('[Wear OS] Data sync failed: $error');
      return false;
    }
  }
}
