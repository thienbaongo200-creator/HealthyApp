from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ai_services.models import Conversation, Message
from ai_services.services.assistant import build_health_context, generate_reply
from ai_services.services.risk_engine import RiskRuleEngine
from core.permissions import PermissionService
from profiles.models import PersonProfile


def authorized_profile(request, profile_id):
    if not PermissionService.has_profile_access(request.user, profile_id, required_permission="view"):
        raise PermissionDenied("You do not have permission to view this profile.")
    profile = get_object_or_404(PersonProfile, id=profile_id, is_archived=False)
    # Consent belongs to the account that owns the health profile (the data subject
    # or its recorded guardian), not merely the household member making the request.
    consent_account = profile.account
    if consent_account is None or not consent_account.ai_consent:
        raise PermissionDenied("AI consent from the profile owner is required.")
    return profile


class HealthRiskAssessmentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, profile_id):
        profile = authorized_profile(request, profile_id)
        result = RiskRuleEngine().assess(profile)
        code = status.HTTP_422_UNPROCESSABLE_ENTITY if result["risk_level"] == "UNKNOWN" else status.HTTP_200_OK
        return Response({"profile_id": str(profile.id), **result}, status=code)


class AiChatSessionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, profile_id):
        profile = authorized_profile(request, profile_id)
        message_text = request.data.get("message", "")
        if not isinstance(message_text, str) or not message_text.strip():
            return Response({"error": "Message content is required."}, status=status.HTTP_400_BAD_REQUEST)
        message_text = message_text.strip()

        conversation_id = request.data.get("conversation_id")
        if conversation_id:
            conversation = get_object_or_404(
                Conversation, id=conversation_id, account=request.user, profile=profile
            )
        else:
            title = message_text[:30] + ("..." if len(message_text) > 30 else "")
            conversation = Conversation.objects.create(
                account=request.user, profile=profile, title=title
            )

        Message.objects.create(conversation=conversation, role="USER", content=message_text)
        context = build_health_context(profile)
        reply, provider = generate_reply(message=message_text, context=context)
        assistant_message = Message.objects.create(
            conversation=conversation,
            role="ASSISTANT",
            content=reply,
            provider=provider.name,
            model_version=provider.model_version,
        )
        return Response({
            "conversation_id": str(conversation.id),
            "title": conversation.title,
            "reply": assistant_message.content,
            "created_at": assistant_message.created_at,
        }, status=status.HTTP_200_OK)
