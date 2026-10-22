import uuid

from django.contrib.auth import get_user_model

from households.models import Household, HouseholdMember, ProfileShare
from profiles.models import PersonProfile


User = get_user_model()


def create_test_household_setup():
    test_id = uuid.uuid4().hex
    owner_user = User.objects.create_user(
        email=f"owner-{test_id}@example.com",
        password="test-password",
    )
    member_active_user = User.objects.create_user(
        email=f"member-active-{test_id}@example.com",
        password="test-password",
    )
    member_pending_user = User.objects.create_user(
        email=f"member-pending-{test_id}@example.com",
        password="test-password",
    )
    outside_user = User.objects.create_user(
        email=f"outside-{test_id}@example.com",
        password="test-password",
    )

    owner_profile = PersonProfile.objects.create(
        account=owner_user,
        full_name="Household Owner",
        profile_type="SELF",
    )
    member_active_profile = PersonProfile.objects.create(
        account=member_active_user,
        full_name="Active Member",
        profile_type="SELF",
    )
    member_pending_profile = PersonProfile.objects.create(
        account=member_pending_user,
        full_name="Pending Member",
        profile_type="SELF",
    )
    outside_profile = PersonProfile.objects.create(
        account=outside_user,
        full_name="Outside User",
        profile_type="SELF",
    )

    household = Household.objects.create(
        name="Test Household",
        created_by=owner_user,
    )
    owner_member = HouseholdMember.objects.create(
        household=household,
        account=owner_user,
        profile=owner_profile,
        role="OWNER",
        status="ACTIVE",
    )
    member_active = HouseholdMember.objects.create(
        household=household,
        account=member_active_user,
        profile=member_active_profile,
        role="MEMBER",
        status="ACTIVE",
    )
    member_pending = HouseholdMember.objects.create(
        household=household,
        account=member_pending_user,
        profile=member_pending_profile,
        role="MEMBER",
        status="PENDING",
    )
    profile_share = ProfileShare.objects.create(
        profile=owner_profile,
        member=member_active,
        share_level="VIEW_ONLY",
    )

    return {
        "owner_user": owner_user,
        "owner_profile": owner_profile,
        "owner_member": owner_member,
        "member_active_user": member_active_user,
        "member_active_profile": member_active_profile,
        "member_active": member_active,
        "member_pending_user": member_pending_user,
        "member_pending_profile": member_pending_profile,
        "member_pending": member_pending,
        "outside_user": outside_user,
        "outside_profile": outside_profile,
        "household": household,
        "profile_share": profile_share,
    }
