from django.db.models import F, Q
from rest_framework import permissions

from households.models import HouseholdMember, ProfileShare
from profiles.models import PersonProfile


class PermissionService:
    """Central object-level authorization for profiles and their child records."""

    @staticmethod
    def _user_memberships(user):
        return HouseholdMember.objects.filter(
            account=user,
            status="ACTIVE",
        )

    @classmethod
    def owner_household_ids(cls, user):
        return cls._user_memberships(user).filter(role="OWNER").values_list(
            "household_id", flat=True
        )

    @classmethod
    def is_active_owner(cls, user, household=None):
        memberships = cls._user_memberships(user).filter(role="OWNER")
        if household is not None:
            memberships = memberships.filter(household=household)
        return memberships.exists()

    @classmethod
    def accessible_profiles(cls, user):
        """Return a database-filtered queryset of profiles the account may view."""
        if not user or not user.is_authenticated:
            return PersonProfile.objects.none()

        memberships = cls._user_memberships(user)
        owner_households = memberships.filter(role="OWNER").values_list(
            "household_id", flat=True
        )
        # A share is valid only when its member and target profile both belong to
        # the same household. Validate that relation in SQL, not in Python loops.
        shared_profile_ids = ProfileShare.objects.filter(
            member__in=memberships,
            member__status="ACTIVE",
            profile__household_links__household_id=F("member__household_id"),
            profile__household_links__status="ACTIVE",
            share_level__in=("VIEW_ONLY", "VIEW_AND_LOG"),
        )
        return PersonProfile.objects.filter(
            Q(account=user, profile_type="SELF")
            | Q(household_links__household_id__in=owner_households,
                household_links__status="ACTIVE")
            | Q(pk__in=shared_profile_ids.filter(
                share_level__in=("VIEW_ONLY", "VIEW_AND_LOG"),
                member__status="ACTIVE",
            ).values("profile_id")),
            is_archived=False,
        ).distinct()

    @classmethod
    def has_profile_access(cls, user, profile_id, required_permission="view"):
        if not user or not user.is_authenticated:
            return False
        try:
            profile = PersonProfile.objects.get(pk=profile_id, is_archived=False)
        except (PersonProfile.DoesNotExist, ValueError, TypeError):
            return False

        # SELF and explicitly linked profiles belong to the linked account.
        if profile.profile_type == "SELF" and profile.account_id == user.pk:
            return True

        # A current active OWNER has household-wide access, subject to a live
        # membership for the target profile in that same household.
        target_households = HouseholdMember.objects.filter(
            profile=profile,
            status="ACTIVE",
        ).values_list("household_id", flat=True)
        owner_access = cls._user_memberships(user).filter(
            household_id__in=target_households,
            role="OWNER",
        ).exists()
        if owner_access:
            return True

        # No shared role can edit profiles or existing records. VIEW_AND_LOG
        # grants MEMBER and CAREGIVER creation of a new manual measurement.
        shares = ProfileShare.objects.filter(
            profile=profile,
            member__in=cls._user_memberships(user),
            member__household_id__in=target_households,
        )
        if required_permission == "view":
            return shares.filter(
                share_level__in=("VIEW_ONLY", "VIEW_AND_LOG")
            ).exists()
        if required_permission in {"measurement_write", "measurement_create"}:
            return shares.filter(
                share_level="VIEW_AND_LOG",
                member__role__in=("MEMBER", "CAREGIVER"),
            ).exists()
        return False

    @classmethod
    def is_caregiver_for_profile(cls, user, profile):
        target_households = HouseholdMember.objects.filter(
            profile=profile, status="ACTIVE"
        ).values_list("household_id", flat=True)
        return ProfileShare.objects.filter(
            profile=profile,
            member__in=cls._user_memberships(user),
            member__household_id__in=target_households,
            member__role="CAREGIVER",
            share_level__in=("VIEW_ONLY", "VIEW_AND_LOG"),
        ).exists()

    @staticmethod
    def has_profile_ai_consent(profile):
        from ai_services.services.consent import AIConsentService

        return AIConsentService.has_consent(profile)


class IsProfileOwnerOrShared(permissions.BasePermission):
    message = "Bạn không có quyền truy cập hoặc chỉnh sửa hồ sơ này."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if isinstance(obj, PersonProfile):
            profile_id = obj.pk
        else:
            profile_id = getattr(obj, "profile_id", None)
            if profile_id is None:
                profile_id = getattr(getattr(obj, "profile", None), "pk", None)
        if profile_id is None:
            return False
        permission = "view" if request.method in permissions.SAFE_METHODS else "edit"
        return PermissionService.has_profile_access(
            request.user, profile_id, required_permission=permission
        )
