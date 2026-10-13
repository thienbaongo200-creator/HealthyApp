from accounts.models import Account
from django.db import IntegrityError, transaction
from django.test import TestCase
from profiles.models import PersonProfile

from .models import Device


class DeviceModelTests(TestCase):
    def setUp(self):
        self.account = Account.objects.create_user(
            email="device-owner@example.com",
            password="safe-password",
        )
        self.profile = PersonProfile.objects.create(
            account=self.account,
            profile_type="SELF",
            full_name="Device Owner",
        )

    def test_device_identifier_must_be_unique_in_database(self):
        Device.objects.create(
            profile=self.profile,
            device_identifier="watch-001",
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Device.objects.create(
                    profile=self.profile,
                    device_identifier="watch-001",
                )

    def test_deleting_profile_cascades_to_its_devices(self):
        device = Device.objects.create(
            profile=self.profile,
            device_identifier="watch-cascade",
        )

        self.profile.delete()

        self.assertFalse(Device.objects.filter(pk=device.pk).exists())
