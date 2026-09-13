from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class PersonProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    gender = models.CharField(max_length=20, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    height_cm = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)

    def __str__(self):
        return f"Profile of {self.user.username}"


class HealthMeasurement(models.Model):
    profile = models.ForeignKey(PersonProfile, on_delete=models.CASCADE, related_name='measurements')
    device_id = models.CharField(max_length=100)
    measured_at = models.DateTimeField()
    idempotency_key = models.UUIDField()
    heart_rate = models.PositiveIntegerField()
    steps = models.PositiveIntegerField(default=0)
    calories = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    
    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'idempotency_key'],
                name='unique_profile_measurement_key',
            ),
        ]

    def __str__(self):
        return f"{self.profile.user.username} - {self.measured_at}"

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        PersonProfile.objects.get_or_create(user=instance)