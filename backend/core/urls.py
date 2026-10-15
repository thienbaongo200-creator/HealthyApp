"""
URL configuration for core project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/', include('profiles.urls')),
    path('api/profiles/', include('profiles.urls')),
    #path('api/devices/', include('devices.urls')),
    #path('api/health/', include('health_measurements.urls')),
    path('api/households/', include('households.urls')),
    path('api/medical/', include('medical_records.urls')),
    # Canonical routes from Chapter 2, retaining /api/medical/ aliases for old clients.
    path('api/medical-records/', include('medical_records.urls')),
    path('api/health-measurements/', include('health_measurements.urls')),
    path('api/ai/', include('ai_services.urls')),
]
