import uuid
from django.db import models
from accounts.models import Account
from profiles.models import PersonProfile

class Household(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    created_by = models.ForeignKey(Account, on_delete=models.CASCADE, related_name='created_households')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class HouseholdMember(models.Model):
    ROLE_CHOICES = (
        ('OWNER', 'Owner'),
        ('MEMBER', 'Member'),
        ('CAREGIVER', 'Caregiver'),
    )
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('ACTIVE', 'Active'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    household = models.ForeignKey(Household, on_delete=models.CASCADE, related_name='members')
    account = models.ForeignKey(Account, on_delete=models.CASCADE, null=True, blank=True, related_name='household_memberships')
    profile = models.ForeignKey(PersonProfile, on_delete=models.CASCADE, related_name='household_links')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    invite_expires_at = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['household', 'profile'], name='unique_household_profile')
        ]

class ProfileShare(models.Model):
    SHARE_LEVEL_CHOICES = (
        ('VIEW_ONLY', 'View Only'),
        ('VIEW_AND_LOG', 'View and Log'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(HouseholdMember, on_delete=models.CASCADE, related_name='shares')
    profile = models.ForeignKey(PersonProfile, on_delete=models.CASCADE, related_name='shared_permissions')
    share_level = models.CharField(max_length=20, choices=SHARE_LEVEL_CHOICES)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['member', 'profile'], name='unique_member_profile_share')
        ]