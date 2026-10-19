from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def backfill_created_by(apps, schema_editor):
    PersonProfile = apps.get_model("profiles", "PersonProfile")
    PersonProfile.objects.filter(created_by__isnull=True, account__isnull=False).update(
        created_by=models.F("account")
    )


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("profiles", "0002_personprofile_relation_type"),
    ]

    operations = [
        migrations.AddField(
            model_name="personprofile",
            name="created_by",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="created_profiles",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.RunPython(backfill_created_by, migrations.RunPython.noop),
    ]
