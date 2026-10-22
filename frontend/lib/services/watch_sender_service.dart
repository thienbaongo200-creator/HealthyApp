import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WatchSenderService {
  static const String _syncUrl = String.fromEnvironment(
    'WATCH_SYNC_URL',
    defaultValue: 'http://localhost:8080/sync',
  );

  Future<bool> sendDataToPhone(Map<String, dynamic> healthData) async {
    try {
      final response = await http
          .post(
            Uri.parse(_syncUrl),
            headers: {'Content-Type': 'application/json'},
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
