from django.urls import path
from .views import DashboardPreferenceView

urlpatterns = [path("preferences/", DashboardPreferenceView.as_view(), name="dashboard-preferences")]
