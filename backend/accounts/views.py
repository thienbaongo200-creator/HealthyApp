from django.contrib.auth import authenticate, get_user_model
from django.db import IntegrityError
from django.utils.dateparse import parse_date
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from profiles.models import PersonProfile


def get_or_create_self_profile(account):
    return PersonProfile.objects.get_or_create(
        account=account,
        profile_type="SELF",
        defaults={"full_name": account.email.partition("@")[0]},
    )


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = str(request.data.get("email", "")).strip()
        password = request.data.get("password", "")

        if not email or "@" not in email or not isinstance(password, str) or len(password) < 6:
            return Response(
                {"detail": "A valid email and a password of at least 6 characters are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        Account = get_user_model()
        if Account.objects.filter(email__iexact=email).exists():
            return Response(
                {"detail": "Email is already in use."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            account = Account.objects.create_user(email=email, password=password)
            get_or_create_self_profile(account)
        except IntegrityError:
            return Response(
                {"detail": "Email is already in use."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                "message": "Đăng ký thành công.",
                "user": {"id": account.pk, "email": account.email},
            },
            status=status.HTTP_201_CREATED,
        )


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request):
        profile, _ = get_or_create_self_profile(request.user)
        date_of_birth = parse_date(str(request.data.get("date_of_birth", "")))
        if request.data.get("date_of_birth") and date_of_birth is None:
            return Response(
                {"detail": "date_of_birth must use YYYY-MM-DD."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.gender = str(request.data.get("gender", profile.gender)).strip()
        profile.date_of_birth = date_of_birth or profile.date_of_birth
        profile.height_cm = request.data.get(
            "height_cm",
            request.data.get("height", profile.height_cm),
        )
        profile.weight_kg = request.data.get(
            "weight_kg",
            request.data.get("weight", profile.weight_kg),
        )
        profile.save()
        return Response(
            {"message": "Cập nhật hồ sơ thành công."},
            status=status.HTTP_200_OK,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = str(request.data.get("email", request.data.get("account", ""))).strip()
        password = request.data.get("password", "")

        if not email or not isinstance(password, str) or not password:
            return Response(
                {"detail": "email and password are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        account = authenticate(
            request=request,
            email=email,
            password=password,
        )
        if account is None:
            return Response(
                {"detail": "Invalid email or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        refresh = RefreshToken.for_user(account)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {"id": account.pk, "email": account.email},
            },
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if not refresh_token:
                return Response(
                    {"error": "Refresh token is required"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(
                {"message": "Successfully logged out"},
                status=status.HTTP_205_RESET_CONTENT,
            )
        except Exception as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )
