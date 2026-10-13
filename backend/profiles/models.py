import uuid
from django.db import models
from accounts.models import Account

class PersonProfile(models.Model):
    PROFILE_TYPE_CHOICES = (
        ('SELF', 'Self'),
        ('DEPENDENT', 'Dependent'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    account = models.ForeignKey(Account, on_delete=models.SET_NULL, null=True, blank=True, related_name='profiles')
    profile_type = models.CharField(max_length=20, choices=PROFILE_TYPE_CHOICES, default='SELF')
    full_name = models.CharField(max_length=255)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=20, null=True, blank=True)
    height_cm = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    blood_type = models.CharField(max_length=10, null=True, blank=True)
    emergency_contact = models.CharField(max_length=255, null=True, blank=True)
    is_archived = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.full_name} ({self.profile_type})"