import uuid

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from .models import HealthMeasurement


class HealthMeasurementBatchApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='health-test',
            password='test-password',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_batch_creates_measurements_with_activity_state(self):
        measurement = {
            'device_id': 'wear-os-test',
            'measured_at': '2026-10-04T05:00:00Z',
            'idempotency_key': str(uuid.uuid4()),
            'heart_rate': 72,
            'steps': 12,
            'calories': '1.25',
            'activity_state': 'resting',
        }

        response = self.client.post(
            '/api/medical/measurements/batch/',
            {'measurements': [measurement]},
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['received_count'], 1)
        self.assertEqual(HealthMeasurement.objects.count(), 1)
        self.assertEqual(
            HealthMeasurement.objects.get().activity_state,
            'resting',
        )

    def test_batch_retry_does_not_duplicate_idempotency_key(self):
        measurement = {
            'device_id': 'wear-os-test',
            'measured_at': '2026-10-04T05:00:00Z',
            'idempotency_key': str(uuid.uuid4()),
            'heart_rate': 120,
            'steps': 200,
            'calories': '8.50',
            'activity_state': 'active',
        }
        url = '/api/medical/measurements/batch/'

        first_response = self.client.post(
            url,
            {'measurements': [measurement]},
            format='json',
        )
        retry_response = self.client.post(
            url,
            {'measurements': [measurement]},
            format='json',
        )

        self.assertEqual(first_response.status_code, 201)
        self.assertEqual(retry_response.status_code, 201)
        self.assertEqual(HealthMeasurement.objects.count(), 1)
