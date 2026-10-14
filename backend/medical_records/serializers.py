from rest_framework import serializers

from health_measurements.models import HealthMeasurement
from profiles.models import PersonProfile


class HealthMeasurementFieldsSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthMeasurement
        fields = [
            "measurement_type",
            "value",
            "value_secondary",
            "unit",
            "measured_at",
            "start_time",
            "end_time",
            "source",
            "device",
            "idempotency_key",
        ]
        extra_kwargs = {
            "device": {"required": False, "allow_null": True},
            "idempotency_key": {"required": False, "allow_null": True},
            "value_secondary": {"required": False, "allow_null": True},
            "start_time": {"required": False, "allow_null": True},
            "end_time": {"required": False, "allow_null": True},
        }


class HealthMeasurementSerializer(HealthMeasurementFieldsSerializer):
    profile_id = serializers.UUIDField(required=False, write_only=True)

    class Meta(HealthMeasurementFieldsSerializer.Meta):
        fields = [*HealthMeasurementFieldsSerializer.Meta.fields, "profile_id"]

    def create(self, validated_data):
        validated_data.pop("profile_id", None)
        return super().create(validated_data)

    def validate(self, attrs):
        if self.instance is not None and "profile_id" in self.initial_data:
            raise serializers.ValidationError(
                {"profile_id": "A measurement cannot be moved to another profile."}
            )
        return attrs


class HealthMeasurementBatchSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField(required=False, write_only=True)
    measurements = HealthMeasurementFieldsSerializer(
        many=True,
        allow_empty=False,
        max_length=500,
    )

    def create(self, validated_data):
        profile = validated_data.pop("profile", None)
        validated_data.pop("profile_id", None)
        if profile is None:
            account = self.context["request"].user
            profile, _ = PersonProfile.objects.get_or_create(
                account=account,
                profile_type="SELF",
                defaults={"full_name": account.email.partition("@")[0]},
            )
        measurements = [
            HealthMeasurement(profile=profile, **item)
            for item in validated_data["measurements"]
        ]
        return HealthMeasurement.objects.bulk_create(
            measurements,
            ignore_conflicts=True,
        )
