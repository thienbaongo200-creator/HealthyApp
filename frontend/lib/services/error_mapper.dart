class ErrorMapper {
  const ErrorMapper._();

  static const String _fallback =
      'Đã xảy ra lỗi. Vui lòng kiểm tra thông tin và thử lại.';

  static String toUserMessage(String? rawMessage) {
    var message = rawMessage?.trim() ?? '';
    if (message.isEmpty) return _fallback;

    message = message
        .replaceFirst(RegExp(r'^(Exception|ApiException|Bad state):\s*'), '')
        .trim();
    if (message.isEmpty) return _fallback;

    final normalized = message.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // Preserve already localized server/UI messages.
    if (_containsVietnamese(message)) return message;

    if (normalized.contains('this field is required') ||
        normalized.contains('is required') ||
        normalized.contains('are required')) {
      return 'Trường này là bắt buộc.';
    }
    if (normalized.contains('may not be blank') ||
        normalized.contains('may not be empty')) {
      return 'Không được để trống trường này.';
    }
    if (normalized.contains('valid email') ||
        normalized.contains('email address is invalid')) {
      return 'Địa chỉ email không hợp lệ.';
    }
    if (normalized.contains('authentication credentials were not provided') ||
        normalized.contains('not authenticated')) {
      return 'Vui lòng đăng nhập để tiếp tục.';
    }
    if (normalized.contains('permission') ||
        normalized.contains('not allowed') ||
        normalized.contains('forbidden')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (normalized == 'not found.' || normalized == 'not found') {
      return 'Không tìm thấy dữ liệu.';
    }
    if (normalized.contains('password is too similar')) {
      return 'Mật khẩu quá giống với thông tin tài khoản. Vui lòng chọn mật khẩu khác.';
    }
    if (normalized.contains('password is too short') ||
        normalized.contains('at least 8 characters')) {
      return 'Mật khẩu quá ngắn. Vui lòng nhập ít nhất 8 ký tự.';
    }
    if (normalized.contains('password is too common')) {
      return 'Mật khẩu này quá phổ biến. Vui lòng chọn mật khẩu khác.';
    }
    if (normalized.contains('username') &&
        (normalized.contains('already exists') ||
            normalized.contains('already in use'))) {
      return 'Tên đăng nhập này đã tồn tại trong hệ thống.';
    }
    if (normalized.contains('email') &&
        (normalized.contains('already exists') ||
            normalized.contains('already in use'))) {
      return 'Email này đã được đăng ký tài khoản trước đó.';
    }
    if (normalized.contains('reset code') &&
        (normalized.contains('invalid') || normalized.contains('expired'))) {
      return 'Mã xác nhận không hợp lệ hoặc đã hết hạn.';
    }
    if (normalized.contains('token') &&
        (normalized.contains('invalid') || normalized.contains('expired'))) {
      return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (normalized.contains('network') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused')) {
      return 'Không thể kết nối máy chủ. Vui lòng thử lại.';
    }
    if (normalized.contains('timed out') || normalized.contains('timeout')) {
      return 'Yêu cầu quá thời gian chờ. Vui lòng thử lại.';
    }
    if (normalized.contains('invalid') ||
        normalized.contains('must be') ||
        normalized.contains('expected')) {
      return 'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.';
    }

    return _fallback;
  }

  static bool _containsVietnamese(String value) =>
      RegExp(r'[ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]', caseSensitive: false)
          .hasMatch(value);
}
