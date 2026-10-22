import 'package:flutter/foundation.dart';

// Android emulator can reach the host machine through 10.0.2.2. A physical
// phone must use the computer's current Wi-Fi IPv4 address via --dart-define.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

void validateApiBaseUrl() {
  if (kReleaseMode && Uri.parse(apiBaseUrl).scheme != 'https') {
    throw StateError(
      'Release builds require an HTTPS API_BASE_URL dart-define.',
    );
  }
}
