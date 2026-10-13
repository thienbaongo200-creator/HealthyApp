from rest_framework import viewsets, status
from core.permissions import IsProfileOwnerOrShared, PermissionService # Sửa lại tên import chuẩn
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
    pagination_class = HealthMeasurementPagination # Lúc này Python đã nhận diện được class này
class HealthMeasurementViewSet(viewsets.ModelViewSet):
    serializer_class = HealthMeasurementSerializer
    permission_classes = [IsProfileOwnerOrShared]
    pagination_class = HealthMeasurementPagination

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return HealthMeasurement.objects.none()

        # Lấy tất cả profile mà user này có quyền truy cập (Chính chủ + Được share + Trong Household)
        user_profiles = PersonProfile.objects.filter(account=user, is_archived=False)
        
        # 1. Profile của chính user
        owned_profile_ids = list(user_profiles.values_list('id', flat=True))
        
        # 2. Profile được chia sẻ qua ProfileShare
        shared_profile_ids = list(ProfileShare.objects.filter(
            member__in=user_profiles, can_view=True, is_active=True
        ).values_list('profile_id', flat=True))
        
        # 3. Profile trong cùng Household (nếu cần cho phép xem)
        household_ids = HouseholdMember.objects.filter(
            profile__in=user_profiles, status='ACTIVE'
        ).values_list('household_id', flat=True)
        
        household_profile_ids = list(HouseholdMember.objects.filter(
            household_id__in=household_ids, status='ACTIVE'
        ).values_list('profile_id', flat=True))

        # Gộp tất cả các ID profile được phép xem
        allowed_profile_ids = set(owned_profile_ids + shared_profile_ids + household_profile_ids)

        return HealthMeasurement.objects.filter(
            profile_id__in=allowed_profile_ids
        ).order_by('-measured_at')

class HealthMeasurementBatchCreateView(APIView):
    permission_classes = [IsProfileOwnerOrShared]

    def post(self, request, *args, **kwargs):
        # 1. Lấy profile_id từ request data (hoặc URL params tùy theo payload của bạn)
        target_profile_id = request.data.get('profile_id') # Hoặc lấy từ serializer validation tùy thiết kế
        
        # Kiểm tra chống IDOR bắt buộc đối với APIView
        if target_profile_id:
            # Yêu cầu quyền 'edit' (VIEW_AND_LOG) vì đây là hành vi tạo/ghi dữ liệu
            if not PermissionService.has_profile_access(request.user, target_profile_id, required_permission='edit'):
                return Response(
                    {"detail": "Bạn không có quyền ghi dữ liệu lên hồ sơ này."},
                    status=status.HTTP_403_FORBIDDEN
                )

        serializer = HealthMeasurementBatchSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(
                {
                    "status": "success",
                    "message": "Batch synced successfully",
                    "received_count": len(serializer.validated_data.get('measurements', [])),
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)