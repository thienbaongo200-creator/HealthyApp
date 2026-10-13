import uuid

from accounts.models import Account
from django.test import TestCase
from health_measurements.models import HealthMeasurement
from rest_framework.test import APIClient


class HealthMeasurementBatchApiTests(TestCase):
    def setUp(self):
        self.account = Account.objects.create_user(
            email="health@example.com",
            password="test-password",
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.account)

    def test_batch_creates_measurements_for_account_profile(self):
        measurement = {
            "measurement_type": "HEART_RATE",
            "value": "72",
            "unit": "bpm",
            "measured_at": "2026-10-04T05:00:00Z",
            "source": "WEAR_OS",
            "idempotency_key": str(uuid.uuid4()),
        }

        response = self.client.post(
            "/api/medical/measurements/batch/",
            {"measurements": [measurement]},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["received_count"], 1)
        self.assertEqual(HealthMeasurement.objects.count(), 1)
        created = HealthMeasurement.objects.get()
        self.assertEqual(created.measurement_type, "HEART_RATE")
        self.assertEqual(created.profile.account, self.account)

    def test_batch_retry_does_not_duplicate_idempotency_key(self):
        measurement = {
            "measurement_type": "HEART_RATE",
            "value": "120",
            "unit": "bpm",
            "measured_at": "2026-10-04T05:00:00Z",
            "source": "WEAR_OS",
            "idempotency_key": str(uuid.uuid4()),
        }
        url = "/api/medical/measurements/batch/"

        first_response = self.client.post(
            url,
            {"measurements": [measurement]},
            format="json",
        )
        retry_response = self.client.post(
            url,
            {"measurements": [measurement]},
            format="json",
        )

        self.assertEqual(first_response.status_code, 201)
        self.assertEqual(retry_response.status_code, 201)
        self.assertEqual(HealthMeasurement.objects.count(), 1)
