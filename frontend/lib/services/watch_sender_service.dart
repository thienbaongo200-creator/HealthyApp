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
    if (watchSyncToken.length < 32) {
      debugPrint('[Wear OS] WATCH_SYNC_TOKEN is not configured.');
      return false;
    }
    try {
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

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on Exception {
      debugPrint('[Wear OS] Data sync failed.');
      return false;
    }
  }
}
