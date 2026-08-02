import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

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
      debugPrint('[Phone Server] 🚀 Server đang chạy tại port $port...');

      _server!.listen((HttpRequest request) async {
        try {
          if (request.method == 'POST' && request.uri.path == '/sync') {
            final content = await utf8.decoder.bind(request).join();
            if (content.isNotEmpty) {
              final Map<String, dynamic> data = jsonDecode(content);
              debugPrint('[Phone Server] 📥 Nhận data: $data');

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
        } catch (e) {
          debugPrint('[Phone Server] ❌ Lỗi xử lý: $e');
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('[Phone Server] 💥 Lỗi Bind Server: $e');
    }
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    await _wearDataController.close();
  }
}
