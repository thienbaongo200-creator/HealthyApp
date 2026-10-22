from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AllergyViewSet,
    HealthMeasurementViewSet,
    HealthMeasurementBatchCreateView,
    LabResultViewSet,
    MedicalHistoryViewSet,
    MedicalDocumentViewSet,
    MedicationViewSet,
    VisitViewSet,
)

router = DefaultRouter()
router.register(r'measurements', HealthMeasurementViewSet, basename='measurement')
router.register(r'documents', MedicalDocumentViewSet, basename='medical-document')
router.register(r'histories', MedicalHistoryViewSet, basename='medical-history')
router.register(r'allergies', AllergyViewSet, basename='allergy')
router.register(r'visits', VisitViewSet, basename='visit')
router.register(r'medications', MedicationViewSet, basename='medication')
router.register(r'lab-results', LabResultViewSet, basename='lab-result')

urlpatterns = [
    # Đặt path tĩnh lên trên để tránh bị router bắt nhầm thành <pk>
    path('measurements/batch/', HealthMeasurementBatchCreateView.as_view(), name='measurement-batch'),
    path('', include(router.urls)),
]