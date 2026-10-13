from django.contrib import admin

from .models import PersonProfile


@admin.register(PersonProfile)
class PersonProfileAdmin(admin.ModelAdmin):
    list_display = (
        "full_name",
        "profile_type",
        "account",
        "gender",
        "date_of_birth",
        "is_archived",
    )
    list_filter = ("profile_type", "gender", "is_archived")
    search_fields = ("full_name", "account__email")
    list_select_related = ("account",)
    readonly_fields = ("id", "created_at", "updated_at")
