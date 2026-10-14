import uuid
from importlib import import_module
from unittest.mock import Mock

from accounts.models import Account
from datetime import datetime, timezone
from django.test import SimpleTestCase
from django.test import TestCase
from health_measurements.models import HealthMeasurement
from households.models import Household, HouseholdMember
from profiles.models import PersonProfile
from rest_framework.test import APIClient

from .models import (
    Allergy,
    LabResult,
    MedicalDocument,
    MedicalHistory,
    Medication,
    Visit,
)


class LegacyMigrationGuardTests(SimpleTestCase):
    def test_migration_refuses_to_delete_nonempty_legacy_tables(self):
        migration = import_module(
            "medical_records.migrations."
            "0002_allergy_labresult_medicaldocument_medicalhistory_and_more"
        )
        legacy_profile = Mock()
        legacy_profile.objects.using.return_value.count.return_value = 2
        legacy_measurement = Mock()
        legacy_measurement.objects.using.return_value.count.return_value = 3
        historical_apps = Mock()
        historical_models = {
            "PersonProfile": legacy_profile,
            "HealthMeasurement": legacy_measurement,
        }
        historical_apps.get_model.side_effect = (
            lambda app_label, model_name: historical_models[model_name]
        )
        schema_editor = Mock()
        schema_editor.connection.alias = "default"

        with self.assertRaisesMessage(
            RuntimeError,
            "found 2 PersonProfile row(s) and 3 HealthMeasurement row(s)",
        ):
            migration.prevent_legacy_data_loss(historical_apps, schema_editor)


class MedicalRecordModelTests(TestCase):
    def setUp(self):
        account = Account.objects.create_user(
            email="records@example.com",
            password="safe-password",
        )
        self.profile = PersonProfile.objects.create(
            account=account,
            profile_type="SELF",
            full_name="Records Owner",
        )

    def test_deleting_profile_cascades_to_medical_records(self):
        visit = Visit.objects.create(
            profile=self.profile,
            visited_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        records = (
            MedicalHistory.objects.create(profile=self.profile, condition="Condition"),
            Allergy.objects.create(profile=self.profile, allergen="Allergen"),
            visit,
            Medication.objects.create(
                profile=self.profile,
                visit=visit,
                name="Medication",
            ),
            LabResult.objects.create(
                profile=self.profile,
                visit=visit,
                test_name="Blood test",
                result="Normal",
                tested_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
            ),
            MedicalDocument.objects.create(
                profile=self.profile,
                visit=visit,
                title="Lab document",
                file_url="https://example.com/report.pdf",
            ),
        )

        self.profile.delete()

        for model in (MedicalHistory, Allergy, Visit, Medication, LabResult, MedicalDocument):
            with self.subTest(model=model.__name__):
                self.assertFalse(model.objects.exists())

    def test_deleting_visit_nulls_optional_medical_record_foreign_keys(self):
        visit = Visit.objects.create(
            profile=self.profile,
            visited_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        medication = Medication.objects.create(
            profile=self.profile,
            visit=visit,
            name="Medication",
        )
        lab_result = LabResult.objects.create(
            profile=self.profile,
            visit=visit,
            test_name="Blood test",
            result="Normal",
            tested_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        document = MedicalDocument.objects.create(
            profile=self.profile,
            visit=visit,
            title="Lab document",
            file_url="https://example.com/report.pdf",
        )

        visit.delete()

        medication.refresh_from_db()
        lab_result.refresh_from_db()
        document.refresh_from_db()
        self.assertIsNone(medication.visit)
        self.assertIsNone(lab_result.visit)
        self.assertIsNone(document.visit)


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

    def test_list_does_not_include_profiles_from_households_where_user_is_only_member(self):
        user_profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="Household User",
        )
        owner_household = Household.objects.create(
            name="Owned household",
            created_by=self.account,
        )
        HouseholdMember.objects.create(
            household=owner_household,
            profile=user_profile,
            account=self.account,
            role="OWNER",
            status="ACTIVE",
        )

        owner_visible_profile = PersonProfile.objects.create(
            profile_type="DEPENDENT",
            full_name="Owner household profile",
        )
        HouseholdMember.objects.create(
            household=owner_household,
            profile=owner_visible_profile,
            role="MEMBER",
            status="ACTIVE",
        )

        member_household = Household.objects.create(
            name="Member household",
            created_by=self.account,
        )
        HouseholdMember.objects.create(
            household=member_household,
            profile=user_profile,
            account=self.account,
            role="MEMBER",
            status="ACTIVE",
        )
        member_only_profile = PersonProfile.objects.create(
            profile_type="DEPENDENT",
            full_name="Member-only household profile",
        )
        HouseholdMember.objects.create(
            household=member_household,
            profile=member_only_profile,
            role="MEMBER",
            status="ACTIVE",
        )

        HealthMeasurement.objects.create(
            profile=owner_visible_profile,
            measurement_type="HEART_RATE",
            value=81,
            unit="bpm",
            measured_at="2026-10-04T05:00:00Z",
            source="MANUAL",
        )
        HealthMeasurement.objects.create(
            profile=member_only_profile,
            measurement_type="HEART_RATE",
            value=119,
            unit="bpm",
            measured_at="2026-10-04T06:00:00Z",
            source="MANUAL",
        )

        response = self.client.get("/api/medical/measurements/")

        self.assertEqual(response.status_code, 200)
        result_values = {item["value"] for item in response.data["results"]}
        self.assertIn("81.00", result_values)
        self.assertNotIn("119.00", result_values)
