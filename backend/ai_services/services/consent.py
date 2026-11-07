from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from ai_services.models import AIConsent
from households.models import HouseholdMember


class AIConsentService:
    @staticmethod
    def can_manage(user, profile):
        if profile.profile_type == "SELF":
            return profile.account_id == user.pk

        if profile.created_by_id == user.pk:
            return True

        return HouseholdMember.objects.filter(
            profile=profile,
            status="ACTIVE",
            role="OWNER",
            account=user,
        ).exists()

    @classmethod
    def set_consent(cls, *, user, profile, granted, version):
        if not cls.can_manage(user, profile):
            raise PermissionDenied("Only the profile owner or guardian may manage consent.")

        record, _ = AIConsent.objects.get_or_create(
            profile=profile,
            defaults={
                "granted_by_account": user,
                "status": "REVOKED",
                "consent_version": version,
            },
        )
        now = timezone.now()
        record.granted_by_account = user
        record.consent_version = version
        record.status = "GRANTED" if granted else "REVOKED"
        record.granted_at = now if granted else record.granted_at
        record.revoked_at = None if granted else now
        record.save(
            update_fields=(
                "granted_by_account",
                "consent_version",
                "status",
                "granted_at",
                "revoked_at",
            )
        )
        return record

    @staticmethod
    def has_consent(profile):
        return AIConsent.objects.filter(profile=profile, status="GRANTED").exists()
