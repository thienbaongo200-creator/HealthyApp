import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class WatchPendingItem {
  const WatchPendingItem({
    required this.idempotencyKey,
    required this.payload,
    required this.attempts,
  });

  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final int attempts;
}

class WatchPendingQueue {
  WatchPendingQueue._();

  static final WatchPendingQueue instance = WatchPendingQueue._();

  Database? _database;

  Future<Database> get _db async {
    if (_database case final database?) return database;
    final path = p.join(await getDatabasesPath(), 'healthyapp_watch_outbox.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (database, _) => database.execute('''
        CREATE TABLE watch_outbox (
          idempotency_key TEXT PRIMARY KEY,
          payload TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          next_attempt_at TEXT,
          created_at TEXT NOT NULL
        )
      '''),
    );
    return _database!;
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final key = payload['idempotency_key']?.toString();
    if (key == null || key.isEmpty) {
      throw ArgumentError('Wear sample requires an idempotency_key.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await (await _db).insert('watch_outbox', {
      'idempotency_key': key,
      'payload': jsonEncode(payload),
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<WatchPendingItem?> firstReady() async {
    final rows = await (await _db).query(
      'watch_outbox',
      where: 'next_attempt_at IS NULL OR next_attempt_at <= ?',
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return WatchPendingItem(
      idempotencyKey: row['idempotency_key']! as String,
      payload: (jsonDecode(row['payload']! as String) as Map)
          .cast<String, dynamic>(),
      attempts: row['attempts']! as int,
    );
  }

  Future<void> acknowledge(String key) async {
    await (await _db).delete(
      'watch_outbox',
      where: 'idempotency_key = ?',
      whereArgs: [key],
    );
  }

  Future<void> scheduleRetry(WatchPendingItem item) async {
    final attempts = item.attempts + 1;
    final exponent = (attempts - 1).clamp(0, 6);
    final delaySeconds = (5 * (1 << exponent)).clamp(5, 300).toInt();
    await (await _db).update(
      'watch_outbox',
      {
        'attempts': attempts,
        'next_attempt_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: delaySeconds))
            .toIso8601String(),
      },
      where: 'idempotency_key = ?',
      whereArgs: [item.idempotencyKey],
    );
  }
}
