import re

from rest_framework.exceptions import (
    AuthenticationFailed,
    NotAuthenticated,
    NotFound,
    PermissionDenied,
    Throttled,
    ValidationError,
)
from rest_framework.views import exception_handler as drf_exception_handler


_EXACT_MESSAGES = {
    "this field is required.": "Trường này là bắt buộc.",
    "this field may not be blank.": "Không được để trống trường này.",
    "this field may not be null.": "Trường này không được để trống.",
    "this field is required": "Trường này là bắt buộc.",
    "enter a valid email address.": "Địa chỉ email không hợp lệ.",
    "a valid email address is required.": "Địa chỉ email không hợp lệ.",
    "authentication credentials were not provided.": "Vui lòng đăng nhập để tiếp tục.",
    "you do not have permission to perform this action.": "Bạn không có quyền thực hiện thao tác này.",
    "not found.": "Không tìm thấy dữ liệu.",
    "invalid input.": "Dữ liệu không hợp lệ.",
    "a valid number is required.": "Vui lòng nhập một số hợp lệ.",
    "a valid integer is required.": "Vui lòng nhập một số nguyên hợp lệ.",
    "expected a boolean value.": "Giá trị phải là đúng hoặc sai.",
    "this value does not match the required format.": "Giá trị không đúng định dạng yêu cầu.",
    "ensure this field has no more than {max_length} characters.": "Trường này không được vượt quá {max_length} ký tự.",
    "ensure this field has at least {min_length} characters.": "Trường này phải có ít nhất {min_length} ký tự.",
    "ensure this value is less than or equal to {max_value}.": "Giá trị phải nhỏ hơn hoặc bằng {max_value}.",
    "ensure this value is greater than or equal to {min_value}.": "Giá trị phải lớn hơn hoặc bằng {min_value}.",
    "ensure this value is greater than {min_value}.": "Giá trị phải lớn hơn {min_value}.",
    "ensure this value is less than {max_value}.": "Giá trị phải nhỏ hơn {max_value}.",
}


def _translate_text(message, code=None):
    text = str(message)
    normalized = text.strip().lower()
    if _contains_vietnamese(text):
        return text
    if normalized in _EXACT_MESSAGES:
        return _EXACT_MESSAGES[normalized]

    if code == "required":
        return "Trường này là bắt buộc."
    if code == "blank":
        return "Không được để trống trường này."
    if code == "null":
        return "Trường này không được để trống."
    if code == "invalid" and normalized in {"invalid.", "invalid input."}:
        return "Giá trị không hợp lệ."
    if code == "password_too_short" or "password is too short" in normalized:
        return "Mật khẩu phải có ít nhất 8 ký tự."
    if code == "password_too_common" or "password is too common" in normalized:
        return "Mật khẩu quá phổ biến. Vui lòng chọn mật khẩu khác."
    if code == "password_entirely_numeric" or "entirely numeric" in normalized:
        return "Mật khẩu không được chỉ gồm chữ số."
    if code == "password_too_similar" or "password is too similar" in normalized:
        return "Mật khẩu quá giống với thông tin tài khoản. Vui lòng chọn mật khẩu khác."

    patterns = (
        (r"^ensure this field has no more than (\d+) characters?\.$", "Trường này không được vượt quá {} ký tự."),
        (r"^ensure this field has at least (\d+) characters?\.$", "Trường này phải có ít nhất {} ký tự."),
        (r"^ensure this value is less than or equal to (.+)\.$", "Giá trị phải nhỏ hơn hoặc bằng {}."),
        (r"^ensure this value is greater than or equal to (.+)\.$", "Giá trị phải lớn hơn hoặc bằng {}."),
        (r"^ensure this value is greater than (.+)\.$", "Giá trị phải lớn hơn {}."),
        (r"^ensure this value is less than (.+)\.$", "Giá trị phải nhỏ hơn {}."),
        (r"^ensure that there are no more than (\d+) digits in total\.$", "Giá trị không được có quá {} chữ số."),
        (r"^ensure that there are no more than (\d+) decimal places?\.$", "Giá trị không được có quá {} chữ số thập phân."),
    )
    for pattern, translated in patterns:
        match = re.match(pattern, normalized)
        if match:
            return translated.format(match.group(1))
    return None


def _contains_vietnamese(text):
    return any(character in text.lower() for character in "ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ")


def translate_validation_messages(messages):
    translated = []
    for message in messages:
        text = _translate_text(message, getattr(message, "code", None))
        translated.append(text or "Dữ liệu không hợp lệ.")
    return translated


def _translate_data(value):
    if isinstance(value, dict):
        return {key: _translate_data(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_translate_data(item) for item in value]

    code = getattr(value, "code", None)
    translated = _translate_text(value, code)
    if translated is not None:
        return translated
    text = str(value)
    if _contains_vietnamese(text):
        return text
    return "Dữ liệu không hợp lệ."


def vietnamese_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    if isinstance(exc, NotAuthenticated):
        response.data = {"detail": "Vui lòng đăng nhập để tiếp tục."}
    elif isinstance(exc, AuthenticationFailed):
        response.data = {"detail": "Thông tin xác thực không hợp lệ hoặc đã hết hạn."}
    elif isinstance(exc, PermissionDenied):
        detail = response.data.get("detail") if isinstance(response.data, dict) else None
        translated = _translate_text(detail) if detail is not None else None
        response.data = {
            "detail": translated or "Bạn không có quyền thực hiện thao tác này."
        }
    elif isinstance(exc, NotFound):
        detail = response.data.get("detail") if isinstance(response.data, dict) else None
        translated = _translate_text(detail) if detail is not None else None
        response.data = {"detail": translated or "Không tìm thấy dữ liệu."}
    elif isinstance(exc, Throttled):
        response.data = {"detail": "Bạn thao tác quá nhanh. Vui lòng thử lại sau."}
    else:
        response.data = _translate_data(response.data)
        if isinstance(exc, ValidationError):
            # Keep field-level detail while ensuring DRF defaults are localized.
            return response

    return response
