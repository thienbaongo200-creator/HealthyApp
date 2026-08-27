from django.contrib.auth import get_user_model
from .models import UserProfile
from rest_framework.test import APITestCase


class LoginViewTests(APITestCase):
	def setUp(self):
		self.password = 'Correct password 123!'
		self.user = get_user_model().objects.create_user(
			username='login-test',
			email='login@example.com',
			password=self.password,
		)

	def test_login_accepts_username(self):
		response = self.client.post(
			'/api/auth/login/',
			{'account': self.user.username, 'password': self.password},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_login_accepts_email(self):
		response = self.client.post(
			'/api/auth/login/',
			{'account': self.user.email, 'password': self.password},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_login_rejects_wrong_password(self):
		response = self.client.post(
			'/api/auth/login/',
			{'account': self.user.username, 'password': 'wrong'},
			format='json',
		)

		self.assertEqual(response.status_code, 401)


class AccountIntegrationTests(APITestCase):
	def test_register_hashes_password_and_creates_profile(self):
		response = self.client.post(
			'/api/auth/register/',
			{'username': 'new-user', 'email': 'new@example.com', 'password': 'secret123'},
			format='json',
		)

		self.assertEqual(response.status_code, 201)
		user = get_user_model().objects.get(username='new-user')
		self.assertTrue(user.check_password('secret123'))
		self.assertTrue(UserProfile.objects.filter(user=user).exists())

	def test_profile_update_requires_jwt_and_saves_data(self):
		user = get_user_model().objects.create_user(
			username='profile-user', password='secret123'
		)
		login = self.client.post(
			'/api/auth/login/',
			{'account': user.username, 'password': 'secret123'},
			format='json',
		)
		self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")

		response = self.client.patch(
			'/api/auth/profile/',
			{
				'gender': 'male',
				'date_of_birth': '2000-01-02',
				'height': 175.0,
				'weight': 70.0,
			},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		profile = UserProfile.objects.get(user=user)
		self.assertEqual(profile.gender, 'male')
		self.assertEqual(profile.height, 175.0)
