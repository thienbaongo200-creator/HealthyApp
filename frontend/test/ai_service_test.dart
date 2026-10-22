import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/ai_service.dart';

void main() {
  group('AiApiService.parseRiskResponse', () {
    test('returns UNKNOWN result for the HTTP 422 screening contract', () {
      final result = AiApiService.parseRiskResponse(
        statusCode: 422,
        payload: {
          'profile_id': 'profile-123',
          'risk_level': 'UNKNOWN',
          'analyzed_count': 0,
          'warnings': ['Chưa đủ dữ liệu hợp lệ.'],
          'recommendation': 'Cần thêm dữ liệu đo.',
          'recommendations': ['Bổ sung ít nhất 3 mẫu nhịp tim.'],
        },
      );

      expect(result, isA<RiskAssessmentResult>());
      expect(result.profileId, 'profile-123');
      expect(result.riskLevel, 'UNKNOWN');
      expect(result.analyzedCount, 0);
      expect(result.recommendations, ['Bổ sung ít nhất 3 mẫu nhịp tim.']);
      expect(result.generatedBy, 'RULE_ONLY');
      expect(result.interpretation, isNull);
    });

    test('parses a consented AI interpretation', () {
      final result = AiApiService.parseRiskResponse(
        statusCode: 200,
        payload: {
          'profile_id': 'profile-123',
          'risk_level': 'LOW',
          'analyzed_count': 3,
          'warnings': <String>[],
          'recommendation': 'Tiếp tục theo dõi.',
          'recommendations': <String>[],
          'generated_by': 'RULE_AND_AI',
          'interpretation': 'Các chỉ số hiện chưa có cảnh báo theo quy tắc.',
        },
      );

      expect(result.generatedBy, 'RULE_AND_AI');
      expect(
        result.interpretation,
        'Các chỉ số hiện chưa có cảnh báo theo quy tắc.',
      );
    });

    test('does not treat other HTTP 422 responses as screening results', () {
      expect(
        () => AiApiService.parseRiskResponse(
          statusCode: 422,
          payload: {'detail': 'Invalid request.'},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
