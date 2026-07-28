from django.urls import path
from .views import HealthDataListCreateView

urlpatterns = [
    path('health/', HealthDataListCreateView.as_view(), name='health-list-create'),
]

