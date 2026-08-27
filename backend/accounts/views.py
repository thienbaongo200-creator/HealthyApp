from django.contrib.auth import authenticate, get_user_model
from django.db import IntegrityError
from django.utils.dateparse import parse_date
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import UserProfile


class RegisterView(APIView):
	permission_classes = [AllowAny]

	def post(self, request):
		username = str(request.data.get('username', '')).strip()
		email = str(request.data.get('email', '')).strip()
		password = request.data.get('password', '')

		if not username or not email or not isinstance(password, str) or len(password) < 6:
			return Response(
				{'detail': 'Username, email and a password of at least 6 characters are required.'},
				status=status.HTTP_400_BAD_REQUEST,
			)

		User = get_user_model()
		if User.objects.filter(username__iexact=username).exists():
			return Response({'detail': 'Username is already in use.'}, status=status.HTTP_400_BAD_REQUEST)
		if User.objects.filter(email__iexact=email).exists():
			return Response({'detail': 'Email is already in use.'}, status=status.HTTP_400_BAD_REQUEST)

		try:
			user = User.objects.create_user(username=username, email=email, password=password)
			UserProfile.objects.create(user=user)
		except IntegrityError:
			return Response({'detail': 'Username or email is already in use.'}, status=status.HTTP_400_BAD_REQUEST)

		return Response(
			{'message': 'Đăng ký thành công.', 'user': {'id': user.pk, 'username': user.username, 'email': user.email}},
			status=status.HTTP_201_CREATED,
		)


class ProfileView(APIView):
	permission_classes = [IsAuthenticated]

	def patch(self, request):
		profile, _ = UserProfile.objects.get_or_create(user=request.user)
		date_of_birth = parse_date(str(request.data.get('date_of_birth', '')))
		if request.data.get('date_of_birth') and date_of_birth is None:
			return Response({'detail': 'date_of_birth must use YYYY-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)

		profile.gender = str(request.data.get('gender', profile.gender)).strip()
		profile.date_of_birth = date_of_birth or profile.date_of_birth
		profile.height = request.data.get('height', profile.height)
		profile.weight = request.data.get('weight', profile.weight)
		profile.save()
		return Response({'message': 'Cập nhật hồ sơ thành công.'}, status=status.HTTP_200_OK)


class LoginView(APIView):
	permission_classes = [AllowAny]

	def post(self, request):
		account = str(
			request.data.get('account', request.data.get('username', ''))
		).strip()
		password = request.data.get('password', '')

		if not account or not isinstance(password, str) or not password:
			return Response(
				{'detail': 'account and password are required.'},
				status=status.HTTP_400_BAD_REQUEST,
			)

		username = account
		User = get_user_model()
		if '@' in account:
			user = User.objects.filter(email__iexact=account).first()
			if user is None:
				return Response(
					{'detail': 'Invalid account or password.'},
					status=status.HTTP_401_UNAUTHORIZED,
				)
			username = user.get_username()

		user = authenticate(request=request, username=username, password=password)
		if user is None:
			return Response(
				{'detail': 'Invalid account or password.'},
				status=status.HTTP_401_UNAUTHORIZED,
			)

		refresh = RefreshToken.for_user(user)
		return Response(
			{
				'access': str(refresh.access_token),
				'refresh': str(refresh),
				'user': {
					'id': user.pk,
					'username': user.get_username(),
					'email': user.email,
				},
			},
			status=status.HTTP_200_OK,
		)
