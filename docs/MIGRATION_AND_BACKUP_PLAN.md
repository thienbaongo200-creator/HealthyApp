# Sprint 0: Model Mapping and Migration Safety

This document describes the Django model schema currently implemented in
`backend/`. It is an implementation inventory, not proof that every field
matches Data Dictionary tables 2.24-2.40. Any discrepancy with the approved
Data Dictionary must be resolved before production release.

## 1. Model inventory

All application models below use a UUID primary key unless noted otherwise.
Every field is non-null unless explicitly marked nullable. `blank=True` is
listed separately because it affects form/model validation, not database null
semantics. `CASCADE`, `SET_NULL`, and `PROTECT` describe the model's FK delete
behavior.

| App | Model | Foreign keys and delete behavior | Unique constraints / indexes |
| --- | --- | --- | --- |
| `accounts` | `Account` | Django auth relations: `groups`, `user_permissions` | `email` unique and indexed |
| `profiles` | `PersonProfile` | `account` → Account, `SET_NULL`, nullable and blank | None |
| `households` | `Household` | `created_by` → Account, `CASCADE` | None |
| `households` | `HouseholdMember` | `household` → Household, `CASCADE`; `account` → Account, `CASCADE`, nullable and blank; `profile` → PersonProfile, `CASCADE` | Unique `(household, profile)` |
| `households` | `ProfileShare` | `member` → HouseholdMember, `CASCADE`; `profile` → PersonProfile, `CASCADE` | Unique `(member, profile)` |
| `devices` | `Device` | `profile` → PersonProfile, `CASCADE` | `device_identifier` unique |
| `medical_records` | `MedicalHistory` | `profile` → PersonProfile, `CASCADE` | None |
| `medical_records` | `Allergy` | `profile` → PersonProfile, `CASCADE` | None |
| `medical_records` | `Visit` | `profile` → PersonProfile, `CASCADE` | None |
| `medical_records` | `Medication` | `profile` → PersonProfile, `CASCADE`; `visit` → Visit, `SET_NULL`, nullable and blank | None |
| `medical_records` | `LabResult` | `profile` → PersonProfile, `CASCADE`; `visit` → Visit, `SET_NULL`, nullable and blank | None |
| `medical_records` | `MedicalDocument` | `profile` → PersonProfile, `CASCADE`; `visit` → Visit, `SET_NULL`, nullable and blank | None |
| `health_measurements` | `HealthMeasurement` | `profile` → PersonProfile, `CASCADE`; `device` → Device, `SET_NULL`, nullable and blank | Unique `(profile, idempotency_key)`; index `(profile, measurement_type, -measured_at)` |
| `ai_services` | `AIInsight` | `profile` → PersonProfile, `CASCADE` | None |
| `ai_services` | `Conversation` | `account` → Account, `CASCADE`; `profile` → PersonProfile, `CASCADE` | None |
| `ai_services` | `Message` | `conversation` → Conversation, `CASCADE` | Default ordering by `created_at` |

## 2. Implemented fields and choices

Notation: `?` means `null=True`; `blank` is shown independently; `default=...`
is the model default. Auto timestamps use Django `auto_now_add` or `auto_now`.

- `Account`: `id` UUID PK; `password` CharField(128, inherited); `last_login`
  DateTime `?`, blank (inherited); `is_superuser` Boolean (inherited);
  `email` EmailField(254), unique, db_index; `is_active` Boolean,
  `default=True`; `is_staff` Boolean, `default=False`; `ai_consent` Boolean,
  `default=False`; `ai_consent_at` DateTime `?`, blank; `created_at` and
  `updated_at` DateTime auto timestamps; `groups` and `user_permissions`
  ManyToMany, blank (inherited auth relations). There is no `phone_number`.
- `PersonProfile`: `id` UUID PK; `account` FK nullable/blank, `SET_NULL`;
  `profile_type` CharField(20), choices `SELF`/`DEPENDENT`,
  `default=SELF`; `full_name` CharField(255), required; `date_of_birth`
  Date `?`, blank; `gender` CharField(20) `?`, blank, no choices declared;
  `height_cm` and `weight_kg` Decimal(5,2) `?`, blank; `blood_type`
  CharField(10) `?`, blank; `emergency_contact` CharField(255) `?`, blank;
  `is_archived` Boolean, `default=False`; automatic `created_at` and
  `updated_at`.
- `Household`: `id` UUID PK; `name` CharField(255), required; `created_by`
  Account FK, required, `CASCADE`; `created_at` DateTime auto-add.
- `HouseholdMember`: `id` UUID PK; `household` Household FK, required,
  `CASCADE`; `account` Account FK `?`, blank, `CASCADE`; `profile`
  PersonProfile FK, required, `CASCADE`; `role` CharField(20), required,
  choices `OWNER`/`MEMBER`/`CAREGIVER`; `status` CharField(20), choices
  `PENDING`/`ACTIVE`, `default=PENDING`; `invite_expires_at` DateTime `?`,
  blank; automatic `created_at` and `updated_at`. Unique constraint:
  `(household, profile)`. `REJECTED` is not a current choice.
- `ProfileShare`: `id` UUID PK; `member` HouseholdMember FK, required,
  `CASCADE`; `profile` PersonProfile FK, required, `CASCADE`; `share_level`
  CharField(20), required, choices `VIEW_ONLY`/`VIEW_AND_LOG`; automatic
  `created_at` and `updated_at`. Unique constraint: `(member, profile)`.
- `Device`: `id` UUID PK; `profile` PersonProfile FK, required, `CASCADE`;
  `device_identifier` CharField(255), unique, required; `device_name`
  CharField(255) `?`, blank; `status` CharField(20), choices
  `ACTIVE`/`REVOKED`, `default=ACTIVE`; `paired_at` DateTime auto-add;
  `last_synced_at` DateTime `?`, blank; automatic `created_at` and
  `updated_at`. No device-type field/choice is defined.
- `MedicalHistory`: `id` UUID PK; `profile` PersonProfile FK, required,
  `CASCADE`; `condition` CharField(255), required; `description` TextField,
  blank; `diagnosed_at` Date `?`, blank; automatic `created_at` and
  `updated_at`.
- `Allergy`: `id` UUID PK; `profile` PersonProfile FK, required, `CASCADE`;
  `allergen` CharField(255), required; `reaction` TextField, blank;
  `severity` CharField(20), choices `MILD`/`MODERATE`/`SEVERE`, blank but
  not nullable; `notes` TextField, blank; `is_active` Boolean,
  `default=True`; automatic `created_at` and `updated_at`.
- `Visit`: `id` UUID PK; `profile` PersonProfile FK, required, `CASCADE`;
  `provider_name` and `facility_name` CharField(255), blank; `visited_at`
  DateTime, required; `reason`, `diagnosis`, and `notes` TextField, blank;
  automatic `created_at` and `updated_at`.
- `Medication`: `id` UUID PK; `profile` PersonProfile FK, required,
  `CASCADE`; `visit` Visit FK `?`, blank, `SET_NULL`; `name` CharField(255),
  required; `dosage` and `frequency` CharField(255), blank; `start_date` and
  `end_date` Date `?`, blank; `instructions` TextField, blank; `status`
  CharField(20), choices `ACTIVE`/`COMPLETED`/`DISCONTINUED`,
  `default=ACTIVE`; automatic `created_at` and `updated_at`.
- `LabResult`: `id` UUID PK; `profile` PersonProfile FK, required, `CASCADE`;
  `visit` Visit FK `?`, blank, `SET_NULL`; `test_name` CharField(255),
  required; `result` TextField, required; `unit` CharField(100), blank;
  `reference_range` CharField(255), blank; `tested_at` DateTime, required;
  `notes` TextField, blank; automatic `created_at` and `updated_at`.
- `MedicalDocument`: `id` UUID PK; `profile` PersonProfile FK, required,
  `CASCADE`; `visit` Visit FK `?`, blank, `SET_NULL`; `document_type`
  CharField(20), choices `PRESCRIPTION`/`LAB_RESULT`/`IMAGING`/`OTHER`,
  `default=OTHER`; `title` CharField(255), required; `file_url` URLField(2048),
  required; `description` TextField, blank; `uploaded_at` DateTime auto-add.
- `HealthMeasurement`: `id` UUID PK; `profile` PersonProfile FK, required,
  `CASCADE`; `measurement_type` CharField(50), choices `BLOOD_PRESSURE`/
  `HEART_RATE`/`BLOOD_GLUCOSE`/`BMI`/`STEPS`/`CALORIES`, required;
  `value` Decimal(10,2), required; `value_secondary` Decimal(10,2) `?`,
  blank; `unit` CharField(50), required; `measured_at` DateTime, required;
  `start_time` and `end_time` DateTime `?`, blank; `source` CharField(20),
  choices `MANUAL`/`WEAR_OS`, required; `device` Device FK `?`, blank,
  `SET_NULL`; `idempotency_key` CharField(255) `?`, blank; automatic
  `created_at` and `updated_at`. Unique constraint: `(profile,
  idempotency_key)`; index `(profile, measurement_type, -measured_at)`.
- `AIInsight`: `id` UUID PK; `profile` PersonProfile FK, required, `CASCADE`;
  `category` CharField(100), `title` CharField(255), `content` TextField, all
  required; `status` CharField(20), choices `AVAILABLE`/`DISMISSED`,
  `default=AVAILABLE`; `source_data` JSONField, `default=dict`, blank;
  `generated_at` DateTime auto-add.
- `Conversation`: `id` UUID PK; `account` Account FK, required, `CASCADE`;
  `profile` PersonProfile FK, required, `CASCADE`; `title` CharField(255),
  blank; automatic `created_at` and `updated_at`.
- `Message`: `id` UUID PK; `conversation` Conversation FK, required,
  `CASCADE`; `role` CharField(20), choices `USER`/`ASSISTANT`/`SYSTEM`,
  required; `content` TextField, required; `created_at` DateTime auto-add;
  ordering by `created_at`. There is no token-usage field.

## 3. Migration and API rollout

The current API URL configuration exposes auth routes and measurement routes
under `/api/auth/` and `/api/medical/`. Other model groups have no registered
API routes in the current `core.urls`. Do not treat the following rollout
order as evidence that those endpoints exist:

1. Auth and Account
2. Profiles
3. Households and shares
4. Devices
5. Medical records and measurements
6. AI services

Deploy schema changes before clients that depend on them. Keep the API contract
(method, URL, authentication/authorization, payload, response and status
codes) synchronized with routes and tests before enabling each client feature.

## 4. Safe handling of legacy medical data

`medical_records.0001` creates the legacy integer-keyed `PersonProfile` and
`HealthMeasurement` tables. `medical_records.0002` replaces those models with
medical-record models and drops both legacy tables; it also removes the old
profile-to-account FK. The target profile and measurement tables belong to
separate apps and use UUID keys. The old measurement schema also stores
`heart_rate`, `steps`, `calories`, and `activity_state`, whereas the new schema
stores one typed value per row. Therefore, blindly copying IDs or mapping one
old row to one new row is not a safe conversion.

As a fail-safe, `medical_records.0002` first counts rows in both legacy tables
and aborts with an actionable error if either table is non-empty. It must not
be bypassed with `--fake`.

For a populated existing database:

1. Stop writes and take a database backup. Keep the backup immutable and
   restricted because it contains sensitive health data.
2. Restore the backup to an isolated staging database and inventory row counts,
   source fields, FK relationships, and actual measurement-type/value usage.
3. Create and review an explicit old-profile-PK → new-profile-UUID mapping.
   Preserve each account link and dependent profile distinction; do not infer
   an account from names or client-supplied identifiers.
4. Transform legacy measurements using an approved domain mapping. Decide
   explicitly how each legacy scalar and activity field maps to typed
   measurement rows, how `idempotency_key` is assigned, and how unknown or
   invalid values are handled. Reject/report unmappable rows; never silently
   discard them.
5. Import into the target UUID tables in staging. Compare source and target
   counts and value totals by type, verify all FK mappings and idempotency
   constraints, and obtain application-owner approval.
6. On the production database, preserve the verified target import and
   immutable backup; clear legacy rows only after verifying the import. Run
   migrations without `--fake`. The migration guard must confirm both legacy
   tables are empty before their removal.
7. Run `manage.py check`, migration checks, application tests, and targeted
   post-migration integrity queries before resuming writes.

Rollback is a database restore, not a reverse Django migration: restore the
immutable pre-migration backup into a separate database, validate it, then
switch the application back to the prior release/database connection. Rehearse
this procedure in staging and record operator, timestamp, row counts, and
validation results before production rollout. Do not point production at a
partially restored or unverified database.

## 5. Backup and restore rehearsal

Use environment-provided connection settings or the approved PostgreSQL
credential mechanism; do not place passwords in shell history or this
document. Example commands use placeholders and must be tested in staging:

```sh
pg_dump --format=custom --file=healthapp_pre_migration.dump "$SOURCE_DATABASE_URL"
createdb healthapp_restore_rehearsal
pg_restore --exit-on-error --no-owner --dbname=healthapp_restore_rehearsal healthapp_pre_migration.dump
```

Verify restored table names, migration records, and row counts before approving
the backup. Restore into a separate database; never overwrite the source as
part of a rehearsal.
