import uuid
from django.urls import reverse
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import Account
from profiles.models import PersonProfile
from health_measurements.models import HealthMeasurement
from ai_services.models import Conversation, Message, AIInsight

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

class HealthRiskAssessmentApiTests(APITestCase):
    def setUp(self):
        # Tạo tài khoản và profile mẫu
        self.account = Account.objects.create_user(
            email="ai_user@example.com",
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

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

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
