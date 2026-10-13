from django.contrib import admin

from .models import Household, HouseholdMember, ProfileShare


@admin.register(Household)
class HouseholdAdmin(admin.ModelAdmin):
    list_display = ("name", "created_by", "created_at")
    search_fields = ("name", "created_by__email")
    list_select_related = ("created_by",)
    readonly_fields = ("id", "created_at")


@admin.register(HouseholdMember)
class HouseholdMemberAdmin(admin.ModelAdmin):
    list_display = ("household", "profile", "account", "role", "status", "created_at")
    list_filter = ("role", "status")
    search_fields = (
        "household__name",
        "profile__full_name",
        "profile__account__email",
        "account__email",
    )
    list_select_related = ("household", "profile", "account")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(ProfileShare)
class ProfileShareAdmin(admin.ModelAdmin):
    list_display = ("profile", "member", "share_level", "created_at")
    list_filter = ("share_level", "member__role", "member__status")
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "member__profile__full_name",
        "member__account__email",
        "member__household__name",
    )
    list_select_related = ("profile", "member", "member__household", "member__account")
    readonly_fields = ("id", "created_at", "updated_at")
