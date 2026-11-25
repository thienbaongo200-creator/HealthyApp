import 'dart:convert';

import 'package:crypto/crypto.dart';

const bool useMockWearOs = bool.fromEnvironment(
  'USE_MOCK_WEAR_OS',
  defaultValue: true,
);

const String watchDeviceIdentifier = String.fromEnvironment(
  'WATCH_DEVICE_IDENTIFIER',
  defaultValue: 'wear-os-demo-device',
);

const String wearMockArchitectureNote =
    'Dữ liệu mô phỏng đồng bộ trực tiếp về điện thoại qua HTTP Sync có xác thực token và hàng đợi ngoại tuyến (Offline Queue).';

const String watchSyncToken = String.fromEnvironment('WATCH_SYNC_TOKEN');

/// Stable diagnostic identifier for comparing build-time tokens.
/// This is not used for authentication and must never replace the token.
String watchSyncTokenDiagnosticId(String token) {
  return sha256.convert(utf8.encode(token)).toString();
}

const int phoneSyncPort = int.fromEnvironment(
  'PHONE_SYNC_PORT',
  defaultValue: 8181,
);
