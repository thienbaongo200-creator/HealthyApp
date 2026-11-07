from django.contrib import admin

from .models import AIConsent, AIInsight, Conversation, Message


@admin.register(AIConsent)
class AIConsentAdmin(admin.ModelAdmin):
    list_display = ("profile", "status", "consent_version", "granted_by_account", "granted_at", "revoked_at")
    list_filter = ("status", "consent_version")
    search_fields = ("profile__full_name", "granted_by_account__email")
    readonly_fields = ("id",)


@admin.register(AIInsight)
class AIInsightAdmin(admin.ModelAdmin):
    list_display = ("profile", "risk_level", "generated_by", "period_start", "period_end", "created_at")
    list_filter = ("risk_level", "generated_by", "created_at")
    search_fields = (
        "summary",
        "recommendation",
        "profile__full_name",
        "profile__account__email",
    )
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "created_at")


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ("title", "account", "profile", "created_at", "updated_at")
    list_filter = ("created_at", "updated_at")
    search_fields = (
        "title",
        "account__email",
        "profile__full_name",
        "profile__account__email",
    )
    list_select_related = ("account", "profile", "profile__account")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ("conversation", "role", "created_at")
    list_filter = ("role", "created_at")
    search_fields = (
        "content",
        "conversation__title",
        "conversation__account__email",
        "conversation__profile__full_name",
    )
    list_select_related = ("conversation", "conversation__account", "conversation__profile")
    readonly_fields = ("id", "created_at")
