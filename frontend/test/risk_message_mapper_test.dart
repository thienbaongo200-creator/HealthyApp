import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/risk_message_mapper.dart';

void main() {
  test('maps rule identifiers to journal-friendly copy', () {
    expect(
      RiskMessageMapper.toUserMessage('R01: elevated heart rate'),
      contains('nhịp tim'),
    );
    expect(
      RiskMessageMapper.toUserMessage('R03: Total steps below target (4,000).'),
      contains('4,000'),
    );
  });

  test('maps new health rules and preserves measured values', () {
    expect(RiskMessageMapper.toUserMessage('R05: Blood pressure high (145/92 mmHg).'), contains('145/92 mmHg'));
    expect(RiskMessageMapper.toUserMessage('R06: Sleep duration below 6 hours (5.50 hours).'), contains('5.50 hours'));
    expect(RiskMessageMapper.toUserMessage('R07: High temperature (38.1 C).'), contains('38.1 C'));
  });

  test('does not expose an unknown technical rule identifier', () {
    expect(
      RiskMessageMapper.toUserMessage('R99: Unmapped warning.'),
      'Unmapped warning.',
    );
  });
}
