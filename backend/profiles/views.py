from django.shortcuts import get_object_or_404
from rest_framework import status, viewsets
from rest_framework.views import APIView
from rest_framework.exceptions import PermissionDenied, NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import generics
from rest_framework.generics import RetrieveUpdateDestroyAPIView
from core.permissions import IsProfileOwnerOrShared, PermissionService
from .models import PersonProfile
from .serializers import PersonProfileCreateSerializer, PersonProfileSerializer
from ai_services.models import AIConsent
from ai_services.serializers import AIConsentSerializer, AIConsentUpdateSerializer
from ai_services.services.consent import AIConsentService

def accessible_profiles_for(user):
    """Backward-compatible wrapper around the central authorization queryset."""
    return PermissionService.accessible_profiles(user)


class PersonProfileViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsProfileOwnerOrShared]
    serializer_class = PersonProfileSerializer

    def get_queryset(self):
        return accessible_profiles_for(self.request.user)

    def get_serializer_class(self):
        if self.action == "create":
            return PersonProfileCreateSerializer
        return PersonProfileSerializer

    def create(self, request, *args, **kwargs):
        if not PermissionService.is_active_owner(request.user):
            raise PermissionDenied("Chỉ chủ hộ đang hoạt động mới được tạo hồ sơ phụ thuộc.")
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
        if not PermissionService.has_profile_access(
            self.request.user, serializer.instance.pk, required_permission="edit"
        ):
            raise PermissionDenied("Chỉ người quản lý hồ sơ mới được cập nhật hồ sơ này.")
        serializer.save()

    def perform_destroy(self, instance):
        if not PermissionService.has_profile_access(
            self.request.user, instance.pk, required_permission="edit"
        ) or instance.profile_type == "SELF":
            raise PermissionDenied("Chỉ người quản lý hồ sơ mới được lưu trữ hồ sơ này.")
        instance.is_archived = True
        instance.save(update_fields=["is_archived", "updated_at"])

    def destroy(self, request, *args, **kwargs):
        profile = self.get_object()
        if not PermissionService.has_profile_access(
            request.user, profile.pk, required_permission="edit"
        ):
            raise PermissionDenied("Chỉ người quản lý hồ sơ mới được lưu trữ hồ sơ này.")
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
        # This endpoint creates DEPENDENT profiles; only a current active
        # household OWNER may do so (RBAC matrix, Table 2.42).
        if not PermissionService.is_active_owner(self.request.user):
            raise PermissionDenied("Chỉ chủ hộ đang hoạt động mới được tạo hồ sơ phụ thuộc.")
        # Khi tạo mới từ phía user, mặc định đây là hồ sơ DEPENDENT (hồ sơ SELF đã được tự động tạo khi Register)
        serializer.save(
            account=self.request.user,
            created_by=self.request.user,
            profile_type="DEPENDENT",
        )

class ProfileAIConsentView(APIView):
    permission_classes = [IsAuthenticated]

    def get_profile(self, profile_id, user):
        profile = get_object_or_404(
            PersonProfile,
            pk=profile_id,
            is_archived=False,
        )
        if not AIConsentService.can_manage(user, profile):
            raise PermissionDenied("Chỉ chủ hồ sơ hoặc người giám hộ mới được quản lý sự đồng ý sử dụng AI.")
        return profile

    def get(self, request, profile_id):
        profile = self.get_profile(profile_id, request.user)
        record = AIConsent.objects.filter(profile=profile).first()
        if record is None:
            return Response({"profile_id": str(profile.pk), "consent": False})
        return Response(AIConsentSerializer(record).data)

    def put(self, request, profile_id):
        profile = self.get_profile(profile_id, request.user)
        serializer = AIConsentUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        record = AIConsentService.set_consent(
            user=request.user,
            profile=profile,
            granted=serializer.validated_data["consent"],
            version=serializer.validated_data["consent_version"],
        )
        return Response(AIConsentSerializer(record).data, status=status.HTTP_200_OK)

class ProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Endpoint quản lý chi tiết một PersonProfile (Xem, Cập nhật, Archive).
    Đã được ghi đè get_object để chuyển từ lỗi 404 sang 403 Forbidden đúng chuẩn kịch bản TC09.
    """
    queryset = PersonProfile.objects.filter(is_archived=False)
    serializer_class = PersonProfileSerializer
    permission_classes = [IsAuthenticated, IsProfileOwnerOrShared]

    def get_object(self):
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        filter_kwargs = {self.lookup_field: self.kwargs[lookup_url_kwarg]}

        # 1. Tìm xem profile có tồn tại trong hệ thống hay không (tránh 404 ẩn dữ liệu)
        try:
            obj = PersonProfile.objects.get(**filter_kwargs, is_archived=False)
        except PersonProfile.DoesNotExist:
            raise NotFound("Không tìm thấy hồ sơ này.")

        # 2. Xác định phương thức request để kiểm tra đúng quyền (view hay edit)
        req_type = 'edit' if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE'] else 'view'

        # 3. Gọi PermissionService để kiểm tra quyền truy cập chi tiết
        has_access = PermissionService.has_profile_access(
            self.request.user, obj.id, required_permission=req_type
        )

        # 4. Nếu user ngoài cố tình chọc vào -> Bắn PermissionDenied để DRF trả về chính xác 403 Forbidden
        if not has_access:
            raise PermissionDenied("Bạn không có quyền truy cập hoặc chỉnh sửa hồ sơ này.")

        self.check_object_permissions(self.request, obj)
        return obj

    def perform_update(self, serializer):
        profile = self.get_object()
        if not PermissionService.has_profile_access(
            self.request.user, profile.pk, required_permission="edit"
        ):
            raise PermissionDenied("Chỉ người quản lý hồ sơ mới được cập nhật hồ sơ này.")
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        """Thay vì xóa cứng (DELETE), ta thực hiện archive mềm (is_archived = True)"""
        profile = self.get_object()
        if not PermissionService.has_profile_access(
            request.user, profile.pk, required_permission="edit"
        ):
            raise PermissionDenied("Chỉ người quản lý hồ sơ mới được lưu trữ hồ sơ này.")
        if profile.profile_type == "SELF":
            return Response(
                {"detail": "Không thể xóa hoặc lưu trữ hồ sơ chính."},
                status=status.HTTP_403_FORBIDDEN
            )

        profile.is_archived = True
        profile.save(update_fields=["is_archived", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)
