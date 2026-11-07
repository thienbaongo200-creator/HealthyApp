import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'watch_sync_config.dart';

typedef WearDataPersister = Future<void> Function(Map<String, dynamic> data);

class WatchService {
  static final WatchService _instance = WatchService._internal();
  factory WatchService() => _instance;
  WatchService._internal();

  HttpServer? _server;
  final StreamController<Map<String, dynamic>> _wearDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get wearDataStream => _wearDataController.stream;

  Future<void> initPhoneListener({
    int port = 8080,
    required WearDataPersister persistBeforeAcknowledgement,
  }) async {
    if (_server != null) return;
    if (watchSyncToken.length < 32) {
      throw StateError('WATCH_SYNC_TOKEN must be at least 32 characters.');
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      _server!.listen((HttpRequest request) async {
        try {
          if (request.method == 'POST' && request.uri.path == '/sync') {
            final supplied = request.headers.value('x-watch-token') ?? '';
            if (!_constantTimeEquals(supplied, watchSyncToken)) {
              request.response.statusCode = HttpStatus.unauthorized;
              return;
            }
            if (request.contentLength > 16 * 1024) {
              request.response.statusCode = HttpStatus.requestEntityTooLarge;
              return;
            }
            final body = BytesBuilder(copy: false);
            var receivedBytes = 0;
            await for (final chunk in request) {
              receivedBytes += chunk.length;
              if (receivedBytes > 16 * 1024) {
                request.response.statusCode = HttpStatus.requestEntityTooLarge;
                return;
              }
              body.add(chunk);
            }
            final content = utf8.decode(body.takeBytes());
            if (content.isNotEmpty) {
              final Map<String, dynamic> data = jsonDecode(content);

              await persistBeforeAcknowledgement(data);
              _wearDataController.add(data);

              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({'status': 'success'}));
            } else {
              request.response.statusCode = HttpStatus.badRequest;
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } on FormatException {
          request.response.statusCode = HttpStatus.badRequest;
        } on Object {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });
    } on SocketException {
      _server = null;
      rethrow;
    }
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
    await _server?.close(force: true);
    _server = null;
    await _wearDataController.close();
  }
}
