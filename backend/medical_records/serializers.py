from rest_framework import serializers

from .models import MedicalDocument


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
