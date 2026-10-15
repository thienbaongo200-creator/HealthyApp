from django.urls import path
from .views import AiChatSessionView, HealthRiskAssessmentView

urlpatterns = [
    path('assess-risk/<uuid:profile_id>/', HealthRiskAssessmentView.as_view(), name='ai-risk-assessment'),
    path('chat/<uuid:profile_id>/', AiChatSessionView.as_view(), name='ai-chat-session'),
]