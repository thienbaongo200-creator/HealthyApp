from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("ai_services", "0001_initial")]

    operations = [
        migrations.AddField(
            model_name="message",
            name="provider",
            field=models.CharField(default="local", max_length=50),
        ),
        migrations.AddField(
            model_name="message",
            name="model_version",
            field=models.CharField(blank=True, default="", max_length=100),
        ),
    ]
