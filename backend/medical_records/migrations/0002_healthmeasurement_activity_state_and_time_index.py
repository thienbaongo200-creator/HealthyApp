from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('medical_records', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='healthmeasurement',
            name='activity_state',
            field=models.CharField(
                choices=[('resting', 'Resting'), ('active', 'Active')],
                default='resting',
                max_length=10,
            ),
        ),
        migrations.AddIndex(
            model_name='healthmeasurement',
            index=models.Index(
                fields=['profile', '-measured_at'],
                name='measurement_profile_time_idx',
            ),
        ),
    ]
