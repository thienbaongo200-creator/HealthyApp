from django.contrib import admin
from .models import HealthData

@admin.register(HealthData)
class HealthDataAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'heart_rate', 'steps', 'calories', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username']

