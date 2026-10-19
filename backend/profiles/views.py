from django.db.models import Q
from rest_framework import status, viewsets
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import generics
from households.models import HouseholdMember, ProfileShare
from .models import PersonProfile
from .serializers import PersonProfileCreateSerializer, PersonProfileSerializer


def accessible_profiles_for(user):
    """Profiles readable by user, matching the existing owner/share rules."""
    owned = PersonProfile.objects.filter(
        Q(account=user) | Q(created_by=user),
        is_archived=False,
    )
    owner_household_ids = HouseholdMember.objects.filter(
        profile__in=owned, status="ACTIVE", role="OWNER"
    ).values_list("household_id", flat=True)
    shared_ids = ProfileShare.objects.filter(
        member__profile__in=owned,
        member__status="ACTIVE",
        share_level__in=("VIEW_ONLY", "VIEW_AND_LOG"),
    ).values_list("profile_id", flat=True)
    household_profile_ids = HouseholdMember.objects.filter(
        household_id__in=owner_household_ids, status="ACTIVE"
    ).values_list("profile_id", flat=True)
    return PersonProfile.objects.filter(
        Q(account=user)
        | Q(created_by=user)
        | Q(pk__in=shared_ids)
        | Q(pk__in=household_profile_ids),
        is_archived=False,
    ).distinct()


class PersonProfileViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = PersonProfileSerializer

    def get_queryset(self):
        return accessible_profiles_for(self.request.user)

    def get_serializer_class(self):
        if self.action == "create":
            return PersonProfileCreateSerializer
        return PersonProfileSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return Response(
            PersonProfileSerializer(
                profile,
                context=self.get_serializer_context(),
            ).data,
            status=status.HTTP_201_CREATED,
        )

    def perform_update(self, serializer):
        profile = self.get_object()
        if profile.account_id != self.request.user.pk and profile.created_by_id != self.request.user.pk:
            raise PermissionDenied("Only the profile owner can update this profile.")
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        profile = self.get_object()
        if profile.account_id != request.user.pk and profile.created_by_id != request.user.pk:
            raise PermissionDenied("Only the profile owner can archive this profile.")
        profile.is_archived = True
        profile.save(update_fields=["is_archived", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)

class ProfileListCreateView(generics.ListCreateAPIView):
    serializer_class = PersonProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Chỉ lấy các hồ sơ chưa bị archive của tài khoản hiện tại
        return accessible_profiles_for(self.request.user)

    def perform_create(self, serializer):
        # Khi tạo mới từ phía user, mặc định đây là hồ sơ DEPENDENT (hồ sơ SELF đã được tự động tạo khi Register)
        serializer.save(
            account=self.request.user,
            created_by=self.request.user,
            profile_type="DEPENDENT",
        )

class ProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PersonProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Đảm bảo user chỉ thao tác trên hồ sơ thuộc về chính tài khoản của họ
        return accessible_profiles_for(self.request.user)

    def perform_update(self, serializer):
        if (
            serializer.instance.account_id != self.request.user.pk
            and serializer.instance.created_by_id != self.request.user.pk
        ):
            raise PermissionDenied("Only the profile owner can update this profile.")
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        """Thay vì xóa cứng (DELETE), ta thực hiện archive mềm (is_archived = True)"""
        profile = self.get_object()
        if profile.account_id != request.user.pk and profile.created_by_id != request.user.pk:
            raise PermissionDenied("Only the profile owner can archive this profile.")
        if profile.profile_type == "SELF":
            return Response(
                {"detail": "Không thể xóa hoặc archive hồ sơ chính (SELF)."},
                status=status.HTTP_403_FORBIDDEN
            )
        
        profile.is_archived = True
        profile.save(update_fields=["is_archived", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)
