from accounts.models import Account
from django.db import IntegrityError, transaction
from django.test import TestCase
from profiles.models import PersonProfile
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework.test import APITestCase


class AccountModelTests(TestCase):
    def test_email_must_be_unique_in_database(self):
        Account.objects.create_user(email="unique@example.com", password="safe-password")

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Account.objects.create_user(
                    email="unique@example.com",
                    password="another-safe-password",
                )


class LoginViewTests(APITestCase):
    def setUp(self):
        self.password = "Correct password 123!"
        self.account = Account.objects.create_user(
            email="login@example.com",
            password=self.password,
        )

    def test_login_accepts_email(self):
        response = self.client.post(
            "/api/auth/login/",
            {"email": self.account.email, "password": self.password},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)

    def test_login_rejects_wrong_password(self):
        response = self.client.post(
            "/api/auth/login/",
            {"email": self.account.email, "password": "wrong"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)

    def test_login_rejects_unknown_email(self):
        response = self.client.post(
            "/api/auth/login/",
            {"email": "unknown@example.com", "password": self.password},
            format="json",
        )

        self.assertEqual(response.status_code, 401)


class AccountIntegrationTests(APITestCase):
    def test_register_hashes_password_and_creates_profile(self):
        response = self.client.post(
            "/api/auth/register/",
            {"email": "new@example.com", "password": "secret123"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        account = Account.objects.get(email="new@example.com")
        self.assertTrue(account.check_password("secret123"))
        self.assertTrue(
            PersonProfile.objects.filter(account=account, profile_type="SELF").exists()
        )

    def test_profile_update_requires_jwt_and_saves_data(self):
        account = Account.objects.create_user(
            email="profile@example.com",
            password="secret123",
        )
        login = self.client.post(
            "/api/auth/login/",
            {"email": account.email, "password": "secret123"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

        response = self.client.patch(
            "/api/auth/profile/",
            {
                "gender": "male",
                "date_of_birth": "2000-01-02",
                "height_cm": 175.0,
                "weight_kg": 70.0,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        profile = PersonProfile.objects.get(account=account, profile_type="SELF")
        self.assertEqual(profile.gender, "male")
        self.assertEqual(profile.height_cm, 175.0)


class JWTAuthenticationFlowTests(APITestCase):
    def setUp(self):
        self.password = "A strong test password 123!"
        self.account = Account.objects.create_user(
            email="jwt-flow@example.com",
            password=self.password,
        )

    def _login(self):
        response = self.client.post(
            reverse("login"),
            {"email": self.account.email, "password": self.password},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        return response.data

    def test_login_refresh_rotates_and_blacklists_previous_refresh_token(self):
        tokens = self._login()

        authenticated_response = self.client.get(reverse("profile-list"))
        self.assertEqual(
            authenticated_response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {tokens['access']}",
        )
        authenticated_response = self.client.get(reverse("profile-list"))
        self.assertEqual(
            authenticated_response.status_code,
            status.HTTP_200_OK,
        )

        refresh_response = self.client.post(
            reverse("token_refresh"),
            {"refresh": tokens["refresh"]},
            format="json",
        )
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        self.assertIn("access", refresh_response.data)
        self.assertIn("refresh", refresh_response.data)
        self.assertNotEqual(refresh_response.data["refresh"], tokens["refresh"])

        replay_response = self.client.post(
            reverse("token_refresh"),
            {"refresh": tokens["refresh"]},
            format="json",
        )
        self.assertIn(
            replay_response.status_code,
            [status.HTTP_400_BAD_REQUEST, status.HTTP_401_UNAUTHORIZED],
        )

    def test_logout_revokes_only_the_authenticated_accounts_refresh_token(self):
        tokens = self._login()
        other_account = Account.objects.create_user(
            email="other-jwt-flow@example.com",
            password=self.password,
        )
        other_tokens = self.client.post(
            reverse("login"),
            {"email": other_account.email, "password": self.password},
            format="json",
        ).data

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {tokens['access']}",
        )
        cross_account_logout = self.client.post(
            reverse("logout"),
            {"refresh": other_tokens["refresh"]},
            format="json",
        )
        self.assertEqual(
            cross_account_logout.status_code,
            status.HTTP_403_FORBIDDEN,
        )

        logout_response = self.client.post(
            reverse("logout"),
            {"refresh": tokens["refresh"]},
            format="json",
        )
        self.assertEqual(
            logout_response.status_code,
            status.HTTP_205_RESET_CONTENT,
        )

        refresh_after_logout = self.client.post(
            reverse("token_refresh"),
            {"refresh": tokens["refresh"]},
            format="json",
        )
        self.assertIn(
            refresh_after_logout.status_code,
            [status.HTTP_400_BAD_REQUEST, status.HTTP_401_UNAUTHORIZED],
        )
