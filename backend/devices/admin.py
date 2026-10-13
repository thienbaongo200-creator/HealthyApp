from django.contrib import admin

from .models import Device


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = (
        "device_name",
        "device_identifier",
        "profile",
        "status",
        "paired_at",
        "last_synced_at",
    )
    list_filter = ("status", "paired_at")
    search_fields = (
        "device_name",
        "device_identifier",
        "profile__full_name",
        "profile__account__email",
    )
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "paired_at", "created_at", "updated_at")
