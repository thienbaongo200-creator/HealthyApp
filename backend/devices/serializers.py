from rest_framework import serializers

from .models import Device


class DeviceSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = Device
        fields = (
            "id",
            "profile_id",
            "device_identifier",
            "device_name",
            "status",
            "paired_at",
            "last_synced_at",
        )
        read_only_fields = ("id", "status", "paired_at", "last_synced_at")


class DeviceCreateSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    device_identifier = serializers.CharField(max_length=255)
    device_name = serializers.CharField(max_length=255, required=False, allow_blank=True)
