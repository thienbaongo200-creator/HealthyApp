from rest_framework import serializers

from health_measurements.models import HealthMeasurement
from profiles.models import PersonProfile


class HealthMeasurementSerializer(serializers.ModelSerializer):
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


class HealthMeasurementBatchSerializer(serializers.Serializer):
    measurements = HealthMeasurementSerializer(
        many=True,
        allow_empty=False,
        max_length=500,
    )

    def create(self, validated_data):
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
