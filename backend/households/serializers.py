from rest_framework import serializers
from .models import Household, HouseholdMember, ProfileShare

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
        memberships = household.members.filter(
            account=request.user,
            status="ACTIVE",
        )
        if memberships.filter(role="OWNER").exists():
            return "OWNER"
        return memberships.order_by("created_at").values_list("role", flat=True).first()


class HouseholdMemberSerializer(serializers.ModelSerializer):
    household_name = serializers.ReadOnlyField(source='household.name')
    user_email = serializers.ReadOnlyField(source='account.email')
    profile_name = serializers.ReadOnlyField(source='profile.full_name')
    profile_type = serializers.ReadOnlyField(source='profile.profile_type')
    shares = serializers.SerializerMethodField()

    class Meta:
        model = HouseholdMember
        fields = [
            'id', 'household', 'household_name', 'profile', 'profile_name',
            'profile_type', 'user_email', 'role', 'status', 'created_at',
            'shares',
        ]
        read_only_fields = ['id', 'profile', 'created_at']

    def get_shares(self, member):
        return list(
            ProfileShare.objects.filter(member=member)
            .select_related('profile')
            .values(
                'profile_id',
                'profile__full_name',
                'share_level',
            )
        )


class HouseholdMemberUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=['MEMBER', 'CAREGIVER'], required=False)
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        required=False,
    )
    share_profile_id = serializers.UUIDField(required=False)


class HouseholdInviteSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=['MEMBER', 'CAREGIVER'], default='MEMBER')
    share_level = serializers.ChoiceField(
        choices=['VIEW_ONLY', 'VIEW_AND_LOG'],
        default='VIEW_ONLY',
    )


class InvitationResponseSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=['accept', 'decline'])
