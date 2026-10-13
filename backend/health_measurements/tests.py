import uuid

from accounts.models import Account
from django.db import IntegrityError, transaction
from django.test import TestCase
from profiles.models import PersonProfile

from .models import HealthMeasurement


class HealthMeasurementModelTests(TestCase):
    def setUp(self):
        account = Account.objects.create_user(
            email="measurement-owner@example.com",
            password="safe-password",
        )
        self.profile = PersonProfile.objects.create(
            account=account,
            profile_type="SELF",
            full_name="Measurement Owner",
        )

    def test_profile_idempotency_key_pair_must_be_unique(self):
        idempotency_key = uuid.uuid4().hex
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="HEART_RATE",
            value=72,
            unit="bpm",
            measured_at="2026-10-04T05:00:00Z",
            source="WEAR_OS",
            idempotency_key=idempotency_key,
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                HealthMeasurement.objects.create(
                    profile=self.profile,
                    measurement_type="HEART_RATE",
                    value=73,
                    unit="bpm",
                    measured_at="2026-10-04T05:01:00Z",
                    source="WEAR_OS",
                    idempotency_key=idempotency_key,
                )

    def test_deleting_profile_cascades_to_measurements(self):
        measurement = HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="HEART_RATE",
            value=72,
            unit="bpm",
            measured_at="2026-10-04T05:00:00Z",
            source="WEAR_OS",
        )

        self.profile.delete()

        self.assertFalse(HealthMeasurement.objects.filter(pk=measurement.pk).exists())
