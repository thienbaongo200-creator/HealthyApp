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
            raise serializers.ValidationError("Danh sách chỉ số phải có định dạng hợp lệ.")
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Danh sách chỉ số không được có giá trị trùng lặp.")
        invalid = set(value) - VALID_METRICS
        if invalid:
            raise serializers.ValidationError(f"Các mã chỉ số không được hỗ trợ: {sorted(invalid)}")
        return value

    def validate(self, attrs):
        selected = attrs.get("selected_metrics", getattr(self.instance, "selected_metrics", []))
        order = attrs.get("metric_order", selected)
        if not isinstance(order, list) or len(order) != len(set(order)) or set(order) != set(selected):
            raise serializers.ValidationError({"metric_order": "Thứ tự phải chứa mỗi chỉ số đã chọn đúng một lần."})
        attrs["metric_order"] = order
        return attrs
