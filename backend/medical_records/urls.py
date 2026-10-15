from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HealthMeasurementViewSet,
    HealthMeasurementBatchCreateView,
    MedicalDocumentViewSet,
)

router = DefaultRouter()
router.register(r'measurements', HealthMeasurementViewSet, basename='measurement')
router.register(r'documents', MedicalDocumentViewSet, basename='medical-document')

urlpatterns = [
    # Đặt path tĩnh lên trên để tránh bị router bắt nhầm thành <pk>
    path('measurements/batch/', HealthMeasurementBatchCreateView.as_view(), name='measurement-batch'),
    path('', include(router.urls)),
]