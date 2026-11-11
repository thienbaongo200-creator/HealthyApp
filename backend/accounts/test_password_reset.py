import re
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password
from django.core import mail
from django.core.cache import cache
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.test import APITestCase

from accounts.models import PasswordResetCode


@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class PasswordResetFlowTests(APITestCase):
    email = "reset-user@example.com"
    old_password = "OldStrongPassword!873"
    new_password = "NewStrongPassword!482"

    def setUp(self):
        cache.clear()
        mail.outbox.clear()
        self.account = get_user_model().objects.create_user(
            email=self.email, password=self.old_password
        )
        self.forgot_url = reverse("auth-forgot-password")
        self.reset_url = reverse("auth-reset-password")

    def _request_code(self, email=None):
        return self.client.post(
            self.forgot_url,
            {"email": email or self.email},
            format="json",
            REMOTE_ADDR="198.51.100.20",
        )

    def _get_otp_from_mail(self):
        match = re.search(r"\b(\d{6})\b", mail.outbox[-1].body)
        self.assertIsNotNone(match, "Email must contain a six-digit OTP")
        return match.group(1)

    def _reset(self, otp, new_password=None):
        return self.client.post(
            self.reset_url,
            {
                "email": self.email,
                "otp": otp,
                "new_password": new_password or self.new_password,
            },
            format="json",
            REMOTE_ADDR="198.51.100.21",
        )

    def test_unknown_email_gets_same_generic_success_response(self):
        known = self._request_code()
        unknown = self._request_code("not-registered@example.com")

        self.assertEqual(known.status_code, status.HTTP_200_OK)
        self.assertEqual(unknown.status_code, status.HTTP_200_OK)
        self.assertEqual(known.data, unknown.data)
        self.assertEqual(PasswordResetCode.objects.count(), 1)

    def test_registered_email_creates_hashed_otp_expiry_and_sends_email(self):
        before = timezone.now()
        response = self._request_code()
        after = timezone.now()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        reset = PasswordResetCode.objects.get(account=self.account)
        otp = self._get_otp_from_mail()
        self.assertTrue(check_password(otp, reset.code_hash))
        self.assertNotEqual(otp, reset.code_hash)
        self.assertGreaterEqual(reset.expires_at, before + timedelta(minutes=15))
        self.assertLessEqual(reset.expires_at, after + timedelta(minutes=15))
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, [self.email])

    def test_forgot_password_is_throttled_after_configured_five_requests(self):
        cache.clear()
        with patch.object(
            ScopedRateThrottle,
            "THROTTLE_RATES",
            {"forgot_password": "5/hour"},
        ):
            responses = [self._request_code() for _ in range(6)]

        self.assertEqual(
            [response.status_code for response in responses[:5]],
            [status.HTTP_200_OK] * 5,
        )
        self.assertEqual(responses[5].status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_wrong_otp_is_rejected_and_increments_attempt_count(self):
        self._request_code()

        response = self._reset("000000")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Reset code is invalid or expired.")
        self.assertEqual(PasswordResetCode.objects.get(account=self.account).attempts, 1)

    def test_expired_otp_is_rejected(self):
        self._request_code()
        reset = PasswordResetCode.objects.get(account=self.account)
        reset.expires_at = timezone.now() - timedelta(seconds=1)
        reset.save(update_fields=["expires_at"])

        response = self._reset(self._get_otp_from_mail())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Reset code is invalid or expired.")
        self.assertTrue(check_password(self.old_password, self.account.password))

    def test_otp_is_rejected_after_five_failed_attempts(self):
        self._request_code()
        reset = PasswordResetCode.objects.get(account=self.account)
        reset.attempts = 5
        reset.save(update_fields=["attempts"])

        response = self._reset(self._get_otp_from_mail())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Reset code is invalid or expired.")

    def test_weak_password_is_rejected_without_changing_existing_password(self):
        self._request_code()
        otp = self._get_otp_from_mail()

        response = self._reset(otp, "12345678")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("new_password", response.data)
        self.account.refresh_from_db()
        self.assertTrue(check_password(self.old_password, self.account.password))
        self.assertTrue(PasswordResetCode.objects.filter(account=self.account).exists())

    def test_valid_reset_hashes_password_deletes_otp_and_allows_login(self):
        self._request_code()
        otp = self._get_otp_from_mail()

        response = self._reset(otp)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.account.refresh_from_db()
        self.assertTrue(check_password(self.new_password, self.account.password))
        self.assertNotEqual(self.new_password, self.account.password)
        self.assertFalse(PasswordResetCode.objects.filter(account=self.account).exists())
        login = self.client.post(
            reverse("auth-login"),
            {"email": self.email, "password": self.new_password},
            format="json",
        )
        self.assertEqual(login.status_code, status.HTTP_200_OK)
        self.assertIn("access", login.data)

    def test_reset_requires_six_digit_code(self):
        response = self._reset("12ab")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["detail"], "Reset code is invalid or expired.")
