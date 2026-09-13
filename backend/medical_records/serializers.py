from rest_framework import serializers
from .models import HealthMeasurement, PersonProfile

class HealthMeasurementSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthMeasurement
        fields = ['device_id', 'measured_at', 'idempotency_key', 'heart_rate', 'steps', 'calories']

class HealthMeasurementBatchSerializer(serializers.Serializer):
    measurements = HealthMeasurementSerializer(many=True)

    def create(self, validated_data):
        user = self.context['request'].user
        profile = PersonProfile.objects.get(user=user)
        measurements_data = validated_data.get('measurements', [])
        
        created_measurements = []
        for item in measurements_data:
            # Sử dụng get_or_create hoặc update_or_create dựa trên unique_constraint (profile + idempotency_key)
            obj, created = HealthMeasurement.objects.update_or_create(
                profile=profile,
                idempotency_key=item['idempotency_key'],
                defaults={
                    'device_id': item['device_id'],
                    'measured_at': item['measured_at'],
                    'heart_rate': item['heart_rate'],
                    'steps': item['steps'],
                    'calories': item['calories'],
                }
            )
            created_measurements.append(obj)
        return created_measurements