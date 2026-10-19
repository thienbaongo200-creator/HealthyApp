import mimetypes
from uuid import UUID

from django.db import IntegrityError, OperationalError, transaction
from django.db.models import Q
from django.http import FileResponse, HttpResponseRedirect
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from core.permissions import IsProfileOwnerOrShared, PermissionService
from health_measurements.models import HealthMeasurement
from health_measurements.serializers import (
    HealthMeasurementBatchSerializer,
    HealthMeasurementFieldsSerializer,
    HealthMeasurementSerializer,
)
from profiles.models import PersonProfile
from households.models import HouseholdMember, ProfileShare
from .serializers import (
    MedicalDocumentSerializer,
)
from .models import MedicalDocument
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
        user_profiles = PersonProfile.objects.filter(
            Q(account=user) | Q(created_by=user),
            is_archived=False,
        )
        
        # 1. Profile của chính user
        owned_profile_ids = list(user_profiles.values_list('id', flat=True))
        
        # 2. Profile được chia sẻ qua ProfileShare (thành viên ACTIVE và có cấp độ quyền xem)
        shared_profile_ids = list(ProfileShare.objects.filter(
            member__profile__in=user_profiles,
            member__status='ACTIVE',
            share_level__in=['VIEW_ONLY', 'VIEW_AND_LOG']
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

        requested_profile_id = self.request.query_params.get('profile_id')
        if requested_profile_id:
            try:
                requested_profile_id = UUID(requested_profile_id)
            except ValueError as error:
                raise ValidationError(
                    {"profile_id": "Must be a valid UUID."}
                ) from error

        blocked_caregiver_profile_ids = set()
        candidate_profiles = PersonProfile.objects.filter(
            pk__in=allowed_profile_ids,
        ).select_related('account', 'created_by')
        for profile in candidate_profiles:
            if (
                PermissionService.is_caregiver_for_profile(user, profile)
                and not PermissionService.has_profile_ai_consent(profile)
            ):
                blocked_caregiver_profile_ids.add(profile.pk)

        if (
            requested_profile_id in blocked_caregiver_profile_ids
            and PermissionService.has_profile_access(
                user,
                requested_profile_id,
                required_permission="view",
            )
        ):
            raise PermissionDenied(
                "Owner AI consent is required for caregivers to view measurements."
            )

        allowed_profile_ids.difference_update(blocked_caregiver_profile_ids)
        queryset = HealthMeasurement.objects.filter(
            profile_id__in=allowed_profile_ids
        )
        if requested_profile_id:
            queryset = queryset.filter(profile_id=requested_profile_id)
        return queryset.order_by('-measured_at')

    def perform_create(self, serializer):
        profile_id = serializer.validated_data.get("profile_id")
        if profile_id is None:
            profile, _ = PersonProfile.objects.get_or_create(
                account=self.request.user,
                profile_type="SELF",
                defaults={
                    "full_name": self.request.user.email.partition("@")[0],
                    "created_by": self.request.user,
                },
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
        serializer.is_valid(raise_exception=True)
        profile_id = serializer.validated_data.get("profile_id")
        if profile_id is None:
            profile, _ = PersonProfile.objects.get_or_create(
                account=request.user,
                profile_type="SELF",
                defaults={
                    "full_name": request.user.email.partition("@")[0],
                    "created_by": request.user,
                },
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

        results = []
        for index, item in enumerate(serializer.validated_data["measurements"]):
            result = {
                "index": index,
                "status": "BỊ_TỪ_CHỐI",
            }
            if not isinstance(item, dict):
                result["errors"] = {"non_field_errors": ["Each item must be a JSON object."]}
                results.append(result)
                continue

            item_serializer = HealthMeasurementFieldsSerializer(data=item)
            if not item_serializer.is_valid():
                result["idempotency_key"] = item.get("idempotency_key")
                result["errors"] = item_serializer.errors
                results.append(result)
                continue

            validated_item = item_serializer.validated_data
            idempotency_key = validated_item.get("idempotency_key")
            result["idempotency_key"] = idempotency_key
            if not idempotency_key:
                result["errors"] = {
                    "idempotency_key": ["This field is required for batch sync."]
                }
                results.append(result)
                continue

            existing = HealthMeasurement.objects.filter(
                profile=profile,
                idempotency_key=idempotency_key,
            ).first()
            if existing:
                result.update(
                    status="TRÙNG_LẶP",
                    measurement_id=str(existing.pk),
                )
                results.append(result)
                continue

            try:
                with transaction.atomic():
                    measurement = HealthMeasurement.objects.create(
                        profile=profile,
                        **validated_item,
                    )
            except IntegrityError:
                # Handles a concurrent retry that wins the unique constraint race.
                existing = HealthMeasurement.objects.filter(
                    profile=profile,
                    idempotency_key=idempotency_key,
                ).first()
                if existing:
                    result.update(
                        status="TRÙNG_LẶP",
                        measurement_id=str(existing.pk),
                    )
                else:
                    result["errors"] = {"detail": ["Measurement violates a database constraint."]}
                results.append(result)
                continue
            except OperationalError:
                result.update(
                    status="CẦN_THỬ_LẠI",
                    errors={"detail": ["Temporary database error; retry this item."]},
                )
                results.append(result)
                continue

            result.update(
                status="ĐÃ_TẠO",
                measurement_id=str(measurement.pk),
            )
            results.append(result)

        created_count = sum(item["status"] == "ĐÃ_TẠO" for item in results)
        duplicate_count = sum(item["status"] == "TRÙNG_LẶP" for item in results)
        rejected_count = sum(item["status"] == "BỊ_TỪ_CHỐI" for item in results)
        retry_count = sum(item["status"] == "CẦN_THỬ_LẠI" for item in results)
        return Response(
            {
                "status": "success" if rejected_count == 0 and retry_count == 0 else "partial",
                "message": "Batch processed.",
                "received_count": len(results),
                "created_count": created_count,
                "duplicate_count": duplicate_count,
                "rejected_count": rejected_count,
                "retry_count": retry_count,
                "results": results,
            },
            status=(
                status.HTTP_201_CREATED
                if rejected_count == 0 and retry_count == 0
                else status.HTTP_200_OK
            ),
        )


class MedicalDocumentViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = MedicalDocumentSerializer
    permission_classes = [IsAuthenticated]
    queryset = MedicalDocument.objects.select_related("profile", "visit")

    def get_queryset(self):
        queryset = super().get_queryset()
        if not self.request.user.is_authenticated:
            return queryset.none()
        if self.request.method == "DELETE":
            return queryset

        accessible_profile_ids = [
            profile_id
            for profile_id in queryset.values_list("profile_id", flat=True).distinct()
            if PermissionService.has_profile_access(
                self.request.user,
                profile_id,
                required_permission="view",
            )
        ]
        queryset = queryset.filter(profile_id__in=accessible_profile_ids)
        profile_id = self.request.query_params.get("profile_id")
        if profile_id:
            try:
                profile_id = UUID(profile_id)
            except ValueError as error:
                raise ValidationError(
                    {"profile_id": "Must be a valid UUID."}
                ) from error
            queryset = queryset.filter(profile_id=profile_id)
        return queryset.order_by("-uploaded_at")

    def perform_create(self, serializer):
        profile_id = serializer.validated_data["profile_id"]
        if not PermissionService.has_profile_access(
            self.request.user,
            profile_id,
            required_permission="edit",
        ):
            raise PermissionDenied(
                "You do not have permission to add documents to this profile."
            )

        profile = PersonProfile.objects.get(pk=profile_id)
        serializer.save(profile=profile)

    def perform_destroy(self, instance):
        if not PermissionService.has_profile_access(
            self.request.user,
            instance.profile_id,
            required_permission="edit",
        ):
            raise PermissionDenied(
                "You do not have permission to delete documents from this profile."
            )

        if instance.file:
            instance.file.delete(save=False)
        instance.delete()

    @action(detail=True, methods=["get"], url_path="download")
    def download(self, request, *args, **kwargs):
        document = self.get_object()
        if not PermissionService.has_profile_access(
            request.user,
            document.profile_id,
            required_permission="view",
        ):
            raise PermissionDenied(
                "You do not have permission to download documents from this profile."
            )

        response_headers = {
            "Cache-Control": "private, no-store",
            "X-Content-Type-Options": "nosniff",
        }
        if document.file:
            content_type = mimetypes.guess_type(document.file.name)[0]
            response = FileResponse(
                document.file.open("rb"),
                as_attachment=True,
                filename=document.file.name.rsplit("/", 1)[-1],
                content_type=content_type or "application/octet-stream",
            )
        elif document.file_url:
            response = HttpResponseRedirect(document.file_url)
        else:
            return Response(
                {"detail": "This document has no downloadable file."},
                status=status.HTTP_404_NOT_FOUND,
            )

        for header, value in response_headers.items():
            response[header] = value
        return response
