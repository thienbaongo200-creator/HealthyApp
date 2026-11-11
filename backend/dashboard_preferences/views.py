from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from core.permissions import PermissionService
from profiles.models import PersonProfile
from .models import DashboardPreference
from .serializers import DashboardPreferenceSerializer, DEFAULT_METRICS


class DashboardPreferenceView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_profile(self, request, profile_id):
        profile = get_object_or_404(PersonProfile, pk=profile_id, is_archived=False)
        if not PermissionService.has_profile_access(request.user, profile.pk, "view"):
            raise PermissionDenied("You do not have permission to manage this profile dashboard.")
        return profile

    def get(self, request):
        profile_id = request.query_params.get("profile_id")
        if not profile_id:
            return Response({"profile_id": "This query parameter is required."}, status=400)
        profile = self._get_profile(request, profile_id)
        preference = DashboardPreference.objects.filter(profile=profile).first()
        if preference is None:
            return Response({"profile_id": str(profile.pk), "selected_metrics": DEFAULT_METRICS,
                             "metric_order": DEFAULT_METRICS, "updated_at": None})
        return Response(DashboardPreferenceSerializer(preference).data)

    def put(self, request):
        profile_id = request.data.get("profile_id")
        if not profile_id:
            return Response({"profile_id": "This field is required."}, status=400)
        profile = self._get_profile(request, profile_id)
        preference, _ = DashboardPreference.objects.get_or_create(
            profile=profile, defaults={"selected_metrics": DEFAULT_METRICS, "metric_order": DEFAULT_METRICS}
        )
        serializer = DashboardPreferenceSerializer(preference, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
