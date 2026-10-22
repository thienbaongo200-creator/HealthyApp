from rest_framework import serializers

from profiles.models import PersonProfile

from .models import (
    Allergy,
    LabResult,
    MedicalDocument,
    MedicalHistory,
    Medication,
    Visit,
)


class ProfileScopedMedicalRecordSerializer(serializers.ModelSerializer):
    profile_id = serializers.PrimaryKeyRelatedField(
        source="profile",
        queryset=PersonProfile.objects.filter(is_archived=False),
    )

    def validate_profile_id(self, profile):
        if self.instance and profile.pk != self.instance.profile_id:
            raise serializers.ValidationError(
                "A medical record cannot be moved to another profile."
            )
        return profile


class MedicalHistorySerializer(ProfileScopedMedicalRecordSerializer):
    class Meta:
        model = MedicalHistory
        fields = (
            "id",
            "profile_id",
            "condition",
            "description",
            "diagnosed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class AllergySerializer(ProfileScopedMedicalRecordSerializer):
    class Meta:
        model = Allergy
        fields = (
            "id",
            "profile_id",
            "allergen",
            "reaction",
            "severity",
            "notes",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class VisitSerializer(ProfileScopedMedicalRecordSerializer):
    class Meta:
        model = Visit
        fields = (
            "id",
            "profile_id",
            "provider_name",
            "facility_name",
            "visited_at",
            "reason",
            "diagnosis",
            "notes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class VisitScopedMedicalRecordSerializer(ProfileScopedMedicalRecordSerializer):
    def validate(self, attrs):
        attrs = super().validate(attrs)
        profile = attrs.get("profile", self.instance.profile if self.instance else None)
        visit = attrs.get("visit", self.instance.visit if self.instance else None)
        if visit and profile and visit.profile_id != profile.pk:
            raise serializers.ValidationError(
                {"visit": "The visit must belong to the same profile."}
            )
        return attrs


class MedicationSerializer(VisitScopedMedicalRecordSerializer):
    class Meta:
        model = Medication
        fields = (
            "id",
            "profile_id",
            "visit",
            "name",
            "dosage",
            "frequency",
            "start_date",
            "end_date",
            "instructions",
            "status",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class LabResultSerializer(VisitScopedMedicalRecordSerializer):
    class Meta:
        model = LabResult
        fields = (
            "id",
            "profile_id",
            "visit",
            "test_name",
            "result",
            "unit",
            "reference_range",
            "tested_at",
            "notes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class MedicalDocumentSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField()
    file = serializers.FileField(write_only=True, required=True, allow_empty_file=False)
    file_name = serializers.SerializerMethodField()

    MAX_FILE_SIZE = 10 * 1024 * 1024
    ALLOWED_FILE_TYPES = {
        ".pdf": {"application/pdf", "application/octet-stream"},
        ".jpg": {"image/jpeg", "application/octet-stream"},
        ".jpeg": {"image/jpeg", "application/octet-stream"},
        ".png": {"image/png", "application/octet-stream"},
    }

    class Meta:
        model = MedicalDocument
        fields = (
            "id",
            "profile_id",
            "visit",
            "document_type",
            "title",
            "file_name",
            "file_url",
            "file",
            "description",
            "uploaded_at",
        )
        read_only_fields = ("id", "file_url", "uploaded_at")

    def create(self, validated_data):
        validated_data.pop("profile_id")
        return super().create(validated_data)

    def get_file_name(self, instance):
        if instance.file:
            return instance.file.name.rsplit("/", 1)[-1]
        return instance.file_url.rsplit("/", 1)[-1] if instance.file_url else ""

    def validate_file(self, uploaded_file):
        if uploaded_file.size > self.MAX_FILE_SIZE:
            raise serializers.ValidationError("File size must not exceed 10 MB.")

        extension = "." + uploaded_file.name.rsplit(".", 1)[-1].lower()
        allowed_content_types = self.ALLOWED_FILE_TYPES.get(extension)
        if allowed_content_types is None:
            raise serializers.ValidationError(
                "Only PDF, JPEG, and PNG files are supported."
            )

        content_type = getattr(uploaded_file, "content_type", None)
        if content_type and content_type not in allowed_content_types:
            raise serializers.ValidationError(
                "The file extension and content type do not match."
            )

        return uploaded_file
