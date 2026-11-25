import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class WatchPendingItem {
  const WatchPendingItem({
    required this.idempotencyKey,
    required this.payload,
    required this.attempts,
    required this.status,
    required this.lastError,
  });

  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final int attempts;
  final String status;
  final String? lastError;
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
      version: 2,
      onCreate: (database, _) => database.execute('''
        CREATE TABLE watch_outbox (
          idempotency_key TEXT PRIMARY KEY,
          payload TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          next_attempt_at TEXT,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'PENDING',
          last_error TEXT
        )
      '''),
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE watch_outbox ADD COLUMN status TEXT NOT NULL DEFAULT 'PENDING'",
          );
          await database.execute(
            'ALTER TABLE watch_outbox ADD COLUMN last_error TEXT',
          );
        }
      },
    );
    return _database!;
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final key = payload['idempotency_key']?.toString();
    if (key == null || key.isEmpty) {
      throw ArgumentError('Wear sample requires an idempotency_key.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await (await _db).insert(
      'watch_outbox',
      {
        'idempotency_key': key,
        'payload': jsonEncode(payload),
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<WatchPendingItem?> firstReady() async {
    final rows = await (await _db).query(
      'watch_outbox',
      where: "status = 'PENDING' AND (next_attempt_at IS NULL OR next_attempt_at <= ?)",
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<WatchPendingItem>> failedItems() async {
    final rows = await (await _db).query(
      'watch_outbox',
      where: "status = 'FAILED'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> acknowledge(String key) async {
    await (await _db).delete(
      'watch_outbox',
      where: 'idempotency_key = ?',
      whereArgs: [key],
    );
  }

  Future<void> markFailed(String key, String reason) async {
    await (await _db).update(
      'watch_outbox',
      {'status': 'FAILED', 'last_error': reason, 'next_attempt_at': null},
      where: 'idempotency_key = ?',
      whereArgs: [key],
    );
  }

  Future<void> retryFailed(String key) async {
    await (await _db).update(
      'watch_outbox',
      {
        'status': 'PENDING',
        'attempts': 0,
        'last_error': null,
        'next_attempt_at': null,
      },
      where: 'idempotency_key = ? AND status = ?',
      whereArgs: [key, 'FAILED'],
    );
  }

  Future<void> scheduleRetry(WatchPendingItem item) async {
    final attempts = item.attempts + 1;
    final exponent = (attempts - 1).clamp(0, 6).toInt();
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

  WatchPendingItem _fromRow(Map<String, Object?> row) => WatchPendingItem(
    idempotencyKey: row['idempotency_key']! as String,
    payload: (jsonDecode(row['payload']! as String) as Map)
        .cast<String, dynamic>(),
    attempts: row['attempts']! as int,
    status: row['status'] as String? ?? 'PENDING',
    lastError: row['last_error'] as String?,
  );
}
