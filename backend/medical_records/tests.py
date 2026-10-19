import uuid
from importlib import import_module
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock

from accounts.models import Account
from django.conf import settings
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase
from django.test import TestCase
from django.test.utils import override_settings
from health_measurements.models import HealthMeasurement
from households.models import Household, HouseholdMember, ProfileShare
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

    def test_list_can_filter_measurements_by_accessible_profile(self):
        primary_profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="Primary profile",
        )
        dependent_profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="DEPENDENT",
            full_name="Dependent profile",
        )
        for profile, value in ((primary_profile, 72), (dependent_profile, 85)):
            HealthMeasurement.objects.create(
                profile=profile,
                measurement_type="HEART_RATE",
                value=value,
                unit="bpm",
                measured_at="2026-10-04T05:00:00Z",
                source="MANUAL",
            )

        response = self.client.get(
            "/api/medical/measurements/",
            {"profile_id": str(dependent_profile.pk)},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["results"]), 1)
        self.assertEqual(response.data["results"][0]["value"], "85.00")

    def test_caregiver_can_only_read_measurements_after_owner_ai_consent(self):
        owner = Account.objects.create_user(
            email="measurement-owner@example.com",
            password="test-password-123",
        )
        owner_profile = PersonProfile.objects.create(
            account=owner,
            profile_type="SELF",
            full_name="Measurement Owner",
        )
        caregiver_profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="Measurement Caregiver",
        )
        household = Household.objects.create(
            name="Caregiver Measurements",
            created_by=owner,
        )
        HouseholdMember.objects.create(
            household=household,
            account=owner,
            profile=owner_profile,
            role="OWNER",
            status="ACTIVE",
        )
        caregiver_membership = HouseholdMember.objects.create(
            household=household,
            account=self.account,
            profile=caregiver_profile,
            role="CAREGIVER",
            status="ACTIVE",
        )
        ProfileShare.objects.create(
            member=caregiver_membership,
            profile=owner_profile,
            share_level="VIEW_AND_LOG",
        )
        HealthMeasurement.objects.create(
            profile=owner_profile,
            measurement_type="HEART_RATE",
            value=75,
            unit="bpm",
            measured_at="2026-10-04T05:00:00Z",
            source="MANUAL",
        )

        url = "/api/medical/measurements/"
        denied = self.client.get(url, {"profile_id": str(owner_profile.pk)})
        self.assertEqual(denied.status_code, 403)

        owner.ai_consent = True
        owner.save(update_fields=["ai_consent"])
        allowed = self.client.get(url, {"profile_id": str(owner_profile.pk)})
        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(len(allowed.data["results"]), 1)

    def test_list_rejects_invalid_profile_id(self):
        response = self.client.get(
            "/api/medical/measurements/",
            {"profile_id": "not-a-uuid"},
        )

        self.assertEqual(response.status_code, 400)


@override_settings(MEDIA_ROOT=settings.BASE_DIR / "test_private_uploads")
class MedicalDocumentApiTests(TestCase):
    def setUp(self):
        self.owner = Account.objects.create_user(
            email="document-owner@example.com",
            password="test-password",
        )
        self.owner_profile = PersonProfile.objects.create(
            account=self.owner,
            profile_type="SELF",
            full_name="Document Owner",
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def tearDown(self):
        for document in MedicalDocument.objects.all():
            if document.file:
                document.file.delete(save=False)
        super().tearDown()

    def upload_pdf(self, profile_id, name="report.pdf", content=b"%PDF-1.4 sample"):
        return self.client.post(
            "/api/medical/documents/",
            {
                "profile_id": str(profile_id),
                "document_type": "LAB_RESULT",
                "title": "Lab report",
                "description": "Annual blood test",
                "file": SimpleUploadedFile(
                    name,
                    content,
                    content_type="application/pdf",
                ),
            },
            format="multipart",
        )

    def test_upload_list_and_download_document_for_profile_owner(self):
        upload_response = self.upload_pdf(self.owner_profile.pk)

        self.assertEqual(upload_response.status_code, 201)
        document = MedicalDocument.objects.get()
        self.assertEqual(document.profile_id, self.owner_profile.pk)
        self.assertTrue(document.file.name.startswith(
            f"medical_documents/{self.owner_profile.pk}/"
        ))
        self.assertEqual(upload_response.data["profile_id"], str(self.owner_profile.pk))
        self.assertEqual(upload_response.data["file_url"], "")
        self.assertTrue(upload_response.data["file_name"].endswith(".pdf"))
        self.assertNotIn("file", upload_response.data)

        list_response = self.client.get("/api/medical/documents/")
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.data), 1)

        download_response = self.client.get(
            f"/api/medical/documents/{document.pk}/download/"
        )
        self.assertEqual(download_response.status_code, 200)
        self.assertEqual(b"".join(download_response.streaming_content), b"%PDF-1.4 sample")
        self.assertIn("attachment;", download_response["Content-Disposition"])
        self.assertEqual(download_response["Cache-Control"], "private, no-store")
        self.assertEqual(download_response["X-Content-Type-Options"], "nosniff")

    def test_canonical_medical_records_document_route_supports_upload_and_delete(self):
        response = self.client.post(
            "/api/medical-records/documents/",
            {
                "profile_id": str(self.owner_profile.pk),
                "document_type": "IMAGING",
                "title": "X-ray",
                "file": SimpleUploadedFile(
                    "x-ray.png",
                    b"png image data",
                    content_type="image/png",
                ),
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, 201)

        document_id = response.data["id"]
        delete_response = self.client.delete(
            f"/api/medical-records/documents/{document_id}/"
        )
        self.assertEqual(delete_response.status_code, 204)
        self.assertFalse(MedicalDocument.objects.filter(pk=document_id).exists())

    def test_document_list_filters_by_profile(self):
        dependent_profile = PersonProfile.objects.create(
            account=self.owner,
            profile_type="DEPENDENT",
            full_name="Dependent",
        )
        MedicalDocument.objects.create(
            profile=self.owner_profile,
            title="Self document",
            file_url="https://example.com/self.pdf",
        )
        dependent_document = MedicalDocument.objects.create(
            profile=dependent_profile,
            title="Dependent document",
            file_url="https://example.com/dependent.pdf",
        )

        response = self.client.get(
            "/api/medical/documents/",
            {"profile_id": str(dependent_profile.pk)},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], str(dependent_document.pk))

    def test_profile_without_edit_access_cannot_upload_delete_or_download(self):
        another_owner = Account.objects.create_user(
            email="another-document-owner@example.com",
            password="test-password",
        )
        another_profile = PersonProfile.objects.create(
            account=another_owner,
            profile_type="SELF",
            full_name="Another Owner",
        )
        document = MedicalDocument.objects.create(
            profile=another_profile,
            title="Private record",
            file_url="",
        )

        upload_response = self.upload_pdf(another_profile.pk)
        delete_response = self.client.delete(
            f"/api/medical/documents/{document.pk}/"
        )
        retrieve_response = self.client.get(
            f"/api/medical/documents/{document.pk}/"
        )
        download_response = self.client.get(
            f"/api/medical/documents/{document.pk}/download/"
        )

        self.assertEqual(upload_response.status_code, 403)
        self.assertEqual(delete_response.status_code, 403)
        self.assertEqual(retrieve_response.status_code, 404)
        self.assertEqual(download_response.status_code, 404)
        self.assertTrue(MedicalDocument.objects.filter(pk=document.pk).exists())

    def test_legacy_url_backed_document_remains_listable_and_downloadable(self):
        document = MedicalDocument.objects.create(
            profile=self.owner_profile,
            title="Legacy report",
            file_url="https://example.com/legacy-report.pdf",
        )

        list_response = self.client.get("/api/medical/documents/")
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(list_response.data[0]["file_url"], document.file_url)

        download_response = self.client.get(
            f"/api/medical/documents/{document.pk}/download/"
        )
        self.assertEqual(download_response.status_code, 302)
        self.assertEqual(download_response["Location"], document.file_url)

    def test_delete_removes_uploaded_file(self):
        response = self.upload_pdf(self.owner_profile.pk)
        self.assertEqual(response.status_code, 201)
        document = MedicalDocument.objects.get()
        stored_path = Path(document.file.path)

        delete_response = self.client.delete(
            f"/api/medical/documents/{document.pk}/"
        )

        self.assertEqual(delete_response.status_code, 204)
        self.assertFalse(MedicalDocument.objects.filter(pk=document.pk).exists())
        self.assertFalse(stored_path.exists())

    def test_upload_rejects_unsupported_file_type(self):
        response = self.client.post(
            "/api/medical/documents/",
            {
                "profile_id": str(self.owner_profile.pk),
                "title": "Unsupported",
                "file": SimpleUploadedFile(
                    "notes.txt",
                    b"not a medical document",
                    content_type="text/plain",
                ),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("file", response.data)

    def test_upload_rejects_files_over_ten_megabytes(self):
        response = self.client.post(
            "/api/medical/documents/",
            {
                "profile_id": str(self.owner_profile.pk),
                "title": "Oversized report",
                "file": SimpleUploadedFile(
                    "report.pdf",
                    b"x" * (10 * 1024 * 1024 + 1),
                    content_type="application/pdf",
                ),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("file", response.data)
