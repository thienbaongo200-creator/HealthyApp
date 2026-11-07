from django.urls import path

from .views import DeviceDetailView, DeviceListCreateView


urlpatterns = [
    path("", DeviceListCreateView.as_view(), name="device-list-create"),
    path("<uuid:device_id>/", DeviceDetailView.as_view(), name="device-detail"),
]
