from django.contrib import admin

from .models import (
    Allergy,
    LabResult,
    MedicalDocument,
    MedicalHistory,
    Medication,
    Visit,
)


@admin.register(MedicalHistory)
class MedicalHistoryAdmin(admin.ModelAdmin):
    list_display = ("profile", "condition", "diagnosed_at", "created_at")
    search_fields = ("profile__full_name", "profile__account__email", "condition")
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Allergy)
class AllergyAdmin(admin.ModelAdmin):
    list_display = ("profile", "allergen", "severity", "is_active", "updated_at")
    list_filter = ("severity", "is_active")
    search_fields = ("profile__full_name", "profile__account__email", "allergen")
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Visit)
class VisitAdmin(admin.ModelAdmin):
    list_display = ("profile", "provider_name", "facility_name", "visited_at")
    list_filter = ("visited_at",)
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "provider_name",
        "facility_name",
    )
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Medication)
class MedicationAdmin(admin.ModelAdmin):
    list_display = ("profile", "name", "dosage", "frequency", "status", "visit")
    list_filter = ("status", "start_date", "end_date")
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "name",
        "visit__provider_name",
    )
    list_select_related = ("profile", "profile__account", "visit")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(LabResult)
class LabResultAdmin(admin.ModelAdmin):
    list_display = ("profile", "test_name", "result", "unit", "tested_at", "visit")
    list_filter = ("tested_at",)
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "test_name",
        "result",
        "visit__provider_name",
    )
    list_select_related = ("profile", "profile__account", "visit")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(MedicalDocument)
class MedicalDocumentAdmin(admin.ModelAdmin):
    list_display = ("profile", "title", "document_type", "visit", "uploaded_at")
    list_filter = ("document_type", "uploaded_at")
    search_fields = (
        "profile__full_name",
        "profile__account__email",
        "title",
        "visit__provider_name",
    )
    list_select_related = ("profile", "profile__account", "visit")
    readonly_fields = ("id", "uploaded_at")
