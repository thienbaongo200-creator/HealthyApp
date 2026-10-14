from rest_framework import viewsets, status
from rest_framework.exceptions import PermissionDenied
from core.permissions import IsProfileOwnerOrShared, PermissionService
from health_measurements.models import HealthMeasurement
from profiles.models import PersonProfile
from households.models import HouseholdMember, ProfileShare
from .serializers import HealthMeasurementSerializer, HealthMeasurementBatchSerializer
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from rest_framework.views import APIView

class HealthMeasurementPagination(PageNumberPagination):
    page_size = 100

class HealthMeasurementViewSet(viewsets.ModelViewSet):
    serializer_class = HealthMeasurementSerializer
    permission_classes = [IsProfileOwnerOrShared]
    pagination_class = HealthMeasurementPagination

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return HealthMeasurement.objects.none()

        # Lấy tất cả profile hợp lệ của user đang đăng nhập
        user_profiles = PersonProfile.objects.filter(account=user, is_archived=False)
        
        # 1. Profile của chính user
        owned_profile_ids = list(user_profiles.values_list('id', flat=True))
        
        # 2. Profile được chia sẻ qua ProfileShare (thành viên ACTIVE và có cấp độ quyền xem)
        shared_profile_ids = list(ProfileShare.objects.filter(
            member__profile__in=user_profiles,
            member__status='ACTIVE',
            share_level__in=['VIEW_ONLY', 'VIEW_AND_LOG', 'FULL']
        ).values_list('profile_id', flat=True))
        
        # 3. Other profiles are visible only in households where this user is an active OWNER.
        owner_household_ids = HouseholdMember.objects.filter(
            profile__in=user_profiles,
            status='ACTIVE',
            role='OWNER',
        ).values_list('household_id', flat=True)
        household_profile_ids = list(HouseholdMember.objects.filter(
            household_id__in=owner_household_ids,
            status='ACTIVE',
        ).values_list('profile_id', flat=True))

        # Gộp tất cả các ID profile được phép xem vào tập duy nhất
        allowed_profile_ids = set(owned_profile_ids + shared_profile_ids + household_profile_ids)

        return HealthMeasurement.objects.filter(
            profile_id__in=allowed_profile_ids
        ).order_by('-measured_at')

    def perform_create(self, serializer):
        profile_id = serializer.validated_data.get("profile_id")
        if profile_id is None:
            profile, _ = PersonProfile.objects.get_or_create(
                account=self.request.user,
                profile_type="SELF",
                defaults={"full_name": self.request.user.email.partition("@")[0]},
            )
        else:
            if not PermissionService.has_profile_access(
                self.request.user,
                profile_id,
                required_permission="edit",
            ):
                raise PermissionDenied(
                    "You do not have permission to add measurements to this profile."
                )
            profile = PersonProfile.objects.get(pk=profile_id)

        if not PermissionService.has_profile_access(
            self.request.user,
            profile.pk,
            required_permission="edit",
        ):
            raise PermissionDenied(
                "You do not have permission to add measurements to this profile."
            )

        serializer.save(profile=profile)


class HealthMeasurementBatchCreateView(APIView):
    permission_classes = [IsProfileOwnerOrShared]

    def post(self, request, *args, **kwargs):
        serializer = HealthMeasurementBatchSerializer(
            data=request.data,
            context={"request": request},
        )
        if serializer.is_valid():
            profile_id = serializer.validated_data.get("profile_id")
            if profile_id is None:
                profile, _ = PersonProfile.objects.get_or_create(
                    account=request.user,
                    profile_type="SELF",
                    defaults={"full_name": request.user.email.partition("@")[0]},
                )
            else:
                if not PermissionService.has_profile_access(
                    request.user,
                    profile_id,
                    required_permission="edit",
                ):
                    raise PermissionDenied(
                        "Bạn không có quyền ghi dữ liệu lên hồ sơ này."
                    )
                profile = PersonProfile.objects.get(pk=profile_id)

            serializer.save(profile=profile)
            return Response(
                {
                    "status": "success",
                    "message": "Batch synced successfully",
                    "received_count": len(serializer.validated_data.get('measurements', [])),
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)