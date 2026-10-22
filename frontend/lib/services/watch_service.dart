import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WatchService {
  static final WatchService _instance = WatchService._internal();
  factory WatchService() => _instance;
  WatchService._internal();

  HttpServer? _server;
  final StreamController<Map<String, dynamic>> _wearDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get wearDataStream => _wearDataController.stream;

  Future<void> initPhoneListener({int port = 8080}) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      _server!.listen((HttpRequest request) async {
        try {
          if (request.method == 'POST' && request.uri.path == '/sync') {
            final content = await utf8.decoder.bind(request).join();
            if (content.isNotEmpty) {
              final Map<String, dynamic> data = jsonDecode(content);

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
        } on Exception {
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

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    await _wearDataController.close();
  }
}
