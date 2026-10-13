from accounts.models import Account
from django.test import TestCase

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
