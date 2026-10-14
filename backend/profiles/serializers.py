from rest_framework import serializers
from .models import PersonProfile


class PersonProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PersonProfile
        fields = [
            "id",
            "profile_type",
            "full_name",
            "date_of_birth",
            "gender",
            "height_cm",
            "weight_kg",
            "blood_type",
            "emergency_contact",
            "is_archived",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "profile_type", "is_archived", "created_at", "updated_at"]


class PersonProfileCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PersonProfile
        fields = [
            "profile_type",
            "full_name",
            "date_of_birth",
            "gender",
            "height_cm",
            "weight_kg",
            "blood_type",
            "emergency_contact",
        ]

    def validate_profile_type(self, value):
        if value not in {"SELF", "DEPENDENT"}:
            raise serializers.ValidationError("Unsupported profile type.")
        return value

    def create(self, validated_data):
        return PersonProfile.objects.create(
            account=self.context["request"].user,
            **validated_data,
        )
