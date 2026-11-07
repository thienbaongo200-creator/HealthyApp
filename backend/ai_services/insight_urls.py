from django.urls import path

from .views import AIInsightListView, HealthRiskAssessmentView


urlpatterns = [
    path("analyze/", HealthRiskAssessmentView.as_view(), name="ai-insight-analyze"),
    path("", AIInsightListView.as_view(), name="ai-insight-list"),
]
