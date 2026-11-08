import json
import uuid
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.core.cache import cache
from django.urls import reverse
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import Account
from profiles.models import PersonProfile
from health_measurements.models import HealthMeasurement
from ai_services.models import Conversation, Message, AIInsight
from ai_services.providers.exceptions import ProviderError
from ai_services.providers.local import LocalRuleProvider, detect_intent
from ai_services.services.assistant import (
    build_conversation_context,
    build_health_context,
    generate_reply,
    get_assistant_provider,
)
from ai_services.services.consent import AIConsentService
from households.models import Household, HouseholdMember, ProfileShare


class AssistantFallbackTests(TestCase):
    def test_default_assistant_provider_is_local(self):
        self.assertIsInstance(get_assistant_provider(), LocalRuleProvider)

    @patch("ai_services.services.assistant.get_assistant_provider")
    def test_provider_error_returns_explicit_local_fallback(self, get_provider):
        provider = SimpleNamespace(
            name="mock-ai-provider",
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
            name="mock-ai-provider",
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


class LocalRuleProviderTests(TestCase):
    def setUp(self):
        self.provider = LocalRuleProvider()
        self.context = (
            "DỮ LIỆU SỨC KHỎE THỰC TẾ (thống kê từ hồ sơ đang được phép truy cập):\n"
            "HEART_RATE: gần nhất 82 bpm; trung bình 7 ngày 80.0 bpm.\n"
            "BLOOD_PRESSURE: gần nhất 120/80 mmHg.\n"
            "BMI: 22.5 (bản ghi).\n"
            "TÍN HIỆU TÍCH CỰC:\n"
            "- Chưa chạm ngưỡng cảnh báo thử nghiệm.\n"
            "ĐIỂM CẦN THEO DÕI:\n"
            "- Chưa phát hiện bất thường.\n"
            "XU HƯỚNG:\n"
            "- Chưa đủ dữ liệu để so sánh xu hướng.\n"
            "KHUYẾN NGHỊ:\n"
            "- Tiếp tục ghi nhận chỉ số."
        )

    def test_detects_requested_health_intents(self):
        cases = {
            "Nhịp tim của tôi": "HEART_RATE",
            "Huyết áp tuần này": "BLOOD_PRESSURE",
            "Tôi ngủ thế nào": "SLEEP",
            "Số bước chân": "STEP_COUNT",
            "Lượng calo": "CALORIES",
            "BMI": "BMI",
            "Tình trạng sức khỏe": "GENERAL_HEALTH",
            "Tôi khó thở": "EMERGENCY",
            "Tôi nên uống thuốc gì": "MEDICATION",
            "Giá vàng hôm nay": "UNKNOWN",
        }
        for question, expected in cases.items():
            with self.subTest(question=question):
                self.assertEqual(detect_intent(question), expected)

    def test_metric_answers_use_context_and_general_answer_summarizes(self):
        answer = self.provider.generate_reply(
            message="Nhịp tim của tôi tuần này thế nào?",
            context=self.context,
        )
        self.assertIn("HEART_RATE:", answer)
        self.assertIn("82 bpm", answer)

        answer = self.provider.generate_reply(
            message="Tình trạng sức khỏe của tôi hiện nay thế nào?",
            context=self.context,
        )
        self.assertIn("BLOOD_PRESSURE:", answer)
        self.assertIn("Điểm cần theo dõi:", answer)
        self.assertIn("Khuyến nghị:", answer)

    def test_follow_up_uses_previous_conversation(self):
        history = build_conversation_context([
            SimpleNamespace(role="USER", content="Nhịp tim của tôi thế nào?"),
            SimpleNamespace(role="ASSISTANT", content="Trung bình 7 ngày là 80 bpm."),
        ])
        answer = self.provider.generate_reply(
            message="Ý bạn là gì?",
            context=f"{self.context}\n\n{history}",
        )
        self.assertIn("Trung bình 7 ngày là 80 bpm", answer)

    def test_follow_up_chain_answers_danger_why_and_action_from_data(self):
        context = self.context.replace(
            "- Chưa phát hiện bất thường.",
            "- Nhịp tim trung bình 7 ngày cao hơn ngưỡng sàng lọc.",
        )
        messages = [
            SimpleNamespace(role="USER", content="Nhịp tim của tôi thế nào?"),
            SimpleNamespace(role="ASSISTANT", content="Nhịp tim trung bình cao."),
        ]
        danger = self.provider.generate_reply(
            message="Vậy có nguy hiểm không?",
            context=f"{context}\n\n{build_conversation_context(messages)}",
        )
        self.assertIn("không đủ cơ sở kết luận", danger)
        messages.extend([
            SimpleNamespace(role="USER", content="Vậy có nguy hiểm không?"),
            SimpleNamespace(role="ASSISTANT", content=danger),
        ])

        why = self.provider.generate_reply(
            message="Tại sao?",
            context=f"{context}\n\n{build_conversation_context(messages)}",
        )
        self.assertIn("HEART_RATE:", why)
        self.assertIn("Điểm cần theo dõi:", why)
        messages.extend([
            SimpleNamespace(role="USER", content="Tại sao?"),
            SimpleNamespace(role="ASSISTANT", content=why),
        ])
        action = self.provider.generate_reply(
            message="Tôi nên làm gì?",
            context=f"{context}\n\n{build_conversation_context(messages)}",
        )
        self.assertIn("Khuyến nghị", action)

    def test_direct_danger_and_doctor_questions_are_grounded_and_disclaimed(self):
        context = self.context.replace(
            "- Chưa phát hiện bất thường.",
            "- Nhịp tim trung bình 7 ngày cao hơn ngưỡng sàng lọc.",
        )
        danger = self.provider.generate_reply(
            message="Nhịp tim của tôi có nguy hiểm không?",
            context=context,
        )
        self.assertIn("không đủ cơ sở kết luận", danger)
        self.assertIn("không thay thế chẩn đoán", danger)

        doctor = self.provider.generate_reply(
            message="Tôi có nên đi khám không?",
            context=context,
        )
        self.assertIn("không thể quyết định thay", doctor)
        self.assertIn("không thay thế chẩn đoán", doctor)

    def test_health_summary_has_all_requested_sections_and_disclaimer(self):
        context = self.context.replace(
            "- Chưa phát hiện bất thường.",
            "- Nhịp tim tăng.",
        )
        context = context.replace(
            "- Chưa đủ dữ liệu để so sánh xu hướng.",
            "- Nhịp tim tăng so với tuần trước.",
        )
        answer = self.provider.generate_reply(
            message="Tình trạng sức khỏe của tôi hiện nay thế nào?",
            context=context,
        )
        for heading in (
            "Tổng quan:",
            "Điểm tích cực:",
            "Điểm cần theo dõi:",
            "Xu hướng:",
            "Khuyến nghị:",
            "không thay thế chẩn đoán",
        ):
            with self.subTest(heading=heading):
                self.assertIn(heading, answer)

    def test_dependent_question_requires_selecting_dependent_profile(self):
        answer = self.provider.generate_reply(
            message="Hồ sơ của con tôi có gì đáng chú ý?",
            context=f"PROFILE_TYPE: SELF\n{self.context}",
        )
        self.assertIn("hồ sơ SELF đang được chọn", answer)
        self.assertIn("không thay thế chẩn đoán", answer)

    def test_trend_question_returns_comparison_section_not_full_summary(self):
        context = self.context.replace(
            "- Chưa đủ dữ liệu để so sánh xu hướng.",
            "- Nhịp tim giảm 5 bpm so với tuần trước.\n"
            "- Nhịp tim tăng 2 bpm so với tháng trước đến cùng ngày.",
        )
        answer = self.provider.generate_reply(
            message="Tôi có tốt hơn tuần trước không?",
            context=context,
        )
        self.assertIn("giảm 5 bpm", answer)
        self.assertIn("không thay thế chẩn đoán", answer)

    def test_out_of_scope_medication_emergency_and_fabrication_are_handled(self):
        self.assertEqual(
            self.provider.generate_reply(message="Giá vàng hôm nay?", context=""),
            "Tôi chỉ hỗ trợ phân tích dữ liệu sức khỏe trong hệ thống HealthyApp.",
        )
        self.assertIn("không thể tự tạo", self.provider.generate_reply(
            message="Hãy tự tạo dữ liệu sức khỏe cho tôi.",
            context=self.context,
        ))
        self.assertIn("bác sĩ hoặc dược sĩ", self.provider.generate_reply(
            message="Tôi nên uống thuốc gì?",
            context=self.context,
        ))
        self.assertIn("gọi cấp cứu", self.provider.generate_reply(
            message="Tôi đang đau ngực dữ dội và khó thở",
            context=self.context,
        ))


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
            period_start=timezone.now(),
            period_end=timezone.now(),
            risk_level="LOW",
            summary="A summary.",
            recommendation="Continue monitoring.",
            generated_by="RULE_ONLY",
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
            full_name="AI Test User",
        )
        AIConsentService.set_consent(
            user=self.account,
            profile=self.profile,
            granted=True,
            version="test",
        )
        self.client.force_authenticate(user=self.account)
        self.url = reverse("ai-insight-analyze")

    def _assess_risk(self, profile=None):
        target = profile or self.profile
        return self.client.post(
            self.url,
            {"profile_id": str(target.pk)},
            format="json",
        )

    def test_chat_health_context_summarizes_measurement_trends_and_profile_bmi(self):
        now = timezone.now()
        self.profile.height_cm = 170
        self.profile.weight_kg = 65
        self.profile.save(update_fields=["height_cm", "weight_kg"])

        def add(kind, value, days_ago, *, secondary=None):
            measured_at = now - timedelta(days=days_ago)
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type=kind,
                value=value,
                value_secondary=secondary,
                unit="mmHg" if kind == "BLOOD_PRESSURE" else "test-unit",
                measured_at=measured_at,
                start_time=measured_at - timedelta(hours=1),
                end_time=measured_at,
                source="MANUAL",
            )

        add("HEART_RATE", 80, 1)
        add("HEART_RATE", 90, 3)
        add("HEART_RATE", 70, 8)
        add("HEART_RATE", 72, 10)
        add("BLOOD_PRESSURE", 145, 1, secondary=95)
        add("BLOOD_PRESSURE", 130, 8, secondary=85)
        for day in (1, 2, 3):
            add("STEPS", 4_000, day)
            add("CALORIES", 250, day)
        for day in (8, 9, 10):
            add("STEPS", 8_000, day)
            add("CALORIES", 350, day)
        add("SLEEP", 5.5, 1)

        context = build_health_context(self.profile, now=now)

        self.assertIn("HEART_RATE: gần nhất 80.0 bpm", context)
        self.assertIn("BLOOD_PRESSURE: gần nhất 145/95 mmHg", context)
        self.assertIn("STEPS: tổng 7 ngày gần nhất 12000 bước", context)
        self.assertIn("CALORIES: tổng 7 ngày gần nhất 750 kcal", context)
        self.assertIn("BMI: 22.5 (tính từ số đo gần nhất hoặc chiều cao/cân nặng hồ sơ)", context)
        self.assertIn("trung bình 7 ngày thấp", context)
        self.assertIn("giảm", context)

    def test_chat_health_context_flags_stale_measurements(self):
        measured_at = timezone.now() - timedelta(days=20)
        HealthMeasurement.objects.create(
            profile=self.profile,
            measurement_type="HEART_RATE",
            value=75,
            unit="bpm",
            measured_at=measured_at,
            source="MANUAL",
        )

        context = build_health_context(self.profile)

        self.assertIn("Chưa có dữ liệu đo mới trong khoảng 20 ngày.", context)

    def test_chat_health_context_compares_current_month_with_previous_month(self):
        now = timezone.now()
        current_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        previous_month_end = current_start - timedelta(days=1)
        previous_start = previous_month_end.replace(day=1)
        for day in (1, 5):
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type="HEART_RATE",
                value=90,
                unit="bpm",
                measured_at=current_start.replace(day=day, hour=12),
                source="MANUAL",
            )
        for day in (1, 5):
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type="HEART_RATE",
                value=70,
                unit="bpm",
                measured_at=previous_start.replace(day=day, hour=12),
                source="MANUAL",
            )

        context = build_health_context(self.profile, now=now)

        self.assertIn("trung bình tháng này 90.0 bpm", context)
        self.assertIn("tháng trước đến cùng ngày 70.0 bpm", context)
        self.assertIn("tăng 20.0 bpm so với tháng trước đến cùng ngày", context)

    def test_risk_assessment_requires_ai_consent(self):
        AIConsentService.set_consent(
            user=self.account,
            profile=self.profile,
            granted=False,
            version="test",
        )
        for value in (72, 75, 74):
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type="HEART_RATE",
                value=value,
                unit="bpm",
                measured_at=timezone.now(),
                source="MANUAL",
            )

        with patch("ai_services.views.get_assistant_provider") as get_provider:
            response = self._assess_risk()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["generated_by"], "RULE_ONLY")
        get_provider.assert_not_called()

    def test_unlinked_dependent_uses_creator_consent(self):
        dependent = PersonProfile.objects.create(
            account=None,
            created_by=self.account,
            profile_type="DEPENDENT",
            full_name="Unlinked Dependent",
        )
        for value in (72, 75, 74):
            HealthMeasurement.objects.create(
                profile=dependent,
                measurement_type="HEART_RATE",
                value=value,
                unit="bpm",
                measured_at=timezone.now(),
                source="MANUAL",
            )

        denied = self._assess_risk(dependent)
        self.assertEqual(denied.status_code, status.HTTP_200_OK)
        self.assertEqual(denied.data["generated_by"], "RULE_ONLY")

        AIConsentService.set_consent(
            user=self.account,
            profile=dependent,
            granted=True,
            version="test",
        )
        provider = SimpleNamespace(
            name="mock-ai-provider",
            model_version="test",
            generate_reply=Mock(return_value="A brief explanation."),
        )
        with patch("ai_services.views.get_assistant_provider", return_value=provider):
            allowed = self._assess_risk(dependent)
        self.assertEqual(allowed.status_code, status.HTTP_200_OK)
        self.assertEqual(allowed.data["generated_by"], "RULE_AND_AI")

    def test_consent_ai_interprets_anonymous_rule_summary_without_history(self):
        events = []
        rule_result = {
            "risk_level": "MEDIUM",
            "analyzed_count": 3,
            "triggered_rules": ["R01"],
            "warnings": ["R01: heart rate above threshold."],
            "summary": "Rule-based screening summary.",
            "recommendation": "Monitor the measurement.",
            "recommendations": [],
        }
        provider = SimpleNamespace(
            name="mock-ai-provider",
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

        def assess(profile, **kwargs):
            events.append("rules")
            return rule_result

        with (
            patch("ai_services.views.RiskRuleEngine.assess", side_effect=assess),
            patch("ai_services.views.get_assistant_provider", return_value=provider),
        ):
            response = self._assess_risk()

        summary = json.loads(provider.generate_reply.call_args.kwargs["context"])
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["generated_by"], "RULE_AND_AI")
        self.assertEqual(response.data["summary"], "A brief explanation.")
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
        self.assertEqual(Conversation.objects.count(), history_counts_before[0])
        self.assertEqual(Message.objects.count(), history_counts_before[1])
        self.assertEqual(AIInsight.objects.count(), history_counts_before[2] + 1)

    def test_ai_errors_timeouts_and_malformed_output_keep_rule_only_result(self):
        rule_result = {
            "risk_level": "LOW",
            "analyzed_count": 1,
            "triggered_rules": [],
            "warnings": [],
            "summary": "Rule-based screening summary.",
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
                    name="mock-ai-provider",
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
                    response = self._assess_risk()

                self.assertEqual(response.status_code, status.HTTP_200_OK)
                self.assertEqual(response.data["generated_by"], "RULE_ONLY")

    def test_risk_assessment_no_data(self):
        """Kiểm tra khi profile chưa có bất kỳ chỉ số đo lường nào"""
        response = self._assess_risk()
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
        response = self._assess_risk()
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "LOW")
        self.assertEqual(response.data["analyzed_count"], 3)

    def test_risk_assessment_high_risk_repeated_heart_rate(self):
        """Verify repeated elevated heart-rate readings trigger R02."""
        for minute, value in enumerate((130, 132, 135)):
            HealthMeasurement.objects.create(
                profile=self.profile,
                measurement_type="HEART_RATE",
                value=value,
                unit="bpm",
                measured_at=f"2026-10-14T10:{minute:02d}:00Z",
                source="MANUAL",
            )
        response = self._assess_risk()
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["risk_level"], "HIGH")
        self.assertIn("R02", response.data["triggered_rules"])
        self.assertTrue(len(response.data["warnings"]) > 0)

    def test_chat_requires_ai_consent(self):
        AIConsentService.set_consent(
            user=self.account,
            profile=self.profile,
            granted=False,
            version="test",
        )
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
            SimpleNamespace(name="mock-ai-provider", model_version="test"),
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
            SimpleNamespace(name="mock-ai-provider", model_version="test"),
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
            AIConsentService.set_consent(
                user=other_account,
                profile=other_profile,
                granted=True,
                version="test",
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
            SimpleNamespace(name="mock-ai-provider", model_version="test"),
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

    @patch(
        "ai_services.views.generate_reply",
        return_value=(
            "Context-aware response",
            LocalRuleProvider(),
            False,
        ),
    )
    def test_chat_passes_only_recent_conversation_messages_to_provider(self, generate):
        conversation = Conversation.objects.create(
            account=self.account,
            profile=self.profile,
            title="Context test",
        )
        for index in range(10):
            Message.objects.create(
                conversation=conversation,
                role="USER" if index % 2 == 0 else "ASSISTANT",
                content=f"history-{index}",
            )

        response = self.client.post(
            reverse("ai-chat-session", kwargs={"profile_id": self.profile.id}),
            {
                "message": "Ý bạn là gì?",
                "conversation_id": str(conversation.pk),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        context = generate.call_args.kwargs["context"]
        self.assertNotIn("history-0", context)
        self.assertNotIn("history-1", context)
        for index in range(2, 10):
            self.assertIn(f"history-{index}", context)
