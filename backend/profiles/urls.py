from rest_framework.routers import DefaultRouter

from .views import PersonProfileViewSet


router = DefaultRouter()
router.register("profiles", PersonProfileViewSet, basename="profile")

urlpatterns = router.urls
