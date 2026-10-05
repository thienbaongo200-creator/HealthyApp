import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/mock_health_data_service.dart';

void main() {
  group('MockHealthDataService', () {
    test('resting keeps heart rate near baseline and adds BMR calories', () {
      final start = DateTime.utc(2026, 10, 4);
      final service = MockHealthDataService(
        dailyBmrKcal: 1600,
        initialTime: start,
        random: Random(42),
      );

      final first = service.nextSample(
        now: start.add(const Duration(minutes: 1)),
      );
      final second = service.nextSample(
        now: start.add(const Duration(minutes: 2)),
      );

      expect(first.heartRate, inInclusiveRange(65, 75));
      expect(second.heartRate, inInclusiveRange(65, 75));
      expect(second.steps, lessThanOrEqualTo(2));
      expect(first.calories, closeTo(1600 / 1440, 0.01));
      expect(second.calories, greaterThan(first.calories));
      expect(first.activityState, MockActivityState.resting);
      expect(first.idempotencyKey, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('calculates BMR from profile inputs using Mifflin-St Jeor', () {
      final male = MockHealthDataService(
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
        sex: MockBmrSex.male,
      );
      final female = MockHealthDataService(
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
        sex: MockBmrSex.female,
      );

      expect(male.dailyBmrKcal, 1617.5);
      expect(female.dailyBmrKcal, 1451.5);
    });

    test(
      'active mode raises heart rate and accumulates steps and calories',
      () {
        final start = DateTime.utc(2026, 10, 4);
        final service = MockHealthDataService(
          initialTime: start,
          random: Random(7),
        )..activityState = MockActivityState.active;

        MockHealthSample sample = service.nextSample(
          now: start.add(const Duration(seconds: 5)),
        );
        for (var minute = 2; minute <= 60; minute++) {
          sample = service.nextSample(
            now: start.add(Duration(minutes: minute)),
          );
        }

        expect(sample.heartRate, inInclusiveRange(110, 140));
        expect(sample.steps, greaterThan(5000));
        expect(sample.calories, greaterThan(200));
        expect(sample.activityState, MockActivityState.active);
      },
    );
  });
}
