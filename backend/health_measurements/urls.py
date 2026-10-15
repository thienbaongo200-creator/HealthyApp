from django.urls import path

from medical_records.views import (
    HealthMeasurementBatchCreateView,
    HealthMeasurementViewSet,
)


measurement_list = HealthMeasurementViewSet.as_view(
    {"get": "list", "post": "create"}
)
measurement_detail = HealthMeasurementViewSet.as_view(
    {
        "get": "retrieve",
        "put": "update",
        "patch": "partial_update",
        "delete": "destroy",
    }
)

urlpatterns = [
    path("batch/", HealthMeasurementBatchCreateView.as_view(), name="measurement-batch"),
    path("", measurement_list, name="measurement-list"),
    path("<uuid:pk>/", measurement_detail, name="measurement-detail"),
]
