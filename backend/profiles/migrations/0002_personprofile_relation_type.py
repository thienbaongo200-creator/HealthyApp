from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("profiles", "0001_initial")]

    operations = [
        migrations.AddField(
            model_name="personprofile",
            name="relation_type",
            field=models.CharField(
                blank=True,
                choices=[
                    ("FATHER", "Father"),
                    ("MOTHER", "Mother"),
                    ("SPOUSE", "Spouse"),
                    ("CHILD", "Child"),
                    ("SIBLING", "Sibling"),
                    ("OTHER", "Other"),
                ],
                max_length=20,
                null=True,
            ),
        ),
    ]
