from django.db.models import Q
from rest_framework import serializers
from .models import Household, HouseholdMember

class HouseholdSerializer(serializers.ModelSerializer):
    viewer_role = serializers.SerializerMethodField()

    class Meta:
        model = Household
        fields = ['id', 'name', 'created_at', 'viewer_role']
        read_only_fields = ['id', 'created_at']

    def get_viewer_role(self, household):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return None

        return (
            household.members.filter(status="ACTIVE")
            .filter(
                Q(account=request.user)
                | Q(profile__account=request.user)
                | Q(profile__created_by=request.user)
            )
            .order_by("created_at")
            .values_list("role", flat=True)
            .first()
        )


class HouseholdMemberSerializer(serializers.ModelSerializer):
    household_name = serializers.ReadOnlyField(source='household.name')
    user_email = serializers.ReadOnlyField(source='account.email')
    profile_name = serializers.ReadOnlyField(source='profile.full_name')
    profile_type = serializers.ReadOnlyField(source='profile.profile_type')

    class Meta:
        model = HouseholdMember
        fields = [
            'id', 'household', 'household_name', 'profile', 'profile_name',
            'profile_type', 'user_email', 'role', 'status', 'created_at',
        ]
        read_only_fields = ['id', 'profile', 'created_at']


class HouseholdMemberUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=['MEMBER', 'CAREGIVER'], required=False)
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        required=False,
    )


class HouseholdInviteSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=['MEMBER', 'CAREGIVER'], default='MEMBER')
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        default='VIEW_ONLY',
    )


class InvitationResponseSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=['accept', 'decline'])