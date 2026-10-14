from django.urls import path
from .views import HealthRiskAssessmentView

urlpatterns = [
    path('assess-risk/<uuid:profile_id>/', HealthRiskAssessmentView.as_view(), name='ai-risk-assessment'),
]