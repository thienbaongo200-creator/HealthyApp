import uuid

from django.test import TestCase
from django.contrib.auth import get_user_model
from profiles.models import PersonProfile
from households.models import Household, HouseholdMember, ProfileShare
from core.permissions import PermissionService

User = get_user_model()

class PermissionServiceTestCase(TestCase):
    def setUp(self):
        test_id = uuid.uuid4().hex
        # 1. Tạo 2 tài khoản người dùng độc lập
        self.user_owner = User.objects.create_user(email=f"owner-{test_id}@example.com", password="password123")
        self.user_other = User.objects.create_user(email=f"other-{test_id}@example.com", password="password123")

        # 2. Tạo profile cho owner và other
        self.profile_owner = PersonProfile.objects.create(
            account=self.user_owner,
            full_name="Nguyễn Văn Owner",
            profile_type="SELF"
        )
        self.profile_other = PersonProfile.objects.create(
            account=self.user_other,
            full_name="Trần Thị Other",
            profile_type="SELF"
        )

        # 3. Tạo Household (truyền thêm created_by=self.user_owner để thỏa mãn NotNullViolation) và HouseholdMember
        self.household = Household.objects.create(
            name="Gia Đình Test",
            created_by=self.user_owner
        )
        HouseholdMember.objects.create(
            household=self.household, profile=self.profile_owner, role="OWNER", status="ACTIVE"
        )
        self.household_member_other = HouseholdMember.objects.create(
            household=self.household, profile=self.profile_other, role="MEMBER", status="ACTIVE"
        )

    def test_owner_access(self):
        """Chính chủ phải có toàn quyền view và edit trên profile của mình"""
        self.assertTrue(PermissionService.has_profile_access(self.user_owner, self.profile_owner.id, 'view'))
        self.assertTrue(PermissionService.has_profile_access(self.user_owner, self.profile_owner.id, 'edit'))

    def test_idor_blocked(self):
        """User ngoài không được phép xem hay sửa profile của người khác (Chống IDOR)"""
        self.assertFalse(PermissionService.has_profile_access(self.user_other, self.profile_owner.id, 'view'))
        self.assertFalse(PermissionService.has_profile_access(self.user_other, self.profile_owner.id, 'edit'))

    def test_profile_share_permissions(self):
        """Kiểm tra quyền qua ProfileShare (VIEW_ONLY vs VIEW_AND_LOG dựa trên share_level)"""
        # Trường hợp 1: Chỉ cho phép xem (VIEW_ONLY)
        share = ProfileShare.objects.create(
            profile=self.profile_owner,
            member=self.household_member_other,
            share_level='VIEW_ONLY'
        )

        # User other phải được xem nhưng KHÔNG được edit
        self.assertTrue(PermissionService.has_profile_access(self.user_other, self.profile_owner.id, 'view'))
        self.assertFalse(PermissionService.has_profile_access(self.user_other, self.profile_owner.id, 'edit'))

        # Trường hợp 2: Nâng cấp lên cho phép cả ghi log (VIEW_AND_LOG)
        share.share_level = 'VIEW_AND_LOG'
        share.save()
        self.assertFalse(
            PermissionService.has_profile_access(
                self.user_other,
                self.profile_owner.id,
                'edit',
            )
        )
        self.assertTrue(
            PermissionService.has_profile_access(
                self.user_other,
                self.profile_owner.id,
                'measurement_write',
            )
        )

    def test_caregiver_share_is_read_only_even_when_share_level_allows_logging(self):
        caregiver_membership = self.household_member_other
        caregiver_membership.account = self.user_other
        caregiver_membership.role = "CAREGIVER"
        caregiver_membership.save(update_fields=["account", "role"])
        ProfileShare.objects.create(
            profile=self.profile_owner,
            member=caregiver_membership,
            share_level="VIEW_AND_LOG",
        )

        self.assertTrue(
            PermissionService.has_profile_access(
                self.user_other,
                self.profile_owner.id,
                required_permission="view",
            )
        )
        self.assertFalse(
            PermissionService.has_profile_access(
                self.user_other,
                self.profile_owner.id,
                required_permission="edit",
            )
        )
        self.assertFalse(
            PermissionService.has_profile_access(
                self.user_other,
                self.profile_owner.id,
                required_permission="measurement_write",
            )
        )