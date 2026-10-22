from datetime import timedelta

from django.conf import settings
from django.test import SimpleTestCase


class JwtLifetimeSettingsTestCase(SimpleTestCase):
    def test_lifetimes_follow_explicit_test_mode(self):
        expected_access = (
            timedelta(seconds=60)
            if settings.JWT_TEST_MODE
            else timedelta(minutes=60)
        )
        expected_refresh = (
            timedelta(days=1) if settings.JWT_TEST_MODE else timedelta(days=7)
        )

        self.assertEqual(settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'], expected_access)
        self.assertEqual(
            settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'],
            expected_refresh,
        )

    def test_scoped_throttle_rates_use_test_overrides(self):
        expected_rates = (
            {'login': '1000/min', 'ai_chat': '1000/min'}
            if settings.API_THROTTLE_TEST_MODE
            else {'login': '10/min', 'ai_chat': '20/min'}
        )

        self.assertEqual(
            settings.REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'],
            expected_rates,
        )
