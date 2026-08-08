from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status


class HealthDataAPITest(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_create_health_data(self):
        payload = {
            'heart_rate': 75,
            'steps': 1500,
            'calories': 12.5
        }
        response = self.client.post('/api/health/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_list_health_data(self):
        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
