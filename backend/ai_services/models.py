import uuid

from django.conf import settings
from django.db import models


class AIConsent(models.Model):
    STATUS_CHOICES = (("GRANTED", "Granted"), ("REVOKED", "Revoked"))

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.OneToOneField(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="ai_consent_record",
    )
    granted_by_account = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="granted_ai_consents",
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    consent_version = models.CharField(max_length=50)
    granted_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.profile_id}: {self.status}"


class AIInsight(models.Model):
    RISK_LEVEL_CHOICES = (
        ("LOW", "Low"),
        ("MEDIUM", "Medium"),
        ("HIGH", "High"),
    )
    GENERATED_BY_CHOICES = (
        ("RULE_ONLY", "Rule engine only"),
        ("RULE_AND_AI", "Rule engine and AI provider"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="ai_insights",
    )
    period_start = models.DateTimeField()
    period_end = models.DateTimeField()
    risk_level = models.CharField(max_length=10, choices=RISK_LEVEL_CHOICES)
    triggered_rules = models.JSONField(default=list, blank=True)
    summary = models.TextField()
    recommendation = models.TextField()
    generated_by = models.CharField(max_length=20, choices=GENERATED_BY_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.risk_level} insight for {self.profile_id}"


class Conversation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    account = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="conversations",
    )
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="conversations",
    )
    title = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title or f"Conversation {self.pk}"


class Message(models.Model):
    ROLE_CHOICES = (
        ("USER", "User"),
        ("ASSISTANT", "Assistant"),
        ("SYSTEM", "System"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    content = models.TextField()
    provider = models.CharField(max_length=50, default="local")
    model_version = models.CharField(max_length=100, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.role} message in {self.conversation_id}"
