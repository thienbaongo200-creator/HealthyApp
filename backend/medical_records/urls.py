from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import HealthMeasurementViewSet, HealthMeasurementBatchCreateView

router = DefaultRouter()
router.register(r'measurements', HealthMeasurementViewSet, basename='measurement')

urlpatterns = [
    path('measurements/batch/', HealthMeasurementBatchCreateView.as_view(), name='measurement-batch'),
    path('', include(router.urls)),
]