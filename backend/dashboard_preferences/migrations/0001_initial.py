from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [("profiles", "0003_personprofile_created_by")]
    operations = [migrations.CreateModel(
        name="DashboardPreference",
        fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("selected_metrics", models.JSONField(default=list)),
            ("metric_order", models.JSONField(default=list)),
            ("updated_at", models.DateTimeField(auto_now=True)),
            ("profile", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="dashboard_preference", to="profiles.personprofile")),
        ],
    )]
