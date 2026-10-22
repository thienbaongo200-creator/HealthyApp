from rest_framework import serializers

from .models import HealthMeasurement


class HealthMeasurementFieldsSerializer(serializers.ModelSerializer):
    """Input contract and broad sanity bounds for one measurement."""

    source = serializers.ChoiceField(
        choices=HealthMeasurement.SOURCE_CHOICES,
        required=False,
        default="MANUAL",
    )
    device = serializers.PrimaryKeyRelatedField(read_only=True)

    VALUE_RANGES = {
        # Broad input sanity bounds; these are not diagnostic/clinical thresholds.
        "HEART_RATE": (30, 220),
        "BMI": (5, 100),
        "STEPS": (0, 200_000),
        "CALORIES": (0, 10_000),
        "WEIGHT": (1, 500),
        "HEIGHT": (30, 300),
        "TEMPERATURE": (25, 45),
        "SLEEP": (0, 24),
    }
    GLUCOSE_RANGES = {
        "mg/dl": (20, 600),
        "mmol/l": (1.1, 33.3),
    }

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

    def validate(self, attrs):
        errors = {}
        if self.initial_data.get("device") not in (None, ""):
            errors["device"] = "Device association is assigned by the server."
        if errors:
            raise serializers.ValidationError(errors)

        measurement_type = attrs.get(
            "measurement_type",
            getattr(self.instance, "measurement_type", None),
        )
        value = attrs.get("value", getattr(self.instance, "value", None))
        secondary = attrs.get(
            "value_secondary",
            getattr(self.instance, "value_secondary", None),
        )
        unit = attrs.get("unit", getattr(self.instance, "unit", ""))
        start_time = attrs.get(
            "start_time",
            getattr(self.instance, "start_time", None),
        )
        end_time = attrs.get(
            "end_time",
            getattr(self.instance, "end_time", None),
        )
        if measurement_type is None or value is None:
            return attrs
        errors = {}

        if measurement_type == "BLOOD_PRESSURE":
            if secondary is None:
                errors["value_secondary"] = "Diastolic pressure is required."
            else:
                if not 40 <= value <= 250:
                    errors["value"] = "Systolic pressure must be between 40 and 250 mmHg."
                if not 40 <= secondary <= 250:
                    errors["value_secondary"] = "Diastolic pressure must be between 40 and 250 mmHg."
                if value <= secondary:
                    errors["value"] = "Systolic pressure must be greater than diastolic pressure."
        else:
            if secondary is not None:
                errors["value_secondary"] = "Only blood pressure accepts a secondary value."

            value_range = self.VALUE_RANGES.get(measurement_type)
            if measurement_type == "BLOOD_GLUCOSE":
                unit_key = str(unit).strip().lower()
                value_range = self.GLUCOSE_RANGES.get(unit_key)
                if value_range is None:
                    errors["unit"] = "Use mg/dL or mmol/L for blood glucose."

            if value_range is not None and not value_range[0] <= value <= value_range[1]:
                errors["value"] = (
                    f"Value for {measurement_type} must be between "
                    f"{value_range[0]} and {value_range[1]}."
                )

            if measurement_type in {"STEPS", "CALORIES"}:
                if value != value.to_integral_value():
                    errors["value"] = f"{measurement_type} must be a whole number."
                if start_time is None or end_time is None:
                    errors["start_time"] = (
                        "start_time and end_time are required for cumulative measurements."
                    )
                elif end_time <= start_time:
                    errors["end_time"] = "end_time must be later than start_time."

        if errors:
            raise serializers.ValidationError(errors)
        return attrs


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
        if self.initial_data.get("source") not in (None, "MANUAL"):
            raise serializers.ValidationError(
                {"source": "Measurement source is assigned by the server."}
            )
        return super().validate(attrs)


class HealthMeasurementBatchSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField(required=False, write_only=True)
    measurements = serializers.ListField(
        child=serializers.JSONField(allow_null=True),
        allow_empty=False,
        min_length=1,
        max_length=100,
    )
