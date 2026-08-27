from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
	user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
	gender = models.CharField(max_length=10, blank=True)
	date_of_birth = models.DateField(null=True, blank=True)
	height = models.FloatField(null=True, blank=True)
	weight = models.FloatField(null=True, blank=True)

	def __str__(self):
		return f'Profile for {self.user.username}'
