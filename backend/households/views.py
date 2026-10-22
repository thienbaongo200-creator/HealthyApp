from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from profiles.models import PersonProfile

from .models import Household, HouseholdMember, ProfileShare
from .serializers import (
    HouseholdInviteSerializer,
    HouseholdMemberSerializer,
    HouseholdMemberUpdateSerializer,
    HouseholdSerializer,
    InvitationResponseSerializer,
)


def _get_or_create_self_profile(account):
    profile, _ = PersonProfile.objects.get_or_create(
        account=account,
        profile_type="SELF",
        defaults={
            "full_name": account.email.partition("@")[0],
            "created_by": account,
        },
    )
    return profile


def _get_household_owner_membership(household, user):
    return HouseholdMember.objects.filter(
        household=household,
        account=user,
        role="OWNER",
        status="ACTIVE",
    ).first()


class HouseholdListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        households = Household.objects.filter(
            members__status="ACTIVE",
        ).filter(
            Q(members__account=request.user)
            | Q(members__profile__account=request.user)
            | Q(members__profile__created_by=request.user)
        ).distinct()
        return Response(
            HouseholdSerializer(
                households,
                many=True,
                context={"request": request},
            ).data
        )

    def post(self, request):
        serializer = HouseholdSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = _get_or_create_self_profile(request.user)
        with transaction.atomic():
            household = Household.objects.create(
                name=serializer.validated_data["name"],
                created_by=request.user,
            )
            HouseholdMember.objects.create(
                household=household,
                account=request.user,
                profile=profile,
                role="OWNER",
                status="ACTIVE",
            )
        return Response(
            HouseholdSerializer(household).data,
            status=status.HTTP_201_CREATED,
        )


class HouseholdDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, household_id):
        household = get_object_or_404(
            Household.objects.filter(
                members__status="ACTIVE",
            )
            .filter(
                Q(members__account=request.user)
                | Q(members__profile__account=request.user)
                | Q(members__profile__created_by=request.user)
            )
            .distinct(),
            pk=household_id,
        )
        return Response(
            HouseholdSerializer(household, context={"request": request}).data
        )


class HouseholdLeaveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, household_id):
        memberships = HouseholdMember.objects.filter(
            household_id=household_id,
            status="ACTIVE",
        ).filter(
            Q(account=request.user)
            | Q(profile__account=request.user)
            | Q(profile__created_by=request.user)
        )
        if not memberships.exists():
            return Response(
                {"detail": "Active household membership was not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if memberships.filter(role="OWNER").exists():
            raise PermissionDenied(
                "Household owners must transfer ownership before leaving."
            )

        memberships.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HouseholdMemberListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_owned_household(self, household_id, user):
        household = get_object_or_404(Household, pk=household_id)
        if not _get_household_owner_membership(household, user):
            raise PermissionDenied("Only an active household owner can manage members.")
        return household

    def get(self, request, household_id):
        household = self._get_owned_household(household_id, request.user)
        members = household.members.select_related("account", "profile").all()
        return Response(HouseholdMemberSerializer(members, many=True).data)

    def post(self, request, household_id):
        household = self._get_owned_household(household_id, request.user)
        serializer = HouseholdInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        invite_data = serializer.validated_data

        User = get_user_model()
        invited_account = User.objects.filter(
            email__iexact=invite_data["email"],
        ).first()
        if invited_account is None:
            return Response(
                {"detail": "An account with this email does not exist."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if invited_account.pk == request.user.pk:
            return Response(
                {"detail": "You cannot invite yourself."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invited_profile = _get_or_create_self_profile(invited_account)
        if HouseholdMember.objects.filter(
            household=household,
            profile=invited_profile,
        ).exists():
            return Response(
                {"detail": "This account already has a household membership."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        share_profile_id = invite_data.get("share_profile_id")
        if share_profile_id is None:
            share_profile = _get_or_create_self_profile(request.user)
        else:
            share_profile = get_object_or_404(
                PersonProfile,
                pk=share_profile_id,
                is_archived=False,
            )
            if not HouseholdMember.objects.filter(
                household=household,
                account=request.user,
                role="OWNER",
                status="ACTIVE",
                profile=share_profile,
            ).exists() and share_profile.account_id != request.user.pk:
                raise PermissionDenied("You can only share a profile you manage.")

        try:
            with transaction.atomic():
                member = HouseholdMember.objects.create(
                    household=household,
                    account=invited_account,
                    profile=invited_profile,
                    role=invite_data["role"],
                    status="PENDING",
                    invite_expires_at=timezone.now() + timedelta(days=7),
                )
                ProfileShare.objects.update_or_create(
                    member=member,
                    profile=share_profile,
                    defaults={"share_level": invite_data["share_level"]},
                )
        except IntegrityError:
            return Response(
                {"detail": "This account already has a household membership."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            HouseholdMemberSerializer(member).data,
            status=status.HTTP_201_CREATED,
        )


class HouseholdMemberDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_owner_and_member(self, household_id, member_id, user):
        household = get_object_or_404(Household, pk=household_id)
        if not _get_household_owner_membership(household, user):
            raise PermissionDenied("Only an active household owner can manage members.")
        member = get_object_or_404(
            HouseholdMember.objects.select_related("profile"),
            household=household,
            pk=member_id,
        )
        return household, member

    def patch(self, request, household_id, member_id):
        household, member = self._get_owner_and_member(
            household_id,
            member_id,
            request.user,
        )
        if member.role == "OWNER":
            return Response(
                {"detail": "Household owner roles cannot be changed here."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = HouseholdMemberUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if "role" in data:
            member.role = data["role"]
            member.save(update_fields=["role", "updated_at"])

        if "share_level" in data:
            share_profile_id = data.get("share_profile_id")
            if share_profile_id is None:
                share_profile = _get_or_create_self_profile(request.user)
            else:
                share_profile = get_object_or_404(
                    PersonProfile,
                    pk=share_profile_id,
                    is_archived=False,
                )
                if not HouseholdMember.objects.filter(
                    household=household,
                    account=request.user,
                    role="OWNER",
                    status="ACTIVE",
                    profile=share_profile,
                ).exists() and share_profile.account_id != request.user.pk:
                    raise PermissionDenied("You can only share a profile you manage.")
            ProfileShare.objects.update_or_create(
                member=member,
                profile=share_profile,
                defaults={"share_level": data["share_level"]},
            )

        return Response(HouseholdMemberSerializer(member).data)

    def delete(self, request, household_id, member_id):
        _, member = self._get_owner_and_member(
            household_id,
            member_id,
            request.user,
        )
        if member.role == "OWNER":
            return Response(
                {"detail": "The household owner cannot be removed."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        member.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class InvitationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        invitations = HouseholdMember.objects.filter(
            account=request.user,
            status="PENDING",
        ).select_related("household", "profile")
        return Response(
            [
                {
                    **HouseholdMemberSerializer(invitation).data,
                    "household_name": invitation.household.name,
                }
                for invitation in invitations
            ]
        )


class InvitationResponseView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, member_id):
        serializer = InvitationResponseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        invitation = get_object_or_404(
            HouseholdMember.objects.select_related("account"),
            pk=member_id,
            account=request.user,
            status="PENDING",
        )
        if (
            invitation.invite_expires_at
            and invitation.invite_expires_at <= timezone.now()
        ):
            invitation.delete()
            return Response(
                {"detail": "This invitation has expired."},
                status=status.HTTP_410_GONE,
            )

        if serializer.validated_data["action"] == "decline":
            invitation.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        invitation.status = "ACTIVE"
        invitation.save(update_fields=["status", "updated_at"])
        return Response(HouseholdMemberSerializer(invitation).data)
