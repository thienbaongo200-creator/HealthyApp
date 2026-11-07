from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import PermissionService
from profiles.models import PersonProfile

from .models import Device
from .serializers import DeviceCreateSerializer, DeviceSerializer


class DeviceListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile_id = request.query_params.get("profile_id")
        queryset = Device.objects.filter(profile__is_archived=False)
        if profile_id:
            if not PermissionService.has_profile_access(request.user, profile_id):
                raise PermissionDenied("You do not have access to this profile.")
            queryset = queryset.filter(profile_id=profile_id)
        else:
            owned_profiles = PersonProfile.objects.filter(
                account=request.user,
                is_archived=False,
            ).values("id")
            queryset = queryset.filter(profile_id__in=owned_profiles)
        return Response(DeviceSerializer(queryset.order_by("-paired_at"), many=True).data)

    def post(self, request):
        serializer = DeviceCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        profile = get_object_or_404(
            PersonProfile,
            pk=data["profile_id"],
            is_archived=False,
        )
        if not PermissionService.has_profile_access(
            request.user,
            profile.pk,
            required_permission="measurement_write",
        ):
            raise PermissionDenied("You cannot pair a device to this profile.")
        device = Device.objects.filter(
            device_identifier=data["device_identifier"]
        ).first()
        if device and device.profile_id != profile.pk:
            raise PermissionDenied("This device is already paired with another profile.")
        created = device is None
        if device is None:
            device = Device.objects.create(
                profile=profile,
                device_identifier=data["device_identifier"],
                device_name=data.get("device_name", ""),
                status="ACTIVE",
            )
        else:
            device.device_name = data.get("device_name", device.device_name)
            device.status = "ACTIVE"
            device.save(update_fields=("device_name", "status", "updated_at"))
        return Response(
            DeviceSerializer(device).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class DeviceDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, device_id):
        device = get_object_or_404(Device, pk=device_id)
        if not PermissionService.has_profile_access(
            request.user,
            device.profile_id,
            required_permission="edit",
        ):
            raise PermissionDenied("You cannot revoke this device.")
        device.status = "REVOKED"
        device.save(update_fields=("status", "updated_at"))
        return Response(DeviceSerializer(device).data)
