from django.apps import AppConfig

class MedicalRecordsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'medical_records'

    def ready(self):
        import medical_records.models # Import models để kích hoạt các signal 
