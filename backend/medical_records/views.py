from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from .models import HealthMeasurement
from .serializers import HealthMeasurementSerializer, HealthMeasurementBatchSerializer


class HealthMeasurementPagination(PageNumberPagination):
    page_size = 100


class HealthMeasurementViewSet(viewsets.ModelViewSet):
    serializer_class = HealthMeasurementSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = HealthMeasurementPagination

    def get_queryset(self):
        return HealthMeasurement.objects.filter(
            profile__user=self.request.user,
        ).order_by('-measured_at')

class HealthMeasurementBatchCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = HealthMeasurementBatchSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(
                {
                    "status": "success",
                    "message": "Batch synced successfully",
                    "received_count": len(serializer.validated_data['measurements']),
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)