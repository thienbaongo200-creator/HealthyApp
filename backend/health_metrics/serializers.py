from rest_framework import serializers
from .models import HealthData

class HealthDataSerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthData
        fields = ['id', 'user', 'heart_rate', 'steps', 'calories', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']