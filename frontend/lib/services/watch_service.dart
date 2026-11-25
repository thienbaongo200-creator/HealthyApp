import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'watch_sync_config.dart';

typedef WearDataPersister = Future<void> Function(Map<String, dynamic> data);

class WatchService {
  static final WatchService _instance = WatchService._internal();
  factory WatchService() => _instance;
  WatchService._internal();

  HttpServer? _server;
  String? _listenerToken;
  WearDataPersister? _persistBeforeAcknowledgement;
  final StreamController<Map<String, dynamic>> _wearDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get wearDataStream => _wearDataController.stream;

  void removePersister(WearDataPersister persister) {
    if (_persistBeforeAcknowledgement == persister) {
      _persistBeforeAcknowledgement = null;
    }
  }

  Future<void> initPhoneListener({
    int port = phoneSyncPort,
    required WearDataPersister persistBeforeAcknowledgement,
  }) async {
    _persistBeforeAcknowledgement = persistBeforeAcknowledgement;
    final configuredToken = watchSyncToken;
    debugPrint(
      '[Phone] WATCH_SYNC_TOKEN configured=${configuredToken.length >= 32} '
      'length=${configuredToken.length} '
      'id=${watchSyncTokenDiagnosticId(configuredToken)}.',
    );
    if (_server != null) {
      final activeToken = _listenerToken ?? '';
      debugPrint(
        '[Phone] Reusing existing /sync listener; active token '
        'length=${activeToken.length} '
        'id=${watchSyncTokenDiagnosticId(activeToken)}.',
      );
      return;
    }
    if (configuredToken.length < 32) {
      debugPrint('[Phone] HTTP sync listener disabled: WATCH_SYNC_TOKEN is not configured.');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      // Snapshot the credential at bind time. Compile-time dart-defines only
      // change when the app is rebuilt; an existing listener cannot rotate it.
      _listenerToken = configuredToken;
      debugPrint('[Phone] HTTP sync listener ready on 0.0.0.0:$port/sync.');

      _server!.listen(_handleHttpRequest);
    } on SocketException catch (error) {
      _server = null;
      _listenerToken = null;
      debugPrint(
        '[Phone] HTTP fallback could not bind port $port: $error. '
        'HTTP Sync is unavailable until the port can be bound.',
      );
    }
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final persister = _persistBeforeAcknowledgement;
    if (persister == null) {
      throw StateError('Wear data persister is not configured.');
    }
    await persister(data);
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'POST' || request.uri.path != '/sync') {
        _writeJson(response, HttpStatus.notFound, {
          'status': 'error',
          'code': 'not_found',
          'message': 'Expected POST /sync.',
        });
        return;
      }

      final supplied = request.headers.value('x-watch-token') ?? '';
      final expected = _listenerToken ?? '';
      if (!_constantTimeEquals(supplied, expected)) {
        debugPrint(
          '[Phone] /sync token rejected: suppliedLength=${supplied.length} '
          'suppliedId=${watchSyncTokenDiagnosticId(supplied)} '
          'expectedLength=${expected.length} '
          'expectedId=${watchSyncTokenDiagnosticId(expected)}.',
        );
        _writeJson(response, HttpStatus.unauthorized, {
          'status': 'error',
          'code': 'invalid_watch_token',
          'message': 'X-Watch-Token is missing or invalid.',
        });
        return;
      }
      if (request.contentLength > 16 * 1024) {
        _writeJson(response, HttpStatus.requestEntityTooLarge, {
          'status': 'error',
          'code': 'payload_too_large',
          'message': 'The maximum request size is 16 KB.',
        });
        return;
      }

      final body = BytesBuilder(copy: false);
      var receivedBytes = 0;
      await for (final chunk in request) {
        receivedBytes += chunk.length;
        if (receivedBytes > 16 * 1024) {
          _writeJson(response, HttpStatus.requestEntityTooLarge, {
            'status': 'error',
            'code': 'payload_too_large',
            'message': 'The maximum request size is 16 KB.',
          });
          return;
        }
        body.add(chunk);
      }

      final content = utf8.decode(body.takeBytes());
      if (content.trim().isEmpty) {
        _writeJson(response, HttpStatus.badRequest, {
          'status': 'error',
          'code': 'empty_body',
          'message': 'A JSON measurement payload is required.',
        });
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        _writeJson(response, HttpStatus.badRequest, {
          'status': 'error',
          'code': 'invalid_payload_shape',
          'message': 'The JSON body must be an object.',
        });
        return;
      }

      try {
        await _persist(decoded);
      } on FormatException catch (error, stackTrace) {
        debugPrint('[Phone] Invalid /sync measurement: $error\n$stackTrace');
        _writeJson(response, HttpStatus.badRequest, {
          'status': 'error',
          'code': 'invalid_measurement',
          'message': error.message,
        });
        return;
      } catch (error, stackTrace) {
        debugPrint('[Phone] /sync persistence failed: $error\n$stackTrace');
        _writeJson(response, HttpStatus.internalServerError, {
          'status': 'error',
          'code': 'persistence_failed',
          'message': 'Mobile could not map or queue this measurement.',
          'detail': error.toString(),
        });
        return;
      }

      _wearDataController.add(decoded);
      debugPrint('[Phone] /sync accepted; sample saved to the mobile queue.');
      _writeJson(response, HttpStatus.ok, {
        'status': 'success',
        'message': 'Measurement saved to the mobile sync queue.',
      });
    } on FormatException catch (error, stackTrace) {
      debugPrint('[Phone] Invalid /sync JSON: $error\n$stackTrace');
      _writeJson(response, HttpStatus.badRequest, {
        'status': 'error',
        'code': 'invalid_json',
        'message': 'The request body is not valid UTF-8 JSON.',
        'detail': error.message,
      });
    } catch (error, stackTrace) {
      debugPrint('[Phone] Unexpected /sync failure: $error\n$stackTrace');
      _writeJson(response, HttpStatus.internalServerError, {
        'status': 'error',
        'code': 'internal_error',
        'message': 'Mobile failed to process the sync request.',
        'detail': error.toString(),
      });
    } finally {
      await response.close();
    }
  }

  void _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  bool _constantTimeEquals(String a, String b) {
    var difference = a.length ^ b.length;
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> dispose() async {
    _persistBeforeAcknowledgement = null;
    await _server?.close(force: true);
    _server = null;
    _listenerToken = null;
    await _wearDataController.close();
  }
}
