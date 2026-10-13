from accounts.models import Account
from django.test import TestCase
from profiles.models import PersonProfile

from .models import AIInsight, Conversation, Message


class AiServiceModelTests(TestCase):
    def setUp(self):
        self.account = Account.objects.create_user(
            email="ai-owner@example.com",
            password="safe-password",
        )
        self.profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="AI Service Owner",
        )

    def test_conversation_messages_and_insights_follow_profile_cascade(self):
        conversation = Conversation.objects.create(
            account=self.account,
            profile=self.profile,
            title="Health chat",
        )
        message = Message.objects.create(
            conversation=conversation,
            role="USER",
            content="How is my health?",
        )
        insight = AIInsight.objects.create(
            profile=self.profile,
            category="HEALTH",
            title="Summary",
            content="A summary.",
        )

        self.profile.delete()

        self.assertFalse(Conversation.objects.filter(pk=conversation.pk).exists())
        self.assertFalse(Message.objects.filter(pk=message.pk).exists())
        self.assertFalse(AIInsight.objects.filter(pk=insight.pk).exists())
