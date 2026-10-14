from rest_framework import serializers

from .models import Household, HouseholdMember


class HouseholdSerializer(serializers.ModelSerializer):
    class Meta:
        model = Household
        fields = ["id", "name", "created_at"]
        read_only_fields = ["id", "created_at"]


class HouseholdMemberSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(source="account.email", read_only=True)
    profile_name = serializers.CharField(source="profile.full_name", read_only=True)

    class Meta:
        model = HouseholdMember
        fields = [
            "id",
            "email",
            "profile",
            "profile_name",
            "role",
            "status",
            "invite_expires_at",
        ]
        read_only_fields = fields


class HouseholdInviteSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=["MEMBER", "CAREGIVER"])
    share_profile_id = serializers.UUIDField(required=False)
    share_level = serializers.ChoiceField(
        choices=["VIEW_ONLY", "VIEW_AND_LOG"],
        default="VIEW_ONLY",
    )


class HouseholdMemberUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(
        choices=["MEMBER", "CAREGIVER"],
        required=False,
    )
    share_profile_id = serializers.UUIDField(required=False)
    share_level = serializers.ChoiceField(
        choices=["VIEW_ONLY", "VIEW_AND_LOG"],
        required=False,
    )


class InvitationResponseSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["accept", "decline"])
