import json
import logging

from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import serializers
from rest_framework import status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.generics import ListAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from ai_services.models import Conversation, Message
from ai_services.serializers import ConversationSerializer, MessageSerializer
from ai_services.providers.exceptions import ProviderError
from ai_services.providers.local import LocalRuleProvider
from ai_services.services.assistant import (
    build_health_context,
    generate_reply,
    get_assistant_provider,
)
from ai_services.services.risk_engine import RiskRuleEngine
from core.permissions import PermissionService
from profiles.models import PersonProfile

logger = logging.getLogger(__name__)


def authorized_profile(
    request,
    profile_id,
    *,
    required_permission="view",
    require_ai_consent=True,
):
    if not PermissionService.has_profile_access(
        request.user,
        profile_id,
        required_permission=required_permission,
    ):
        raise PermissionDenied("You do not have permission to view this profile.")
    profile = get_object_or_404(PersonProfile, id=profile_id, is_archived=False)
    if require_ai_consent and not PermissionService.has_profile_ai_consent(profile):
        raise PermissionDenied("AI consent from the profile owner is required.")
    return profile


def interpret_risk_result(result):
    try:
        provider = get_assistant_provider()
        if isinstance(provider, LocalRuleProvider):
            return None
        interpretation = provider.generate_reply(
            message=(
                "Hãy giải thích ngắn gọn kết quả sàng lọc theo ngôn ngữ dễ hiểu. "
                "Không chẩn đoán và không đưa ra kết luận vượt quá các quy tắc."
            ),
            context=json.dumps(
                {
                    "risk_level": result["risk_level"],
                    "analyzed_count": result["analyzed_count"],
                    "warnings": result["warnings"],
                    "recommendation": result["recommendation"],
                },
                ensure_ascii=False,
            ),
        )
    except (ProviderError, TimeoutError):
        logger.warning("AI risk interpretation failed; returning rule-only result.")
        return None

    if not isinstance(interpretation, str) or not interpretation.strip():
        logger.warning("AI risk interpretation was malformed; returning rule-only result.")
        return None
    return interpretation.strip()


class HealthRiskAssessmentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, profile_id):
        profile = authorized_profile(
            request,
            profile_id,
            require_ai_consent=False,
        )
        result = RiskRuleEngine().assess(profile)
        has_consent = PermissionService.has_profile_ai_consent(profile)
        response_data = {
            "profile_id": str(profile.id),
            **result,
            "generated_by": "RULE_ONLY",
            "interpretation": None,
        }

        if has_consent:
            interpretation = interpret_risk_result(result)
            if interpretation is not None:
                response_data["generated_by"] = "RULE_AND_AI"
                response_data["interpretation"] = interpretation

        code = (
            status.HTTP_200_OK
            if not has_consent or result["risk_level"] != "UNKNOWN"
            else status.HTTP_422_UNPROCESSABLE_ENTITY
        )
        return Response(response_data, status=code)


class AiChatSessionView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "ai_chat"

    def post(self, request, profile_id):
        profile = authorized_profile(request, profile_id, required_permission="view")
        message_text = request.data.get("message", "")
        if not isinstance(message_text, str) or not message_text.strip():
            return Response({"error": "Message content is required."}, status=status.HTTP_400_BAD_REQUEST)
        message_text = message_text.strip()

        conversation_id = request.data.get("conversation_id")
        conversation = None
        if conversation_id:
            conversation = get_object_or_404(
                Conversation, id=conversation_id, account=request.user, profile=profile
            )
            title = conversation.title
        else:
            title = message_text[:30] + ("..." if len(message_text) > 30 else "")

        context = build_health_context(profile)
        reply, provider, is_fallback = generate_reply(
            message=message_text,
            context=context,
        )
        if is_fallback:
            return Response(
                {
                    "conversation_id": str(conversation.id) if conversation else None,
                    "fallback": True,
                    "retryable": True,
                    "message": (
                        "AI is temporarily unavailable. This local fallback was "
                        "not saved; please retry."
                    ),
                    "fallback_reply": reply,
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        with transaction.atomic():
            if conversation is None:
                conversation = Conversation.objects.create(
                    account=request.user,
                    profile=profile,
                    title=title,
                )
            Message.objects.create(
                conversation=conversation,
                role="USER",
                content=message_text,
            )
            assistant_message = Message.objects.create(
                conversation=conversation,
                role="ASSISTANT",
                content=reply,
                provider=provider.name,
                model_version=provider.model_version,
            )
            conversation.save(update_fields=["updated_at"])
        return Response({
            "conversation_id": str(conversation.id),
            "title": conversation.title,
            "reply": assistant_message.content,
            "created_at": assistant_message.created_at,
        }, status=status.HTTP_200_OK)


class AiConversationListView(ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationSerializer

    def get_queryset(self):
        profile_id = self.request.query_params.get("profile")
        if not profile_id:
            raise ValidationError({"profile": "This query parameter is required."})
        profile_id = serializers.UUIDField().run_validation(profile_id)
        authorized_profile(
            self.request,
            profile_id,
            require_ai_consent=False,
        )
        return Conversation.objects.filter(
            account=self.request.user,
            profile_id=profile_id,
        ).order_by("-updated_at")


class AiConversationMessagesView(ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MessageSerializer

    def get_queryset(self):
        conversation = get_object_or_404(
            Conversation.objects.select_related("profile").filter(
                account=self.request.user
            ),
            pk=self.kwargs["conversation_id"],
        )
        if not PermissionService.has_profile_access(
            self.request.user,
            conversation.profile_id,
            required_permission="view",
        ):
            raise PermissionDenied(
                "You do not have permission to view this conversation."
            )
        return Message.objects.filter(conversation=conversation).order_by(
            "created_at", "pk"
        )
