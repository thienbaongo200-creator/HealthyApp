from django.db.models import Q
from rest_framework import status, viewsets
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from households.models import HouseholdMember, ProfileShare
from .models import PersonProfile
from .serializers import PersonProfileCreateSerializer, PersonProfileSerializer


class PersonProfileViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = PersonProfileSerializer

    def get_queryset(self):
        user_profiles = PersonProfile.objects.filter(
            account=self.request.user,
            is_archived=False,
        )
        owner_household_ids = HouseholdMember.objects.filter(
            profile__in=user_profiles,
            status="ACTIVE",
            role="OWNER",
        ).values_list("household_id", flat=True)
        shared_profile_ids = ProfileShare.objects.filter(
            member__profile__in=user_profiles,
            member__status="ACTIVE",
            share_level__in=("VIEW_ONLY", "VIEW_AND_LOG"),
        ).values_list("profile_id", flat=True)
        household_profile_ids = HouseholdMember.objects.filter(
            household_id__in=owner_household_ids,
            status="ACTIVE",
        ).values_list("profile_id", flat=True)

        return PersonProfile.objects.filter(
            Q(account=self.request.user)
            | Q(pk__in=shared_profile_ids)
            | Q(pk__in=household_profile_ids),
            is_archived=False,
        ).distinct()

    def get_serializer_class(self):
        if self.action == "create":
            return PersonProfileCreateSerializer
        return PersonProfileSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return Response(
            PersonProfileSerializer(profile).data,
            status=status.HTTP_201_CREATED,
        )

    def perform_update(self, serializer):
        profile = self.get_object()
        if profile.account_id != self.request.user.pk:
            raise PermissionDenied("Only the profile owner can update this profile.")
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        profile = self.get_object()
        if profile.account_id != request.user.pk:
            raise PermissionDenied("Only the profile owner can archive this profile.")
        profile.is_archived = True
        profile.save(update_fields=["is_archived", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)
