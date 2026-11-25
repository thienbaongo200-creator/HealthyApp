from django.test import SimpleTestCase
from rest_framework.exceptions import ErrorDetail

from core.exceptions import _translate_data, _translate_text


class VietnameseErrorTranslationTests(SimpleTestCase):
    def test_standard_serializer_errors_are_translated(self):
        self.assertEqual(
            _translate_text(ErrorDetail("This field is required.", code="required")),
            "Trường này là bắt buộc.",
        )
        self.assertEqual(
            _translate_text(ErrorDetail("This field may not be blank.", code="blank")),
            "Không được để trống trường này.",
        )
        self.assertEqual(
            _translate_text("Enter a valid email address."),
            "Địa chỉ email không hợp lệ.",
        )

    def test_nested_serializer_errors_keep_fields_and_translate_values(self):
        result = _translate_data(
            {"email": [ErrorDetail("Enter a valid email address.", code="invalid")]}
        )
        self.assertEqual(result, {"email": ["Địa chỉ email không hợp lệ."]})

    def test_length_validation_keeps_the_limit(self):
        self.assertEqual(
            _translate_text("Ensure this field has no more than 12 characters."),
            "Trường này không được vượt quá 12 ký tự.",
        )

