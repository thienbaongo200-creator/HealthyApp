import 'dart:math';

enum MockActivityState { resting, active }
enum MockBmrSex { male, female }

class MockHealthSample {
  const MockHealthSample({
    required this.heartRate,
    required this.steps,
    required this.calories,
    required this.activityState,
    required this.measuredAt,
    required this.deviceId,
    required this.idempotencyKey,
  });

  final int heartRate;
  final int steps;
  final double calories;
  final MockActivityState activityState;
  final DateTime measuredAt;
  final String deviceId;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
    'heart_rate': heartRate,
    'steps': steps,
    'calories': calories,
    'activity_state': activityState.name,
    'measured_at': measuredAt.toUtc().toIso8601String(),
    'device_id': deviceId,
    'idempotency_key': idempotencyKey,
  };
}

class MockHealthDataService {
  MockHealthDataService({
    this.deviceId = 'wear-os-mock',
    double? dailyBmrKcal,
    this.weightKg = 70,
    this.heightCm = 170,
    this.ageYears = 30,
    this.sex,
    DateTime? initialTime,
    Random? random,
  }) : _lastSampleAt = initialTime ?? DateTime.now(),
       _dailyBmrOverride = dailyBmrKcal,
       _random = random ?? Random.secure();

  final String deviceId;
  final double? _dailyBmrOverride;
  final double weightKg;
  final double heightCm;
  final int ageYears;
  final MockBmrSex? sex;
  final Random _random;

  double get dailyBmrKcal =>
      _dailyBmrOverride ??
      10 * weightKg +
          6.25 * heightCm -
          5 * ageYears +
          (sex == MockBmrSex.male ? 5 : sex == MockBmrSex.female ? -161 : -78);

  DateTime _lastSampleAt;
  int _heartRate = 70;
  int _steps = 0;
  double _calories = 0;
  double _fractionalSteps = 0;
  MockActivityState activityState = MockActivityState.resting;

  MockHealthSample nextSample({DateTime? now}) {
    final measuredAt = now ?? DateTime.now();
    final elapsed = measuredAt.difference(_lastSampleAt);
    final elapsedSeconds = elapsed.isNegative ? 0.0 : elapsed.inMilliseconds / 1000;
    _lastSampleAt = measuredAt;

    _updateHeartRate();
    _updateSteps(elapsedSeconds);

    final basalCalories = dailyBmrKcal * elapsedSeconds / Duration.secondsPerDay;
    final activeCalories = activityState == MockActivityState.active
        ? _stepsAddedThisTick * 0.04
        : 0.0;
    _calories += basalCalories + activeCalories;

    return MockHealthSample(
      heartRate: _heartRate,
      steps: _steps,
      calories: double.parse(_calories.toStringAsFixed(2)),
      activityState: activityState,
      measuredAt: measuredAt,
      deviceId: deviceId,
      idempotencyKey: _createUuidV4(),
    );
  }

  int _stepsAddedThisTick = 0;

  void _updateHeartRate() {
    final target = activityState == MockActivityState.active
        ? 110 + _random.nextInt(31)
        : 65 + _random.nextInt(11);
    final maxChange = activityState == MockActivityState.active
        ? 6
        : _heartRate < 65 || _heartRate > 75
        ? 12
        : 3;
    final delta = target - _heartRate;
    _heartRate += delta.clamp(-maxChange, maxChange);
    if (delta.abs() <= maxChange) {
      _heartRate = target;
    }
  }

  void _updateSteps(double elapsedSeconds) {
    _stepsAddedThisTick = 0;
    if (activityState == MockActivityState.active) {
      final cadence = 90 + _random.nextInt(41);
      _fractionalSteps += elapsedSeconds * cadence / 60;
      _stepsAddedThisTick = _fractionalSteps.floor();
      _fractionalSteps -= _stepsAddedThisTick;
    } else if (elapsedSeconds > 0 &&
        _random.nextDouble() < elapsedSeconds / 240) {
      _stepsAddedThisTick = 1;
    }
    _steps += _stepsAddedThisTick;
  }

  String _createUuidV4() {
    return createIdempotencyKey(_random);
  }
}

String createIdempotencyKey([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
