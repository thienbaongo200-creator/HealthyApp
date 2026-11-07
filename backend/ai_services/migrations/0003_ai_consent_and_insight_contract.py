import django.utils.timezone
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid


def migrate_insights(apps, schema_editor):
    AIInsight = apps.get_model("ai_services", "AIInsight")
    for insight in AIInsight.objects.all().iterator():
        AIInsight.objects.filter(pk=insight.pk).update(
            period_start=insight.generated_at,
            period_end=insight.generated_at,
            summary=insight.content,
            created_at=insight.generated_at,
        )


def reverse_insights(apps, schema_editor):
    AIInsight = apps.get_model("ai_services", "AIInsight")
    for insight in AIInsight.objects.all().iterator():
        AIInsight.objects.filter(pk=insight.pk).update(
            content=insight.summary,
            generated_at=insight.created_at,
        )


def migrate_account_consent(apps, schema_editor):
    Account = apps.get_model("accounts", "Account")
    PersonProfile = apps.get_model("profiles", "PersonProfile")
    AIConsent = apps.get_model("ai_services", "AIConsent")
    for account in Account.objects.filter(ai_consent=True).iterator():
        profile = PersonProfile.objects.filter(
            account_id=account.pk, profile_type="SELF", is_archived=False
        ).first()
        if profile:
            AIConsent.objects.update_or_create(
                profile_id=profile.pk,
                defaults={
                    "granted_by_account_id": account.pk,
                    "status": "GRANTED",
                    "consent_version": "legacy-migrated",
                    "granted_at": account.ai_consent_at or django.utils.timezone.now(),
                },
            )


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_passwordresetcode"),
        ("profiles", "0003_personprofile_created_by"),
        ("ai_services", "0002_message_provider_metadata"),
    ]

    operations = [
        migrations.CreateModel(
            name="AIConsent",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("status", models.CharField(choices=[("GRANTED", "Granted"), ("REVOKED", "Revoked")], max_length=10)),
                ("consent_version", models.CharField(max_length=50)),
                ("granted_at", models.DateTimeField(blank=True, null=True)),
                ("revoked_at", models.DateTimeField(blank=True, null=True)),
                ("profile", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="ai_consent_record", to="profiles.personprofile")),
                ("granted_by_account", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="granted_ai_consents", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddField("aiinsight", "period_start", models.DateTimeField(default=django.utils.timezone.now)),
        migrations.AddField("aiinsight", "period_end", models.DateTimeField(default=django.utils.timezone.now)),
        migrations.AddField("aiinsight", "risk_level", models.CharField(choices=[("LOW", "Low"), ("MEDIUM", "Medium"), ("HIGH", "High")], default="LOW", max_length=10)),
        migrations.AddField("aiinsight", "triggered_rules", models.JSONField(blank=True, default=list)),
        migrations.AddField("aiinsight", "summary", models.TextField(default="")),
        migrations.AddField("aiinsight", "recommendation", models.TextField(default="")),
        migrations.AddField("aiinsight", "generated_by", models.CharField(choices=[("RULE_ONLY", "Rule engine only"), ("RULE_AND_AI", "Rule engine and AI provider")], default="RULE_ONLY", max_length=20)),
        migrations.AddField("aiinsight", "created_at", models.DateTimeField(blank=True, null=True)),
        migrations.RunPython(migrate_insights, reverse_insights),
        migrations.RunPython(migrate_account_consent, migrations.RunPython.noop),
        migrations.RemoveField("aiinsight", "category"),
        migrations.RemoveField("aiinsight", "title"),
        migrations.RemoveField("aiinsight", "content"),
        migrations.RemoveField("aiinsight", "status"),
        migrations.RemoveField("aiinsight", "source_data"),
        migrations.RemoveField("aiinsight", "generated_at"),
        migrations.AlterField("aiinsight", "created_at", models.DateTimeField(auto_now_add=True)),
        migrations.AlterField("aiinsight", "period_start", models.DateTimeField()),
        migrations.AlterField("aiinsight", "period_end", models.DateTimeField()),
        migrations.AlterField("aiinsight", "risk_level", models.CharField(choices=[("LOW", "Low"), ("MEDIUM", "Medium"), ("HIGH", "High")], max_length=10)),
        migrations.AlterField("aiinsight", "summary", models.TextField()),
        migrations.AlterField("aiinsight", "recommendation", models.TextField()),
        migrations.AlterField("aiinsight", "generated_by", models.CharField(choices=[("RULE_ONLY", "Rule engine only"), ("RULE_AND_AI", "Rule engine and AI provider")], max_length=20)),
    ]
