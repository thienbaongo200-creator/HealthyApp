import uuid

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from health_measurements.models import HealthMeasurement

from .test_helpers import create_test_household_setup


class HealthMeasurementAPIIntegrationTestCase(APITestCase):
    def setUp(self):
        self.data = create_test_household_setup()
        self.measurement_list_url = reverse("measurement-list")
        self.measurement_batch_url = reverse("measurement-batch")
        self.measurement = HealthMeasurement.objects.create(
            profile=self.data["owner_profile"],
            measurement_type="HEART_RATE",
            value=75,
            unit="bpm",
            measured_at="2026-10-14T00:00:00Z",
            source="MANUAL",
        )
        self.measurement_detail_url = reverse(
            "measurement-detail",
            kwargs={"pk": self.measurement.pk},
        )

    def test_owner_can_crud_measurement(self):
        self.client.force_authenticate(user=self.data["owner_user"])
        idempotency_key = uuid.uuid4().hex

        create_response = self.client.post(
            self.measurement_batch_url,
            {
                "profile_id": str(self.data["owner_profile"].pk),
                "measurements": [
                    {
                        "measurement_type": "HEART_RATE",
                        "value": "80",
                        "unit": "bpm",
                        "measured_at": "2026-10-14T01:00:00Z",
                        "source": "MANUAL",
                        "idempotency_key": idempotency_key,
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(create_response.data["received_count"], 1)

        created_measurement = HealthMeasurement.objects.get(
            idempotency_key=idempotency_key,
        )
        self.assertEqual(created_measurement.profile, self.data["owner_profile"])
        detail_url = reverse(
            "measurement-detail",
            kwargs={"pk": created_measurement.pk},
        )

        list_response = self.client.get(self.measurement_list_url)
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertIn(
            "80.00",
            {item["value"] for item in list_response.data["results"]},
        )

        detail_response = self.client.get(detail_url)
        self.assertEqual(detail_response.status_code, status.HTTP_200_OK)
        self.assertEqual(detail_response.data["value"], "80.00")

        update_response = self.client.patch(
            detail_url,
            {"value": "82"},
            format="json",
        )
        self.assertEqual(update_response.status_code, status.HTTP_200_OK)
        created_measurement.refresh_from_db()
        self.assertEqual(created_measurement.value, 82)

        delete_response = self.client.delete(detail_url)
        self.assertEqual(delete_response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(
            HealthMeasurement.objects.filter(pk=created_measurement.pk).exists()
        )

    def test_owner_can_create_measurement_with_standard_post(self):
        self.client.force_authenticate(user=self.data["owner_user"])

        response = self.client.post(
            self.measurement_list_url,
            {
                "profile_id": str(self.data["owner_profile"].pk),
                "measurement_type": "HEART_RATE",
                "value": "78",
                "unit": "bpm",
                "source": "WEAR_OS",
                "measured_at": "2026-10-14T03:00:00Z",
                "idempotency_key": uuid.uuid4().hex,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = HealthMeasurement.objects.get(
            profile=self.data["owner_profile"],
            value=78,
        )
        self.assertEqual(created.measurement_type, "HEART_RATE")

    def test_standard_post_defaults_to_authenticated_users_self_profile(self):
        self.client.force_authenticate(user=self.data["owner_user"])

        response = self.client.post(
            self.measurement_list_url,
            {
                "measurement_type": "STEPS",
                "value": "1200",
                "unit": "steps",
                "source": "WEAR_OS",
                "measured_at": "2026-10-14T03:15:00Z",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        measurement = HealthMeasurement.objects.get(
            measurement_type="STEPS",
            value=1200,
        )
        self.assertEqual(measurement.profile, self.data["owner_profile"])

    def test_update_cannot_move_measurement_to_another_profile(self):
        self.client.force_authenticate(user=self.data["owner_user"])

        response = self.client.patch(
            self.measurement_detail_url,
            {"profile_id": str(self.data["outside_profile"].pk)},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.measurement.refresh_from_db()
        self.assertEqual(self.measurement.profile, self.data["owner_profile"])

    def test_standard_post_cannot_write_to_an_unshared_profile(self):
        self.client.force_authenticate(user=self.data["outside_user"])

        response = self.client.post(
            self.measurement_list_url,
            {
                "profile_id": str(self.data["owner_profile"].pk),
                "measurement_type": "HEART_RATE",
                "value": "78",
                "unit": "bpm",
                "source": "MANUAL",
                "measured_at": "2026-10-14T03:00:00Z",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            HealthMeasurement.objects.filter(
                profile=self.data["owner_profile"],
                value=78,
            ).count(),
            0,
        )

    def test_outside_user_idor_blocked(self):
        self.client.force_authenticate(user=self.data["outside_user"])

        response = self.client.get(self.measurement_detail_url)

        self.assertIn(
            response.status_code,
            [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND],
        )

    def test_view_only_member_cannot_create_log(self):
        self.client.force_authenticate(user=self.data["member_active_user"])

        response = self.client.post(
            self.measurement_batch_url,
            {
                "profile_id": str(self.data["owner_profile"].pk),
                "measurements": [
                    {
                        "measurement_type": "HEART_RATE",
                        "value": "80",
                        "unit": "bpm",
                        "measured_at": "2026-10-14T02:00:00Z",
                        "source": "MANUAL",
                    }
                ],
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_pending_member_access_blocked(self):
        self.client.force_authenticate(user=self.data["member_pending_user"])

        response = self.client.get(self.measurement_detail_url)

        self.assertIn(
            response.status_code,
            [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND],
        )
