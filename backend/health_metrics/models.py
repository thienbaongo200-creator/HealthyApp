from django.db import models
from django.contrib.auth.models import User

# Create your models here.
class HealthData(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='health_records',
        null=True,
        blank=True
    )
    heart_rate = models.IntegerField(help_text="Nhịp tim (bpm)")
    steps = models.IntegerField(default=0, help_text="Số bước chân")
    calories = models.FloatField(default=0.0, help_text="Lượng calo (kcal)")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at'] # Sắp xếp bản ghi mới nhất lên đầu

    def __str__(self):
        username = self.user.username if self.user else 'Anonymous'
        return f"{username} - HR: {self.heart_rate} bpm ({self.created_at.strftime('%Y-%m-%d %H:%M')})"

