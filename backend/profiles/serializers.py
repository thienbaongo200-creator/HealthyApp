from django.db.models import Q
from django.db import transaction
from rest_framework import serializers
from households.models import Household, HouseholdMember, ProfileShare
from .models import PersonProfile


class HouseholdRoleField(serializers.Field):
    default_error_messages = {
        "invalid": "Role must be MEMBER or CAREGIVER.",
    }

    def get_attribute(self, instance):
        return instance

    def to_internal_value(self, data):
        if not isinstance(data, str) or data not in ("MEMBER", "CAREGIVER"):
            self.fail("invalid")
        return data

    def to_representation(self, profile):
        membership = HouseholdMember.objects.filter(
            profile=profile,
            status="ACTIVE",
        ).order_by("created_at").first()
        if membership:
            return membership.role
        return "OWNER" if profile.profile_type == "SELF" else "MEMBER"


def _save_household_role(profile, account, role):
    with transaction.atomic():
        owner_household_ids = list(
            HouseholdMember.objects.filter(
                account=account,
                role="OWNER",
                status="ACTIVE",
            ).values_list("household_id", flat=True)
        )
        if not owner_household_ids:
            household = Household.objects.create(
                name=f"{account.email.partition('@')[0]}'s household",
                created_by=account,
            )
            owner_profile, _ = PersonProfile.objects.get_or_create(
                account=account,
                profile_type="SELF",
                defaults={
                    "full_name": account.email.partition("@")[0],
                    "created_by": account,
                },
            )
            HouseholdMember.objects.create(
                household=household,
                account=account,
                profile=owner_profile,
                role="OWNER",
                status="ACTIVE",
            )
            owner_household_ids = [household.pk]

        for household_id in owner_household_ids:
            membership, _ = HouseholdMember.objects.get_or_create(
                household_id=household_id,
                profile=profile,
                defaults={
                    "account": account,
                    "role": role,
                    "status": "ACTIVE",
                },
            )
            if membership.role != role or membership.status != "ACTIVE":
                membership.role = role
                membership.status = "ACTIVE"
                membership.save(update_fields=["role", "status", "updated_at"])


class PersonProfileSerializer(serializers.ModelSerializer):
    household_role = HouseholdRoleField(required=False)
    viewer_role = serializers.SerializerMethodField()
    share_level = serializers.SerializerMethodField()
    is_current_user = serializers.SerializerMethodField()

    class Meta:
        model = PersonProfile
        fields = [
            "id",
            "profile_type",
            "is_current_user",
            "relation_type",
            "household_role",
            "viewer_role",
            "share_level",
            "full_name",
            "date_of_birth",
            "gender",
            "height_cm",
            "weight_kg",
            "blood_type",
            "emergency_contact",
            "is_archived",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "profile_type", "is_archived", "created_at", "updated_at"]

    def get_is_current_user(self, profile):
        request = self.context.get("request")
        return bool(
            request
            and request.user.is_authenticated
            and profile.profile_type == "SELF"
            and profile.account_id == request.user.pk
        )

    def _sharing(self, profile):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return None
        return (
            ProfileShare.objects.select_related("member")
            .filter(
                profile=profile,
                member__account=request.user,
                member__status="ACTIVE",
            )
            .order_by("created_at")
            .first()
        )

    def get_viewer_role(self, profile):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return None

        if profile.account_id == request.user.pk or profile.created_by_id == request.user.pk:
            return "OWNER"

        share = self._sharing(profile)
        if share:
            return share.member.role

        membership = HouseholdMember.objects.filter(
            profile=profile,
            account=request.user,
            status="ACTIVE",
        ).order_by("created_at").first()
        if membership:
            return membership.role

        is_household_owner = HouseholdMember.objects.filter(
            Q(profile__account=request.user) | Q(profile__created_by=request.user),
            status="ACTIVE",
            role="OWNER",
            household__members__profile=profile,
            household__members__status="ACTIVE",
        ).exists()
        if is_household_owner:
            return "OWNER"

        return "MEMBER"

    def get_share_level(self, profile):
        share = self._sharing(profile)
        if share:
            return share.share_level
        request = self.context.get("request")
        if request and (
            profile.account_id == request.user.pk
            or profile.created_by_id == request.user.pk
        ):
            return "FULL"
        return "VIEW_ONLY"

    def validate_household_role(self, value):
        if self.instance and self.instance.profile_type == "SELF":
            raise serializers.ValidationError("The primary profile role cannot be changed.")
        return value

    def create(self, validated_data):
        role = validated_data.pop("household_role", "MEMBER")
        profile = super().create(validated_data)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            _save_household_role(profile, request.user, role)
        return profile

    def update(self, instance, validated_data):
        role = validated_data.pop("household_role", None)
        profile = super().update(instance, validated_data)
        request = self.context.get("request")
        if role and request and request.user.is_authenticated:
            _save_household_role(profile, request.user, role)
        return profile

    def validate_relation_type(self, value):
        if self.instance and self.instance.profile_type == "SELF" and value:
            raise serializers.ValidationError("SELF profiles cannot have a family relation.")
        return value


class PersonProfileCreateSerializer(serializers.ModelSerializer):
    household_role = HouseholdRoleField(required=False, default="MEMBER")

    class Meta:
        model = PersonProfile
        fields = [
            "profile_type",
            "relation_type",
            "household_role",
            "full_name",
            "date_of_birth",
            "gender",
            "height_cm",
            "weight_kg",
            "blood_type",
            "emergency_contact",
        ]

    def validate_profile_type(self, value):
        if value not in {"SELF", "DEPENDENT"}:
            raise serializers.ValidationError("Unsupported profile type.")
        return value

    def validate(self, attrs):
        if attrs.get("profile_type", "DEPENDENT") == "SELF" and attrs.get("relation_type"):
            raise serializers.ValidationError({"relation_type": "SELF profiles cannot have a family relation."})
        return attrs

    def create(self, validated_data):
        validated_data.setdefault("profile_type", "DEPENDENT")
        role = validated_data.pop("household_role", "MEMBER")
        creator = self.context["request"].user
        profile = PersonProfile.objects.create(
            account=creator,
            created_by=creator,
            **validated_data,
        )
        _save_household_role(profile, creator, role)
        return profile
