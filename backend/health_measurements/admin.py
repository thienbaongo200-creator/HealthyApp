from django.contrib import admin

from .models import HealthMeasurement


@admin.register(HealthMeasurement)
class HealthMeasurementAdmin(admin.ModelAdmin):
    list_display = (
        "profile",
        "measurement_type",
        "value",
        "value_secondary",
        "unit",
        "measured_at",
        "source",
        "device",
    )
    list_filter = ("measurement_type", "source", "measured_at")
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "device__device_identifier",
        "idempotency_key",
    )
    list_select_related = ("profile", "profile__account", "device")
    readonly_fields = ("id", "created_at", "updated_at")
