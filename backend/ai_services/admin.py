from django.contrib import admin

from .models import AIInsight, Conversation, Message


@admin.register(AIInsight)
class AIInsightAdmin(admin.ModelAdmin):
    list_display = ("title", "profile", "category", "status", "generated_at")
    list_filter = ("category", "status", "generated_at")
    search_fields = (
        "title",
        "category",
        "content",
        "profile__full_name",
        "profile__account__email",
    )
    list_select_related = ("profile", "profile__account")
    readonly_fields = ("id", "generated_at")


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
