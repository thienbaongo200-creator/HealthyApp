from django.db import models
from profiles.models import PersonProfile


class DashboardPreference(models.Model):
    profile = models.OneToOneField(
        PersonProfile, on_delete=models.CASCADE, related_name="dashboard_preference"
    )
    selected_metrics = models.JSONField(default=list)
    metric_order = models.JSONField(default=list)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Dashboard preference for {self.profile_id}"
