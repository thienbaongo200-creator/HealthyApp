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
        self.client.force_authenticate(user=self.account)
        self.url = reverse('ai-risk-assessment', kwargs={'profile_id': self.profile.id})

    def test_risk_assessment_no_data(self):
        """Kiểm tra khi profile chưa có bất kỳ chỉ số đo lường nào"""
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "UNKNOWN")
        self.assertEqual(response.data["analyzed_count"], 0)

    def test_risk_assessment_low_risk(self):
        """Kiểm tra đánh giá rủi ro ở mức thấp với các chỉ số bình thường"""
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="HEART_RATE",
            value=72,
            unit="bpm",
            measured_at="2026-10-14T10:00:00Z",
            source="MANUAL"
        )
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "LOW")
        self.assertEqual(response.data["analyzed_count"], 1)

    def test_risk_assessment_high_risk_blood_pressure(self):
        """Kiểm tra đánh giá rủi ro ở mức cao khi huyết áp vượt ngưỡng nguy hiểm"""
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="BLOOD_PRESSURE_SYSTOLIC",
            value=145,
            unit="mmHg",
            measured_at="2026-10-14T10:00:00Z",
            source="MANUAL"
        )
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="BLOOD_PRESSURE_DIASTOLIC",
            value=95,
            unit="mmHg",
            measured_at="2026-10-14T10:00:00Z",
            source="MANUAL"
        )
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "HIGH")
        self.assertTrue(len(response.data["warnings"]) > 0)