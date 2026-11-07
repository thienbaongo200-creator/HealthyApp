from rest_framework import serializers

from .models import AIConsent, AIInsight, Conversation, Message


class AIConsentSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField(read_only=True)
    granted_by_account_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = AIConsent
        fields = (
            "profile_id",
            "consent",
            "granted_by_account_id",
            "status",
            "consent_version",
            "granted_at",
            "revoked_at",
        )

    consent = serializers.SerializerMethodField()

    def get_consent(self, obj):
        return obj.status == "GRANTED"


class AIConsentUpdateSerializer(serializers.Serializer):
    consent = serializers.BooleanField()
    consent_version = serializers.CharField(max_length=50, allow_blank=False)


class AIInsightSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = AIInsight
        fields = (
            "id",
            "profile_id",
            "period_start",
            "period_end",
            "risk_level",
            "triggered_rules",
            "summary",
            "recommendation",
            "generated_by",
            "created_at",
        )
        read_only_fields = fields


class ConversationSerializer(serializers.ModelSerializer):
    profile_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = Conversation
        fields = ("id", "profile_id", "title", "created_at", "updated_at")


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ("id", "role", "content", "created_at")
