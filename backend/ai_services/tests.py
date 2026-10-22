import json
import uuid
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.core.cache import cache
from django.urls import reverse
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import Account
from profiles.models import PersonProfile
from health_measurements.models import HealthMeasurement
from ai_services.models import Conversation, Message, AIInsight
from ai_services.providers.exceptions import ProviderError
from ai_services.providers.local import LocalRuleProvider
from ai_services.services.assistant import generate_reply
from households.models import Household, HouseholdMember, ProfileShare


class AssistantFallbackTests(TestCase):
    @patch("ai_services.services.assistant.get_assistant_provider")
    def test_provider_error_returns_explicit_local_fallback(self, get_provider):
        provider = SimpleNamespace(
            name="gemini",
            model_version="test",
            generate_reply=Mock(side_effect=ProviderError("Unavailable.")),
        )
        get_provider.return_value = provider

        reply, fallback_provider, is_fallback = generate_reply(
            message="How is my heart rate?",
            context="HEART_RATE: 72 bpm",
        )

        self.assertTrue(reply)
        self.assertIsInstance(fallback_provider, LocalRuleProvider)
        self.assertTrue(is_fallback)

    @patch("ai_services.services.assistant.get_assistant_provider")
    def test_malformed_provider_output_returns_explicit_local_fallback(
        self,
        get_provider,
    ):
        provider = SimpleNamespace(
            name="gemini",
            model_version="test",
            generate_reply=Mock(return_value=None),
        )
        get_provider.return_value = provider

        reply, fallback_provider, is_fallback = generate_reply(
            message="How is my heart rate?",
            context="HEART_RATE: 72 bpm",
        )

        self.assertTrue(reply)
        self.assertIsInstance(fallback_provider, LocalRuleProvider)
        self.assertTrue(is_fallback)

    @patch("ai_services.services.assistant.get_assistant_provider")
    def test_configured_local_provider_is_not_marked_as_fallback(self, get_provider):
        get_provider.return_value = LocalRuleProvider()

        reply, provider, is_fallback = generate_reply(
            message="How is my heart rate?",
            context="HEART_RATE: 72 bpm",
        )

        self.assertTrue(reply)
        self.assertIsInstance(provider, LocalRuleProvider)
        self.assertFalse(is_fallback)

class AiServiceModelTests(TestCase):
    def setUp(self):
        self.account = Account.objects.create_user(
            email=f"ai-owner-{uuid.uuid4().hex}@example.com",
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

@override_settings(SECURE_SSL_REDIRECT=False)
class HealthRiskAssessmentApiTests(APITestCase):
    def setUp(self):
        # Tạo tài khoản và profile mẫu
        self.account = Account.objects.create_user(
            email=f"ai-user-{uuid.uuid4().hex}@example.com",
            password="test-password-123"
        )
        self.profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="AI Test User"
        )
        self.account.ai_consent = True
        self.account.save(update_fields=["ai_consent"])
        self.client.force_authenticate(user=self.account)
        self.url = reverse('ai-risk-assessment', kwargs={'profile_id': self.profile.id})

    def test_risk_assessment_requires_ai_consent(self):
        self.account.ai_consent = False
        self.account.save(update_fields=["ai_consent"])

        with patch("ai_services.views.get_assistant_provider") as get_provider:
            response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["generated_by"], "RULE_ONLY")
        self.assertIsNone(response.data["interpretation"])
        get_provider.assert_not_called()

    def test_unlinked_dependent_uses_creator_consent(self):
        dependent = PersonProfile.objects.create(
            account=None,
            created_by=self.account,
            profile_type="DEPENDENT",
            full_name="Unlinked Dependent",
        )
        url = reverse("ai-risk-assessment", kwargs={"profile_id": dependent.id})

        self.account.ai_consent = False
        self.account.save(update_fields=["ai_consent"])
        denied = self.client.get(url)
        self.assertEqual(denied.status_code, status.HTTP_200_OK)
        self.assertEqual(denied.data["generated_by"], "RULE_ONLY")

        self.account.ai_consent = True
        self.account.save(update_fields=["ai_consent"])
        allowed = self.client.get(url)
        self.assertEqual(allowed.status_code, status.HTTP_422_UNPROCESSABLE_ENTITY)
        self.assertEqual(allowed.data["risk_level"], "UNKNOWN")
        self.assertGreater(len(allowed.data["recommendations"]), 0)

    def test_consent_ai_interprets_anonymous_rule_summary_without_history(self):
        events = []
        rule_result = {
            "risk_level": "MEDIUM",
            "analyzed_count": 3,
            "warnings": ["R01: heart rate above threshold."],
            "recommendation": "Monitor the measurement.",
            "recommendations": [],
        }
        provider = SimpleNamespace(
            name="gemini",
            model_version="test",
            generate_reply=Mock(
                side_effect=lambda **kwargs: (
                    events.append("ai") or "A brief explanation."
                )
            ),
        )
        history_counts_before = (
            Conversation.objects.count(),
            Message.objects.count(),
            AIInsight.objects.count(),
        )

        def assess(profile):
            events.append("rules")
            return rule_result

        with (
            patch("ai_services.views.RiskRuleEngine.assess", side_effect=assess),
            patch("ai_services.views.get_assistant_provider", return_value=provider),
        ):
            response = self.client.get(self.url)

        summary = json.loads(provider.generate_reply.call_args.kwargs["context"])
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["generated_by"], "RULE_AND_AI")
        self.assertEqual(response.data["interpretation"], "A brief explanation.")
        self.assertEqual(events, ["rules", "ai"])
        self.assertNotIn(str(self.profile.id), summary.values())
        self.assertNotIn(self.profile.full_name, json.dumps(summary))
        self.assertEqual(
            summary,
            {
                "risk_level": "MEDIUM",
                "analyzed_count": 3,
                "warnings": ["R01: heart rate above threshold."],
                "recommendation": "Monitor the measurement.",
            },
        )
        self.assertEqual(
            (
                Conversation.objects.count(),
                Message.objects.count(),
                AIInsight.objects.count(),
            ),
            history_counts_before,
        )

    def test_ai_errors_timeouts_and_malformed_output_keep_rule_only_result(self):
        rule_result = {
            "risk_level": "LOW",
            "analyzed_count": 1,
            "warnings": [],
            "recommendation": "Continue monitoring.",
            "recommendations": [],
        }
        invalid_outputs = [
            ProviderError("Provider unavailable."),
            TimeoutError("Provider timeout."),
            "",
            {"unexpected": "shape"},
        ]

        for invalid_output in invalid_outputs:
            with self.subTest(output=type(invalid_output).__name__):
                provider = SimpleNamespace(
                    name="gemini",
                    model_version="test",
                    generate_reply=Mock(side_effect=invalid_output)
                    if isinstance(invalid_output, Exception)
                    else Mock(return_value=invalid_output),
                )
                with (
                    patch(
                        "ai_services.views.RiskRuleEngine.assess",
                        return_value=rule_result,
                    ),
                    patch(
                        "ai_services.views.get_assistant_provider",
                        return_value=provider,
                    ),
                ):
                    response = self.client.get(self.url)

                self.assertEqual(response.status_code, status.HTTP_200_OK)
                self.assertEqual(response.data["generated_by"], "RULE_ONLY")
                self.assertIsNone(response.data["interpretation"])

    def test_risk_assessment_no_data(self):
        """Kiểm tra khi profile chưa có bất kỳ chỉ số đo lường nào"""
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_422_UNPROCESSABLE_ENTITY)
        self.assertEqual(response.data["risk_level"], "UNKNOWN")
        self.assertEqual(response.data["analyzed_count"], 0)

    def test_risk_assessment_low_risk(self):
        """Kiểm tra đánh giá rủi ro ở mức thấp với các chỉ số bình thường"""
        for minute, value in enumerate((72, 74, 71)):
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type="HEART_RATE",
                value=value,
                unit="bpm",
                measured_at=f"2026-10-14T10:{minute:02d}:00Z",
                source="MANUAL",
            )
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "LOW")
        self.assertEqual(response.data["analyzed_count"], 3)

    def test_risk_assessment_high_risk_blood_pressure(self):
        """Kiểm tra đánh giá rủi ro ở mức cao khi huyết áp vượt ngưỡng nguy hiểm"""
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="BLOOD_PRESSURE",
            value=145,
            value_secondary=95,
            unit="mmHg",
            measured_at="2026-10-14T10:00:00Z",
            source="MANUAL"
        )
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "HIGH")
        self.assertTrue(len(response.data["warnings"]) > 0)

    def test_chat_requires_ai_consent(self):
        self.account.ai_consent = False
        self.account.save(update_fields=["ai_consent"])
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})

        response = self.client.post(
            url,
            {"message": "How are my health measurements?"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Provider response",
            SimpleNamespace(name="gemini", model_version="test"),
            False,
        ),
    )
    def test_shared_view_only_member_can_chat_with_profile_consent(self, generate):
        member = Account.objects.create_user(
            email=f"chat-member-{uuid.uuid4().hex}@example.com",
            password="SecurePassword123!",
        )
        member_profile = PersonProfile.objects.create(
            account=member,
            profile_type="SELF",
            full_name="Shared Chat Member",
        )
        household = Household.objects.create(
            name="Chat Permission Household",
            created_by=self.account,
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.account,
            profile=self.profile,
            role="OWNER",
            status="ACTIVE",
        )
        membership = HouseholdMember.objects.create(
            household=household,
            account=member,
            profile=member_profile,
            role="MEMBER",
            status="ACTIVE",
        )
        ProfileShare.objects.create(
            member=membership,
            profile=self.profile,
            share_level="VIEW_ONLY",
        )
        self.client.force_authenticate(user=member)
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})

        response = self.client.post(
            url,
            {"message": "How are my health measurements?"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertTrue(Conversation.objects.filter(account=member).exists())
        self.assertEqual(
            list(
                Message.objects.filter(
                    conversation__account=member,
                ).values_list("role", flat=True)
            ),
            ["USER", "ASSISTANT"],
        )
        generate.assert_called_once()

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Provider response",
            SimpleNamespace(name="gemini", model_version="test"),
            False,
        ),
    )
    def test_chat_throttle_is_limited_per_account(self, generate):
        cache.clear()
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})
        payload = {"message": "How are my health measurements?"}

        with patch(
            "rest_framework.throttling.ScopedRateThrottle.THROTTLE_RATES",
            {"login": "2/min", "ai_chat": "2/min"},
        ):
            self.client.force_authenticate(user=self.account)
            first = self.client.post(url, payload, format="json")
            second = self.client.post(url, payload, format="json")
            limited = self.client.post(url, payload, format="json")

            other_account = Account.objects.create_user(
                email=f"chat-throttle-{uuid.uuid4().hex}@example.com",
                password="SecurePassword123!",
                ai_consent=True,
            )
            other_profile = PersonProfile.objects.create(
                account=other_account,
                profile_type="SELF",
                full_name="Other Chat User",
            )
            self.client.force_authenticate(user=other_account)
            other_account_response = self.client.post(
                reverse("ai-chat-session", kwargs={"profile_id": other_profile.id}),
                payload,
                format="json",
            )

        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(limited.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertEqual(other_account_response.status_code, status.HTTP_200_OK)

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Local guidance",
            LocalRuleProvider(),
            True,
        ),
    )
    def test_chat_fallback_does_not_persist_conversation_or_messages(
        self,
        generate,
    ):
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})

        response = self.client.post(
            url,
            {"message": "How are my health measurements?"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertTrue(response.data["fallback"])
        self.assertTrue(response.data["retryable"])
        self.assertIsNone(response.data["conversation_id"])
        self.assertEqual(
            response.data["message"],
            "AI is temporarily unavailable. This local fallback was not saved; please retry.",
        )
        self.assertFalse(Conversation.objects.exists())
        self.assertFalse(Message.objects.exists())

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Local guidance",
            LocalRuleProvider(),
            True,
        ),
    )
    def test_chat_fallback_does_not_append_to_existing_conversation(
        self,
        generate,
    ):
        conversation = Conversation.objects.create(
            account=self.account,
            profile=self.profile,
            title="Existing conversation",
        )
        Message.objects.create(
            conversation=conversation,
            role="USER",
            content="Previous question",
        )
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})

        response = self.client.post(
            url,
            {
                "message": "How are my health measurements?",
                "conversation_id": str(conversation.id),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(response.data["conversation_id"], str(conversation.id))
        self.assertEqual(conversation.messages.count(), 1)
        self.assertEqual(conversation.messages.get().content, "Previous question")

    def test_conversation_history_is_scoped_to_current_account_and_profile(self):
        conversation = Conversation.objects.create(
            account=self.account,
            profile=self.profile,
            title="Recent chat",
        )
        Message.objects.create(
            conversation=conversation,
            role="USER",
            content="Question",
        )
        Message.objects.create(
            conversation=conversation,
            role="ASSISTANT",
            content="Answer",
        )
        other = Account.objects.create_user(
            email=f"private-chat-{uuid.uuid4().hex}@example.com",
            password="test-password",
            ai_consent=True,
        )
        other_profile = PersonProfile.objects.create(
            account=other,
            profile_type="SELF",
            full_name="Other Chat Profile",
        )
        Conversation.objects.create(
            account=other,
            profile=other_profile,
            title="Private chat",
        )

        conversations_response = self.client.get(
            reverse("ai-conversation-list"),
            {"profile": str(self.profile.pk)},
        )
        messages_response = self.client.get(
            reverse(
                "ai-conversation-messages",
                kwargs={"conversation_id": conversation.pk},
            )
        )
        other_messages_response = self.client.get(
            reverse(
                "ai-conversation-messages",
                kwargs={"conversation_id": Conversation.objects.get(
                    account=other,
                ).pk},
            )
        )

        self.assertEqual(conversations_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(conversations_response.data), 1)
        self.assertEqual(
            conversations_response.data[0]["id"],
            str(conversation.pk),
        )
        self.assertEqual(messages_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [item["role"] for item in messages_response.data],
            ["USER", "ASSISTANT"],
        )
        self.assertEqual(other_messages_response.status_code, status.HTTP_404_NOT_FOUND)

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Provider response",
            SimpleNamespace(name="gemini", model_version="test"),
            False,
        ),
    )
    def test_chat_persists_only_successful_provider_response(self, generate):
        url = reverse("ai-chat-session", kwargs={"profile_id": self.profile.id})

        response = self.client.post(
            url,
            {"message": "How are my health measurements?"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        conversation = Conversation.objects.get(pk=response.data["conversation_id"])
        self.assertEqual(
            list(conversation.messages.values_list("role", flat=True)),
            ["USER", "ASSISTANT"],
        )
