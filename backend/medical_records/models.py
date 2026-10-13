from django.conf import settings
from django.db import connections, models
from django.db.models.signals import post_save
from django.dispatch import receiver


class PersonProfile(models.Model):
    # Khai báo khóa ngoại trỏ tới AUTH_USER_MODEL thay vì import trực tiếp
    account = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='person_profiles'
    )
    profile_type = models.CharField(max_length=20, default='SELF') # SELF hoặc DEPENDENT
    full_name = models.CharField(max_length=255, blank=True)
    gender = models.CharField(max_length=20, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    height_cm = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        identifier = self.account.email if self.account else "No Account"
        return f"Profile: {self.full_name or 'Unnamed'} ({identifier})"


class HealthMeasurement(models.Model):
    ACTIVITY_STATE_CHOICES = [
        ('resting', 'Resting'),
        ('active', 'Active'),
    ]

    profile = models.ForeignKey(PersonProfile, on_delete=models.CASCADE, related_name='measurements')
    measurement_type = models.CharField(max_length=50, default='heart_rate')
    value = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    value_secondary = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    unit = models.CharField(max_length=20, blank=True)
    measured_at = models.DateTimeField()
    start_time = models.DateTimeField(null=True, blank=True)
    end_time = models.DateTimeField(null=True, blank=True)
    source = models.CharField(max_length=50, default='manual')
    idempotency_key = models.UUIDField(null=True, blank=True)
    
    # Giữ lại các trường tương thích phiên bản cũ nếu cần
    heart_rate = models.PositiveIntegerField(null=True, blank=True)
    steps = models.PositiveIntegerField(default=0)
    calories = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    activity_state = models.CharField(
        max_length=10,
        choices=ACTIVITY_STATE_CHOICES,
        default='resting',
    )
    
    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'idempotency_key'],
                name='unique_profile_measurement_key',
            ),
        ]
        indexes = [
            models.Index(
                fields=['profile', '-measured_at'],
                name='measurement_profile_time_idx',
            ),
        ]

    def __str__(self):
        email_str = self.profile.account.email if self.profile and self.profile.account else "Unlinked"
        return f"{email_str} - {self.measured_at}"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, raw=False, using=None, **kwargs):
    if not created or raw:
        return

    database = using or instance._state.db
    if database is None:
        raise RuntimeError("Cannot create a profile for an account without a database.")

    connection = connections[database]
    table_name = PersonProfile._meta.db_table
    account_column = PersonProfile._meta.get_field('account').column

    with connection.cursor() as cursor:
        tables = connection.introspection.table_names(cursor)
        if table_name not in tables:
            raise RuntimeError(
                f"Cannot create an account profile: table {table_name!r} "
                f"does not exist in database {database!r}. Run migrations first."
            )
        columns = {
            column.name
            for column in connection.introspection.get_table_description(cursor, table_name)
        }
        if account_column not in columns:
            raise RuntimeError(
                f"Cannot create an account profile: column "
                f"{table_name}.{account_column} does not exist in database "
                f"{database!r}. Check and apply migrations first."
            )

    PersonProfile.objects.using(database).get_or_create(
        account_id=instance.pk,
        profile_type='SELF',
        defaults={'full_name': instance.email.partition('@')[0]},
    )