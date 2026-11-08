const bool useMockWearOs = bool.fromEnvironment(
  'USE_MOCK_WEAR_OS',
  defaultValue: true,
);

const String watchDeviceIdentifier = String.fromEnvironment(
  'WATCH_DEVICE_IDENTIFIER',
  defaultValue: 'wear-os-demo-device',
);

const String wearMockArchitectureNote =
    'Phiên bản hiện tại sử dụng dữ liệu mô phỏng Wear OS để kiểm thử kiến trúc Offline Queue & Sync, sẵn sàng kết nối thiết bị thương mại';

const String watchSyncToken = String.fromEnvironment('WATCH_SYNC_TOKEN');
