from accounts.models import Account
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.urls import reverse
from profiles.models import PersonProfile
from rest_framework import status
from rest_framework.test import APITestCase

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


class HouseholdAPITests(APITestCase):
    def setUp(self):
        self.owner = Account.objects.create_user(
            email="household-api-owner@example.com",
            password="test-password-123",
        )
        self.owner_profile = PersonProfile.objects.create(
            account=self.owner,
            profile_type="SELF",
            full_name="Household API Owner",
        )
        self.invitee = Account.objects.create_user(
            email="household-api-invitee@example.com",
            password="test-password-123",
        )
        self.client.force_authenticate(user=self.owner)

    def test_create_household_and_protect_its_only_owner(self):
        response = self.client.post(
            reverse("household-list"),
            {"name": "API Household"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        household_id = response.data["id"]
        owner_membership = HouseholdMember.objects.get(
            household_id=household_id,
            account=self.owner,
        )

        remove_owner = self.client.delete(
            reverse(
                "household-member-detail",
                kwargs={
                    "household_id": household_id,
                    "member_id": owner_membership.pk,
                },
            )
        )
        self.assertEqual(
            remove_owner.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertTrue(
            HouseholdMember.objects.filter(
                pk=owner_membership.pk,
                role="OWNER",
                status="ACTIVE",
            ).exists()
        )

    def test_owner_invites_account_invitee_accepts_and_owner_can_remove_member(self):
        household = Household.objects.create(
            name="Invitation Household",
            created_by=self.owner,
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.owner,
            profile=self.owner_profile,
            role="OWNER",
            status="ACTIVE",
        )

        invite = self.client.post(
            reverse(
                "household-member-list",
                kwargs={"household_id": household.pk},
            ),
            {
                "email": self.invitee.email,
                "role": "MEMBER",
                "share_level": "VIEW_ONLY",
            },
            format="json",
        )
        self.assertEqual(invite.status_code, status.HTTP_201_CREATED)
        membership = HouseholdMember.objects.get(pk=invite.data["id"])
        self.assertEqual(membership.status, "PENDING")
        self.assertTrue(
            ProfileShare.objects.filter(
                member=membership,
                profile=self.owner_profile,
                share_level="VIEW_ONLY",
            ).exists()
        )

        self.client.force_authenticate(user=self.invitee)
        invitation_list = self.client.get(reverse("invitation-list"))
        self.assertEqual(invitation_list.status_code, status.HTTP_200_OK)
        self.assertEqual(len(invitation_list.data), 1)

        accept = self.client.post(
            reverse(
                "invitation-respond",
                kwargs={"member_id": membership.pk},
            ),
            {"action": "accept"},
            format="json",
        )
        self.assertEqual(accept.status_code, status.HTTP_200_OK)
        membership.refresh_from_db()
        self.assertEqual(membership.status, "ACTIVE")

        self.client.force_authenticate(user=self.owner)
        remove_member = self.client.delete(
            reverse(
                "household-member-detail",
                kwargs={
                    "household_id": household.pk,
                    "member_id": membership.pk,
                },
            )
        )
        self.assertEqual(
            remove_member.status_code,
            status.HTTP_204_NO_CONTENT,
        )
        self.assertFalse(HouseholdMember.objects.filter(pk=membership.pk).exists())

    def test_invite_share_level_defaults_to_view_only_and_rejects_full(self):
        household = Household.objects.create(
            name="Safe Sharing Household",
            created_by=self.owner,
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.owner,
            profile=self.owner_profile,
            role="OWNER",
            status="ACTIVE",
        )
        invite_url = reverse(
            "household-member-list",
            kwargs={"household_id": household.pk},
        )

        invalid_invite = self.client.post(
            invite_url,
            {
                "email": self.invitee.email,
                "share_level": "FULL",
            },
            format="json",
        )
        self.assertEqual(
            invalid_invite.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertFalse(
            HouseholdMember.objects.filter(
                household=household,
                account=self.invitee,
            ).exists()
        )

        invite = self.client.post(
            invite_url,
            {"email": self.invitee.email},
            format="json",
        )
        self.assertEqual(invite.status_code, status.HTTP_201_CREATED)
        membership = HouseholdMember.objects.get(pk=invite.data["id"])
        share = ProfileShare.objects.get(
            member=membership,
            profile=self.owner_profile,
        )
        self.assertEqual(share.share_level, "VIEW_ONLY")

        invalid_update = self.client.patch(
            reverse(
                "household-member-detail",
                kwargs={
                    "household_id": household.pk,
                    "member_id": membership.pk,
                },
            ),
            {"share_level": "FULL"},
            format="json",
        )
        self.assertEqual(
            invalid_update.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        share.refresh_from_db()
        self.assertEqual(share.share_level, "VIEW_ONLY")

    def test_owner_can_invite_and_update_caregiver_role(self):
        household = Household.objects.create(
            name="Caregiver Household",
            created_by=self.owner,
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.owner,
            profile=self.owner_profile,
            role="OWNER",
            status="ACTIVE",
        )

        invite = self.client.post(
            reverse("household-member-list", kwargs={"household_id": household.pk}),
            {
                "email": self.invitee.email,
                "role": "CAREGIVER",
                "share_level": "VIEW_AND_LOG",
            },
            format="json",
        )

        self.assertEqual(invite.status_code, status.HTTP_201_CREATED)
        self.assertEqual(invite.data["role"], "CAREGIVER")
        membership = HouseholdMember.objects.get(pk=invite.data["id"])
        self.assertEqual(membership.role, "CAREGIVER")

        update = self.client.patch(
            reverse(
                "household-member-detail",
                kwargs={"household_id": household.pk, "member_id": membership.pk},
            ),
            {"role": "MEMBER"},
            format="json",
        )
        self.assertEqual(update.status_code, status.HTTP_200_OK)
        self.assertEqual(update.data["role"], "MEMBER")

    def test_non_owner_cannot_invite_household_member(self):
        household = Household.objects.create(
            name="Restricted Household",
            created_by=self.owner,
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.owner,
            profile=self.owner_profile,
            role="OWNER",
            status="ACTIVE",
        )
        member_profile = PersonProfile.objects.create(
            account=self.invitee,
            profile_type="SELF",
            full_name="Invited Member",
        )
        HouseholdMember.objects.create(
            household=household,
            account=self.invitee,
            profile=member_profile,
            role="MEMBER",
            status="ACTIVE",
        )

        self.client.force_authenticate(user=self.invitee)
        response = self.client.post(
            reverse(
                "household-member-list",
                kwargs={"household_id": household.pk},
            ),
            {
                "email": "another-account@example.com",
                "role": "MEMBER",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
