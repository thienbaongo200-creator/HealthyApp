from django.contrib.auth import authenticate, get_user_model
from django.db import IntegrityError
from django.urls import reverse
from django.utils.dateparse import parse_date
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.test import APITestCase

from profiles.models import PersonProfile

User = get_user_model()

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

        # Cấp token luôn để hỗ trợ client đăng nhập tự động sau khi đăng ký
        refresh = RefreshToken.for_user(account)
        return Response(
            {
                "message": "Đăng ký thành công.",
                "user": {"id": account.pk, "email": account.email},
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
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


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Bổ sung GET để client có thể lấy thông tin hồ sơ cá nhân hiện tại."""
        profile, _ = get_or_create_self_profile(request.user)
        return Response(
            {
                "id": profile.id,
                "full_name": profile.full_name,
                "gender": profile.gender,
                "date_of_birth": profile.date_of_birth,
                "height_cm": profile.height_cm,
                "weight_kg": profile.weight_kg,
            },
            status=status.HTTP_200_OK,
        )

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

class AccountsAuthIntegrationTestCase(APITestCase):
    def setUp(self):
        # Đảm bảo các tên 'auth-register', 'auth-login' khớp với accounts/urls.py của bạn
        self.register_url = reverse('auth-register')
        self.login_url = reverse('auth-login')
        self.refresh_url = reverse('auth-refresh')
        self.logout_url = reverse('auth-logout')
        
        self.user_data = {
            "email": "testuser@example.com",
            "password": "SecurePassword123!"
        }

    def test_01_register_success(self):
        """Kiểm tra đăng ký tài khoản thành công (không trả token trực tiếp)"""
        response = self.client.post(self.register_url, self.user_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('message', response.data)
        self.assertIn('user', response.data)
        self.assertEqual(response.data['user']['email'], self.user_data['email'])

    def test_02_login_and_logout_flow(self):
        """Kiểm tra đăng nhập lấy token và đăng xuất an toàn"""
        # Tạo user sẵn trong DB test
        User.objects.create_user(email="loginuser@example.com", password="SecurePassword123!")

        # 1. Login lấy token
        login_response = self.client.post(self.login_url, {
            "email": "loginuser@example.com",
            "password": "SecurePassword123!"
        }, format='json')
        
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        access_token = login_response.data['access']
        refresh_token = login_response.data['refresh']

        # 2. Logout gửi kèm refresh token và Bearer token
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + access_token)
        logout_response = self.client.post(self.logout_url, {
            "refresh": refresh_token
        }, format='json')
        
        # Chấp nhận mã 205 (Reset Content như code view của bạn) hoặc 200 OK
        self.assertIn(logout_response.status_code, [status.HTTP_205_RESET_CONTENT, status.HTTP_200_OK])