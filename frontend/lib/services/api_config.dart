// Android emulator can reach the host machine through 10.0.2.2. A physical
// phone must use the computer's current Wi-Fi IPv4 address via --dart-define.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
