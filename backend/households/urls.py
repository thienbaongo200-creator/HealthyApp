from django.urls import path

from .views import (
    HouseholdDetailView,
    HouseholdListCreateView,
    HouseholdMemberDetailView,
    HouseholdMemberListCreateView,
    InvitationListView,
    InvitationResponseView,
)


urlpatterns = [
    path("", HouseholdListCreateView.as_view(), name="household-list"),
    path("<uuid:household_id>/", HouseholdDetailView.as_view(), name="household-detail"),
    path(
        "<uuid:household_id>/members/",
        HouseholdMemberListCreateView.as_view(),
        name="household-member-list",
    ),
    path(
        "<uuid:household_id>/members/<uuid:member_id>/",
        HouseholdMemberDetailView.as_view(),
        name="household-member-detail",
    ),
    path("invitations/", InvitationListView.as_view(), name="invitation-list"),
    path(
        "invitations/<uuid:member_id>/respond/",
        InvitationResponseView.as_view(),
        name="invitation-respond",
    ),
]
