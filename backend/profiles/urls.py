from django.urls import path
from .views import ProfileAIConsentView, ProfileListCreateView, ProfileDetailView

urlpatterns = [
    path('', ProfileListCreateView.as_view(), name='profile-list'),
    path('<uuid:pk>/', ProfileDetailView.as_view(), name='profile-detail'),
    path('<uuid:profile_id>/ai-consent/', ProfileAIConsentView.as_view(), name='profile-ai-consent'),
]
