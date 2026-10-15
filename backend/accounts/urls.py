from django.urls import path
from .views import AiConsentView, LoginView, ProfileView, RegisterView, LogoutView
from rest_framework_simplejwt.views import TokenRefreshView, TokenObtainPairView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('profile/', ProfileView.as_view(), name='auth-profile'),
    path('ai-consent/', AiConsentView.as_view(), name='auth-ai-consent'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('refresh/', TokenRefreshView.as_view(), name='auth-refresh'),
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
