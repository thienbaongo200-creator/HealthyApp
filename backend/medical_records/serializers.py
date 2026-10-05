from rest_framework import serializers
from .models import HealthMeasurement, PersonProfile

class HealthMeasurementSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthMeasurement
        fields = [
            'device_id',
            'measured_at',
            'idempotency_key',
            'heart_rate',
            'steps',
            'calories',
            'activity_state',
        ]

class HealthMeasurementBatchSerializer(serializers.Serializer):
    measurements = HealthMeasurementSerializer(
        many=True,
        allow_empty=False,
        max_length=500,
    )

    def create(self, validated_data):
        user = self.context['request'].user
        profile, _ = PersonProfile.objects.get_or_create(user=user)
        measurements_data = validated_data.get('measurements', [])
        measurements = [
            HealthMeasurement(profile=profile, **item)
            for item in measurements_data
        ]
        return HealthMeasurement.objects.bulk_create(
            measurements,
            ignore_conflicts=True,
        )