class RiskMessageMapper {
  const RiskMessageMapper._();

  static const Map<String, String> _messages = {
    'R01': 'Nhịp tim vượt ngưỡng 120 bpm; cần theo dõi và đo lại.',
    'R02': 'Nhịp tim đo được cao hơn ngưỡng theo dõi.',
    'R03': 'Tổng số bước trong ngày thấp hơn mục tiêu 6.000 bước.',
    'R04': 'Lượng calo trong ngày thấp hơn mục tiêu 300 kcal.',
    'R05': 'Huyết áp cao hơn ngưỡng theo dõi.',
    'R06': 'Thời lượng giấc ngủ khai báo thấp hơn mức khuyến nghị.',
    'R07': 'Thân nhiệt đạt hoặc vượt ngưỡng 37,8 °C.',
    'R08': 'Kết quả xét nghiệm có giá trị cần theo dõi thêm.',
    'R09': 'Phát hiện nguy cơ liên quan giữa thuốc sử dụng và tiền sử dị ứng.',
    'R10': 'Bệnh nền kết hợp với các dấu hiệu hiện tại làm tăng mức độ cần theo dõi.',
  };

  static String toUserMessage(String? raw) {
    var value = raw?.trim() ?? '';

    if (value.isEmpty) {
      return 'Chưa phát hiện cảnh báo sức khỏe.';
    }

    value = value
        .replaceAll(
          'Không có cảnh báo nào được kích hoạt',
          'Không phát hiện bất thường theo các ngưỡng sàng lọc hiện tại',
        )
        .replaceAll(
          'R01–R10',
          'các ngưỡng sàng lọc sức khỏe',
        );

    final match = RegExp(
      r'^(R\d{2}):?\s*(.*)$',
      dotAll: true,
    ).firstMatch(value);

    if (match == null) {
      return value;
    }

    final code = match.group(1)!;
    final knownMessage = _messages[code];

    if (knownMessage == null) {
      final detail = match.group(2)?.trim() ?? '';

      return detail.isEmpty
          ? 'Có cảnh báo sức khỏe cần được theo dõi thêm.'
          : detail;
    }

    final detail = match.group(2)?.trim() ?? '';

    final measurement =
        RegExp(r'\(([^()]*)\)').firstMatch(detail)?.group(1);

    return measurement == null
        ? knownMessage
        : '$knownMessage Giá trị ghi nhận: $measurement.';
  }
}
