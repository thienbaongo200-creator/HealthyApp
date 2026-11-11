class RiskMessageMapper {
  const RiskMessageMapper._();

  static const Map<String, String> _messages = {
    'R01': 'Huyết áp ghi nhận ở mức cần lưu ý.',
    'R02': 'Nhịp tim đo được cao hơn mức bình thường.',
    'R03': 'Thân nhiệt ghi nhận có dấu hiệu sốt.',
    'R04': 'Chỉ số đường huyết nằm ngoài khoảng khuyến nghị.',
    'R05': 'Chỉ số khối cơ thể (BMI) hoặc cân nặng cần được chú ý.',
    'R06': 'Thời lượng giấc ngủ khai báo thấp hơn mức khuyến nghị.',
    'R07': 'Mức độ vận động trong ngày chưa đạt mục tiêu.',
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