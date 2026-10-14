from accounts.models import Account
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import PersonProfile


class PersonProfileModelTests(TestCase):
    def test_account_can_own_multiple_profiles_and_dependent_can_be_unlinked(self):
        account = Account.objects.create_user(
            email="profiles@example.com",
            password="safe-password",
        )
        self_profile = PersonProfile.objects.create(
            account=account,
            profile_type="SELF",
            full_name="Account Holder",
        )
        dependent_profile = PersonProfile.objects.create(
            account=account,
            profile_type="DEPENDENT",
            full_name="Dependent",
        )
        unlinked_dependent = PersonProfile.objects.create(
            account=None,
            profile_type="DEPENDENT",
            full_name="Unlinked Dependent",
        )

        self.assertEqual(account.profiles.count(), 2)
        self.assertEqual(self_profile.account, account)
        self.assertEqual(dependent_profile.account, account)
        self.assertIsNone(unlinked_dependent.account)

    def test_deleting_account_unlinks_profiles_instead_of_deleting_them(self):
        account = Account.objects.create_user(
            email="unlink@example.com",
            password="safe-password",
        )
        profile = PersonProfile.objects.create(
            account=account,
            profile_type="SELF",
            full_name="Retained Profile",
        )

        account.delete()

        profile.refresh_from_db()
        self.assertIsNone(profile.account)


class PersonProfileAPITests(APITestCase):
    def setUp(self):
        self.account = Account.objects.create_user(
            email="profile-api@example.com",
            password="test-password-123",
        )
        self.client.force_authenticate(user=self.account)

    def test_create_list_update_and_archive_profile(self):
        create_response = self.client.post(
            reverse("profile-list"),
            {
                "profile_type": "DEPENDENT",
                "full_name": "Dependent Profile",
                "gender": "female",
            },
            format="json",
        )
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        profile_id = create_response.data["id"]
        profile = PersonProfile.objects.get(pk=profile_id)
        self.assertEqual(profile.account, self.account)
        self.assertEqual(profile.profile_type, "DEPENDENT")

        list_response = self.client.get(reverse("profile-list"))
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_response.data), 1)

        update_response = self.client.patch(
            reverse("profile-detail", kwargs={"pk": profile_id}),
            {"full_name": "Updated Dependent"},
            format="json",
        )
        self.assertEqual(update_response.status_code, status.HTTP_200_OK)

        archive_response = self.client.delete(
            reverse("profile-detail", kwargs={"pk": profile_id}),
        )
        self.assertEqual(
            archive_response.status_code,
            status.HTTP_204_NO_CONTENT,
        )
        profile.refresh_from_db()
        self.assertTrue(profile.is_archived)
