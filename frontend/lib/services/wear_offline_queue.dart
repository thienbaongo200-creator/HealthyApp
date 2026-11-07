import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class WearQueueItem {
  const WearQueueItem({
    required this.profileId,
    required this.measurement,
    required this.status,
    required this.attempts,
    required this.nextAttemptAt,
  });

  final String profileId;
  final Map<String, dynamic> measurement;
  final String status;
  final int attempts;
  final DateTime? nextAttemptAt;

  String get key => measurement['idempotency_key'].toString();
}

class WearOfflineQueue {
  static final WearOfflineQueue instance = WearOfflineQueue._();
  WearOfflineQueue._();

  Database? _database;

  Future<Database> get database async {
    if (_database case final db?) return db;
    final path = p.join(await getDatabasesPath(), 'healthyapp_wear_queue.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE wear_queue (
            idempotency_key TEXT PRIMARY KEY,
            profile_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at TEXT,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX wear_queue_ready_idx ON wear_queue(status, next_attempt_at, created_at)',
        );
      },
      onOpen: (db) async {
        await db.rawUpdate(
          "UPDATE wear_queue SET status='WAITING', updated_at=? WHERE status='SENDING'",
          [DateTime.now().toUtc().toIso8601String()],
        );
      },
    );
    return _database!;
  }

  Future<void> enqueue(String profileId, Map<String, dynamic> measurement) async {
    final key = measurement['idempotency_key']?.toString();
    if (key == null || key.isEmpty) {
      throw ArgumentError('Queued measurement requires idempotency_key.');
    }
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'wear_queue',
      {
        'idempotency_key': key,
        'profile_id': profileId,
        'payload': jsonEncode(measurement),
        'status': 'WAITING',
        'attempts': 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<WearQueueItem>> ready({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'wear_queue',
      where: '''
        status IN (?, ?) AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
      ''',
      whereArgs: [
        'WAITING',
        'RETRY_PENDING',
        DateTime.now().toUtc().toIso8601String(),
      ],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<int> pendingCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM wear_queue WHERE status IN ('WAITING','SENDING','RETRY_PENDING')",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markSending(Iterable<WearQueueItem> items) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in items) {
      batch.update(
        'wear_queue',
        {'status': 'SENDING', 'updated_at': now},
        where: 'idempotency_key = ?',
        whereArgs: [item.key],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMeasurement(WearQueueItem item, Map<String, dynamic> measurement) async {
    final db = await database;
    await db.update(
      'wear_queue',
      {
        'payload': jsonEncode(measurement),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'idempotency_key = ?',
      whereArgs: [item.key],
    );
  }

  Future<void> markSynced(String key) => _update(key, {
    'status': 'SYNCED',
    'next_attempt_at': null,
    'last_error': null,
  });

  Future<void> markFailed(String key, String reason) => _update(key, {
    'status': 'FAILED',
    'next_attempt_at': null,
    'last_error': reason,
  });

  Future<void> scheduleRetry(WearQueueItem item, String reason) async {
    final attempts = item.attempts + 1;
    if (attempts >= 8) {
      await markFailed(item.key, reason);
      return;
    }
    final seconds = (5 * (1 << (attempts - 1))).clamp(5, 3600).toInt();
    await _update(item.key, {
      'status': 'RETRY_PENDING',
      'attempts': attempts,
      'next_attempt_at': DateTime.now()
          .toUtc()
          .add(Duration(seconds: seconds))
          .toIso8601String(),
      'last_error': reason,
    });
  }

  Future<void> retryFailed(String key) => _update(key, {
    'status': 'WAITING',
    'attempts': 0,
    'next_attempt_at': null,
    'last_error': null,
  });

  Future<void> _update(String key, Map<String, Object?> values) async {
    final db = await database;
    await db.update(
      'wear_queue',
      {...values, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'idempotency_key = ?',
      whereArgs: [key],
    );
  }

  WearQueueItem _fromRow(Map<String, Object?> row) => WearQueueItem(
    profileId: row['profile_id']! as String,
    measurement: (jsonDecode(row['payload']! as String) as Map).cast<String, dynamic>(),
    status: row['status']! as String,
    attempts: row['attempts']! as int,
    nextAttemptAt: row['next_attempt_at'] == null
        ? null
        : DateTime.tryParse(row['next_attempt_at']! as String),
  );
}
