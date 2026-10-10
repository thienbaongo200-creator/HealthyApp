import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores manually entered health measurements locally until the API supports them.
class ManualMeasurementStore {
  ManualMeasurementStore._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'manual_health_measurements';

  static Future<List<Map<String, dynamic>>> readAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList(growable: true);
  }

  static Future<void> add(Map<String, dynamic> measurement) async {
    final records = await readAll();
    records.insert(0, measurement);
    await _storage.write(key: _key, value: jsonEncode(records));
  }
}
