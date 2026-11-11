import secrets
import logging
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import serializers, status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from profiles.models import PersonProfile
from ai_services.services.consent import AIConsentService
from .models import PasswordResetCode

logger = logging.getLogger(__name__)


def get_or_create_self_profile(account):
    return PersonProfile.objects.get_or_create(
        account=account,
        profile_type="SELF",
        defaults={
            "full_name": account.email.partition("@")[0],
            "created_by": account,
        },
    )


def is_profile_complete(profile):
    gender = (profile.gender or "").strip()
    return bool(
        gender
        and profile.date_of_birth
        and profile.date_of_birth <= timezone.localdate()
        and profile.height_cm
        and profile.height_cm > 0
        and profile.weight_kg
        and profile.weight_kg > 0
    )


class RegisterView(APIView):
    authentication_classes = []
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
        if request.data.get("password_confirm") != password:
            return Response(
                {"password_confirm": ["Mật khẩu xác nhận không khớp."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_password(password, user=Account(email=email))
        except DjangoValidationError as error:
            return Response(
                {"password": error.messages},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if Account.objects.filter(email__iexact=email).exists():
            return Response(
                {"detail": "Email is already in use."},
                status=status.HTTP_409_CONFLICT,
            )

        try:
            account = Account.objects.create_user(email=email, password=password)
            get_or_create_self_profile(account)
        except IntegrityError:
            return Response(
                {"detail": "Email is already in use."},
                status=status.HTTP_409_CONFLICT,
            )

        return Response(
            {
                "message": "Đăng ký thành công.",
                "user": {
                    "id": account.pk,
                    "email": account.email,
                    "is_profile_completed": False,
                },
                "is_profile_completed": False,
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
        height_cm = request.data.get(
            "height_cm",
            request.data.get("height", profile.height_cm),
        )
        try:
            profile.height_cm = serializers.DecimalField(
                max_digits=5,
                decimal_places=2,
                min_value=30,
                max_value=300,
                allow_null=True,
            ).run_validation(height_cm)
        except serializers.ValidationError as error:
            return Response({"height_cm": error.detail}, status=status.HTTP_400_BAD_REQUEST)
        profile.weight_kg = request.data.get(
            "weight_kg",
            request.data.get("weight", profile.weight_kg),
        )
        profile.save()
        return Response(
            {
                "message": "Cập nhật hồ sơ thành công.",
                "is_profile_completed": is_profile_complete(profile),
                "profile": {
                    "id": str(profile.pk),
                    "gender": profile.gender,
                    "date_of_birth": (
                        profile.date_of_birth.isoformat()
                        if profile.date_of_birth
                        else None
                    ),
                    "height_cm": profile.height_cm,
                    "weight_kg": profile.weight_kg,
                },
            },
            status=status.HTTP_200_OK,
        )


class AiConsentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile, _ = get_or_create_self_profile(request.user)
        return Response(
            {
                "ai_consent": AIConsentService.has_consent(profile),
            },
            status=status.HTTP_200_OK,
        )

    def patch(self, request):
        consent = request.data.get("ai_consent")
        if not isinstance(consent, bool):
            return Response(
                {"ai_consent": ["Must be a boolean."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile, _ = get_or_create_self_profile(request.user)
        AIConsentService.set_consent(
            user=request.user,
            profile=profile,
            granted=consent,
            version=str(request.data.get("consent_version") or "1.0"),
        )
        consent_record_exists = AIConsentService.has_consent(profile)
        return Response(
            {
                "ai_consent": consent_record_exists,
            },
            status=status.HTTP_200_OK,
        )


class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

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

        profile, _ = get_or_create_self_profile(account)
        profile_completed = is_profile_complete(profile)
        refresh = RefreshToken.for_user(account)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": account.pk,
                    "email": account.email,
                    "is_profile_completed": profile_completed,
                },
                "is_profile_completed": profile_completed,
            },
            status=status.HTTP_200_OK,
        )


class ForgotPasswordView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "forgot_password"

    def post(self, request):
        email = str(request.data.get("email", "")).strip()
        if not email or "@" not in email:
            return Response({"email": ["Enter a valid email address."]}, status=400)
        account = get_user_model().objects.filter(email__iexact=email, is_active=True).first()
        if account:
            code = f"{secrets.randbelow(1_000_000):06d}"
            PasswordResetCode.objects.filter(account=account).delete()
            reset = PasswordResetCode.objects.create(
                account=account,
                code_hash=make_password(code),
                expires_at=timezone.now() + timedelta(minutes=15),
            )
            try:
                sent = send_mail(
                    "HealthyApp password reset code",
                    f"Your password reset code is {code}. It expires in 15 minutes.",
                    settings.DEFAULT_FROM_EMAIL,
                    [account.email],
                    fail_silently=False,
                )
                if not sent:
                    reset.delete()
            except Exception:
                logger.exception("Failed to send a password reset code")
                reset.delete()
                # Keep the response indistinguishable from an unknown email.
                return Response({"detail": "If an account exists for this email, a reset code has been sent."})
        return Response({"detail": "If an account exists for this email, a reset code has been sent."})


class ResetPasswordView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "reset_password"

    def post(self, request):
        email = str(request.data.get("email", "")).strip()
        code = str(request.data.get("otp", "")).strip()
        new_password = request.data.get("new_password", "")
        if not email or not code or not isinstance(new_password, str):
            return Response({"detail": "email, otp and new_password are required."}, status=400)
        if len(code) != 6 or not code.isdigit():
            return Response({"detail": "Reset code is invalid or expired."}, status=400)
        with transaction.atomic():
            account = get_user_model().objects.select_for_update().filter(
                email__iexact=email, is_active=True
            ).first()
            reset = (
                PasswordResetCode.objects.select_for_update()
                .filter(account=account)
                .order_by("-created_at")
                .first()
                if account
                else None
            )
            if reset is None or reset.expires_at <= timezone.now() or reset.attempts >= 5:
                return Response({"detail": "Reset code is invalid or expired."}, status=400)
            if not check_password(code, reset.code_hash):
                reset.attempts += 1
                reset.save(update_fields=["attempts"])
                return Response({"detail": "Reset code is invalid or expired."}, status=400)
            try:
                validate_password(new_password, user=account)
            except DjangoValidationError as error:
                return Response({"new_password": error.messages}, status=400)
            account.set_password(new_password)
            account.save(update_fields=["password"])
            PasswordResetCode.objects.filter(account=account).delete()
        return Response({"detail": "Password has been reset successfully."})


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return Response(
                {"detail": "Refresh token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            token = RefreshToken(refresh_token)
        except (TokenError, AuthenticationFailed):
            return Response(
                {"detail": "Refresh token is invalid or revoked."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        token_user_id = token.get(api_settings.USER_ID_CLAIM)
        if str(token_user_id) != str(request.user.pk):
            raise PermissionDenied(
                "You can only revoke a refresh token belonging to your account."
            )

        try:
            token.blacklist()
            return Response(
                {"message": "Successfully logged out"},
                status=status.HTTP_205_RESET_CONTENT,
            )
        except AttributeError as error:
            raise RuntimeError(
                "Refresh token blacklisting is not installed or enabled."
            ) from error
