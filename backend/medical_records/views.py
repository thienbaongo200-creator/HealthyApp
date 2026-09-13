from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import HealthMeasurement
from .serializers import HealthMeasurementSerializer, HealthMeasurementBatchSerializer

class HealthMeasurementViewSet(viewsets.ModelViewSet):
    serializer_class = HealthMeasurementSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return HealthMeasurement.objects.filter(profile__user=self.request.user)

class HealthMeasurementBatchCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = HealthMeasurementBatchSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response({"status": "success", "message": "Batch synced successfully"}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)