import uuid

from django.db import models


class MedicalHistory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="medical_histories",
    )
    condition = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    diagnosed_at = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.condition


class Allergy(models.Model):
    SEVERITY_CHOICES = (
        ("MILD", "Mild"),
        ("MODERATE", "Moderate"),
        ("SEVERE", "Severe"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="allergies",
    )
    allergen = models.CharField(max_length=255)
    reaction = models.TextField(blank=True)
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES, blank=True)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.allergen


class Visit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="visits",
    )
    provider_name = models.CharField(max_length=255, blank=True)
    facility_name = models.CharField(max_length=255, blank=True)
    visited_at = models.DateTimeField()
    reason = models.TextField(blank=True)
    diagnosis = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.profile} - {self.visited_at:%Y-%m-%d}"


class Medication(models.Model):
    STATUS_CHOICES = (
        ("ACTIVE", "Active"),
        ("COMPLETED", "Completed"),
        ("DISCONTINUED", "Discontinued"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="medications",
    )
    visit = models.ForeignKey(
        Visit,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="medications",
    )
    name = models.CharField(max_length=255)
    dosage = models.CharField(max_length=255, blank=True)
    frequency = models.CharField(max_length=255, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    instructions = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="ACTIVE")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class LabResult(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="lab_results",
    )
    visit = models.ForeignKey(
        Visit,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="lab_results",
    )
    test_name = models.CharField(max_length=255)
    result = models.TextField()
    unit = models.CharField(max_length=100, blank=True)
    reference_range = models.CharField(max_length=255, blank=True)
    tested_at = models.DateTimeField()
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.test_name


class MedicalDocument(models.Model):
    DOCUMENT_TYPE_CHOICES = (
        ("PRESCRIPTION", "Prescription"),
        ("LAB_RESULT", "Lab result"),
        ("IMAGING", "Imaging"),
        ("OTHER", "Other"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    profile = models.ForeignKey(
        "profiles.PersonProfile",
        on_delete=models.CASCADE,
        related_name="medical_documents",
    )
    visit = models.ForeignKey(
        Visit,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="documents",
    )
    document_type = models.CharField(
        max_length=20,
        choices=DOCUMENT_TYPE_CHOICES,
        default="OTHER",
    )
    title = models.CharField(max_length=255)
    file_url = models.URLField(max_length=2048)
    description = models.TextField(blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
