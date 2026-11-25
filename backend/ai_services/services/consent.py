from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from ai_services.models import AIConsent
from households.models import HouseholdMember


class AIConsentService:
    @staticmethod
    def can_manage(user, profile):
        if not user or not user.is_authenticated:
            return False
        if profile.profile_type == "SELF":
            return profile.account_id == user.pk

        # Consent for a dependent belongs to the current guardian/household
        # owner. Being the historical creator is not an enduring grant.
        target_household_ids = HouseholdMember.objects.filter(
            profile=profile,
            status="ACTIVE",
        ).values_list("household_id", flat=True)
        return HouseholdMember.objects.filter(
            household_id__in=target_household_ids,
            account=user,
            status="ACTIVE",
            role="OWNER",
        ).exists()

    @classmethod
    def set_consent(cls, *, user, profile, granted, version):
        if not cls.can_manage(user, profile):
            raise PermissionDenied("Chỉ chủ hồ sơ hoặc người giám hộ mới được quản lý sự đồng ý sử dụng AI.")

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
