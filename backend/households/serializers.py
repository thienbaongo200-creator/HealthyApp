from rest_framework import serializers
from .models import Household, HouseholdMember

class HouseholdSerializer(serializers.ModelSerializer):
    class Meta:
        model = Household
        fields = ['id', 'name', 'created_at']
        read_only_fields = ['id', 'created_at']


class HouseholdMemberSerializer(serializers.ModelSerializer):
    household_name = serializers.ReadOnlyField(source='household.name')
    user_email = serializers.ReadOnlyField(source='account.email')

    class Meta:
        model = HouseholdMember
        fields = ['id', 'household', 'household_name', 'user_email', 'role', 'status', 'created_at']
        read_only_fields = ['id', 'created_at']


class HouseholdMemberUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=['OWNER', 'MEMBER', 'VIEW_ONLY'], required=False)
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        required=False,
    )


class HouseholdInviteSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=['MEMBER', 'VIEW_ONLY'], default='MEMBER')
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        default='VIEW_ONLY',
    )


class InvitationResponseSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=['accept', 'decline'])