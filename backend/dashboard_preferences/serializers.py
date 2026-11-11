from rest_framework import serializers
from health_measurements.models import HealthMeasurement
from .models import DashboardPreference


VALID_METRICS = {key for key, _ in HealthMeasurement.TYPE_CHOICES}
DEFAULT_METRICS = ["HEART_RATE", "BLOOD_PRESSURE", "BMI", "TEMPERATURE"]


class DashboardPreferenceSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = DashboardPreference
        fields = ("profile_id", "selected_metrics", "metric_order", "updated_at")
        read_only_fields = ("profile_id", "updated_at")

    def validate_selected_metrics(self, value):
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            raise serializers.ValidationError("Must be a list of metric codes.")
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Metric codes must be unique.")
        invalid = set(value) - VALID_METRICS
        if invalid:
            raise serializers.ValidationError(f"Unsupported metrics: {sorted(invalid)}")
        return value

    def validate(self, attrs):
        selected = attrs.get("selected_metrics", getattr(self.instance, "selected_metrics", []))
        order = attrs.get("metric_order", selected)
        if not isinstance(order, list) or len(order) != len(set(order)) or set(order) != set(selected):
            raise serializers.ValidationError({"metric_order": "Must contain each selected metric exactly once."})
        attrs["metric_order"] = order
        return attrs
