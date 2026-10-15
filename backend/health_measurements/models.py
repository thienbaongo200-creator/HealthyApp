import uuid
from django.db import models
from profiles.models import PersonProfile
from devices.models import Device

class HealthMeasurement(models.Model):
    TYPE_CHOICES = (
        ('BLOOD_PRESSURE', 'Blood Pressure'),
        ('HEART_RATE', 'Heart Rate'),
        ('BLOOD_GLUCOSE', 'Blood Glucose'),
        ('BMI', 'BMI'),
        ('STEPS', 'Steps'),
        ('CALORIES', 'Calories'),
        ('WEIGHT', 'Weight'),
        ('HEIGHT', 'Height'),
        ('TEMPERATURE', 'Temperature'),
    )
    SOURCE_CHOICES = (
        ('MANUAL', 'Manual'),
        ('WEAR_OS', 'Wear OS'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(PersonProfile, on_delete=models.CASCADE, related_name='measurements')
    measurement_type = models.CharField(max_length=50, choices=TYPE_CHOICES)
    value = models.DecimalField(max_digits=10, decimal_places=2)
    value_secondary = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    unit = models.CharField(max_length=50)
    measured_at = models.DateTimeField()
    start_time = models.DateTimeField(null=True, blank=True)
    end_time = models.DateTimeField(null=True, blank=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)
    device = models.ForeignKey(Device, on_delete=models.SET_NULL, null=True, blank=True, related_name='measurements')
    
    # Khóa chống trùng lặp theo yêu cầu NFR03 & BR07
    idempotency_key = models.CharField(max_length=255, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['profile', 'idempotency_key'], name='unique_profile_idempotency')
        ]
        indexes = [
            models.Index(fields=['profile', 'measurement_type', '-measured_at'], name='meas_profile_type_date_idx')
        ]
