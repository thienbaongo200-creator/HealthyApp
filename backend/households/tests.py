from accounts.models import Account
from django.db import IntegrityError, transaction
from django.test import TestCase
from profiles.models import PersonProfile

from .models import Household, HouseholdMember, ProfileShare


class HouseholdModelTests(TestCase):
    def setUp(self):
        self.owner = Account.objects.create_user(
            email="household-owner@example.com",
            password="safe-password",
        )
        self.owner_profile = PersonProfile.objects.create(
            account=self.owner,
            profile_type="SELF",
            full_name="Household Owner",
        )
        self.household = Household.objects.create(
            name="Test Household",
            created_by=self.owner,
        )

    def test_household_member_profile_pair_must_be_unique(self):
        HouseholdMember.objects.create(
            household=self.household,
            profile=self.owner_profile,
            account=self.owner,
            role="OWNER",
            status="ACTIVE",
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                HouseholdMember.objects.create(
                    household=self.household,
                    profile=self.owner_profile,
                    account=self.owner,
                    role="OWNER",
                    status="ACTIVE",
                )

    def test_profile_share_member_profile_pair_must_be_unique(self):
        member = HouseholdMember.objects.create(
            household=self.household,
            profile=self.owner_profile,
            account=self.owner,
            role="OWNER",
            status="ACTIVE",
        )
        ProfileShare.objects.create(
            member=member,
            profile=self.owner_profile,
            share_level="VIEW_ONLY",
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                ProfileShare.objects.create(
                    member=member,
                    profile=self.owner_profile,
                    share_level="VIEW_AND_LOG",
                )

    def test_deleting_profile_cascades_to_household_members_and_shares(self):
        member = HouseholdMember.objects.create(
            household=self.household,
            profile=self.owner_profile,
            account=self.owner,
            role="OWNER",
            status="ACTIVE",
        )
        share = ProfileShare.objects.create(
            member=member,
            profile=self.owner_profile,
            share_level="VIEW_ONLY",
        )

        self.owner_profile.delete()

        self.assertFalse(HouseholdMember.objects.filter(pk=member.pk).exists())
        self.assertFalse(ProfileShare.objects.filter(pk=share.pk).exists())
