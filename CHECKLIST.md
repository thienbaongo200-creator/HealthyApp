# HealthyApp — Checklist hành động theo Sprint

> Lộ trình này được lập để đưa prototype hiện tại khớp dần với `docs/Chuong2_HoanChinh.docx` (Chương 2). Sprint được sắp theo phụ thuộc kỹ thuật: **hợp đồng dữ liệu → CSDL/model → logic bảo mật/nghiệp vụ → API → đồng bộ/AI → Flutter → nghiệm thu**. Chỉ đánh dấu `[x]` khi có mã nguồn và bằng chứng kiểm thử tương ứng; UI hoặc endpoint giả lập không được tính là hoàn thành nghiệp vụ.
>
> Trạng thái kiểm tra kỹ thuật thực tế: Backend đã có 16 models theo Data Dictionary, kiểm tra quyền cơ bản qua `PermissionService` (RBAC & chống IDOR) và unique constraint chống trùng lặp dữ liệu đo lường. Tuy nhiên, các CRUD y bạ (Visit, Allergy, Medication,...), Device API, Redis Blacklist (BR01), Redis Idempotency Lock (BR07/BR08), kiểm tra `ai_consent` cho hồ sơ giám hộ/DEPENDENT (BR10) và tích hợp AI Provider kèm Fallback (BR12) chưa hoàn thiện hoặc chưa có mã nguồn triển khai.
>
> - `[ ]` Chưa thực hiện (Không tìm thấy code triển khai)
> - `[~]` Đã có một phần, cần sửa/bổ sung/kiểm thử (Mã nguồn mới viết khung, thiếu logic bảo mật hoặc chưa hoàn thiện theo Chương 2)
> - `[x]` Đạt DoD và có test/bằng chứng (Đã triển khai hoàn chỉnh logic, đúng chuẩn thiết kế kỹ thuật)

## Quy tắc quản lý tiến độ

- [x] Chốt tài liệu Chương 2 làm chuẩn; nếu cần thay đổi schema hoặc API thì cập nhật tài liệu/hợp đồng trước khi code.
- [x] Tạo nhánh/PR riêng cho từng Sprint; mỗi PR gồm migration, test và ghi chú thay đổi API liên quan.
- [~] Không bắt đầu Flutter tích hợp một endpoint trước khi schema, quyền truy cập, response schema và test API của endpoint đó đã ổn định (Một số màn hình Flutter vẫn dùng mock store hoặc gọi endpoint chưa hoàn thiện).
- [x] Không sửa/xóa migration đã áp dụng lên môi trường dùng chung; tạo migration mới và kiểm thử đường nâng cấp dữ liệu (`LegacyMigrationGuardTests`).
- [x] Dùng dữ liệu kiểm thử giả lập; không đưa dữ liệu sức khỏe thật hoặc secret vào log, fixture công khai hay repository.

---

## Sprint 0 — Chốt hợp đồng và đường di trú

**Mục tiêu:** loại bỏ mơ hồ giữa Chương 2, backend đang chạy và frontend; chuẩn bị đường nâng cấp an toàn trước khi thay model.

### Công việc

- [x] Lập bảng ánh xạ 16 thực thể, trường, PK/FK, UNIQUE, index và enum từ Data Dictionary (Bảng 2.24–2.40).
- [~] Chốt quy ước endpoint, tiền tố `/api`, dấu `/` cuối URL, request/response, phân trang và mã lỗi (Một số endpoint như `/api/devices/` đang bị comment trong `core/urls.py`, endpoint measurements đang nằm trong `medical_records/urls.py` thay vì `health_measurements/urls.py`).
- [x] Kiểm kê dữ liệu đang lưu trong `PersonProfile`, `HealthMeasurement` và app cũ `health_metrics`; xác định ánh xạ dữ liệu sang schema đích.
- [x] Viết kế hoạch migration theo giai đoạn cho PK UUID và quan hệ hiện có; xác định backup/rollback trước khi migrate dữ liệu (`medical_records/tests.py:LegacyMigrationGuardTests`).
- [~] Xác định thứ tự phát hành migration và phiên bản API để tránh frontend/backend lệch hợp đồng (Client hiện có 2 file `ApiClient` khác nhau với cấu hình IP và đường dẫn endpoint chưa đồng nhất).

### Definition of Done

- [x] Có danh sách 16 bảng và mapping trường được đối chiếu trực tiếp với Data Dictionary.
- [~] Mọi endpoint chính có method, quyền, schema đầu vào/đầu ra và status code thống nhất (Vẫn còn endpoint chưa đồng bộ giữa `medical_records` và `health_measurements`).
- [x] Có phương án bảo toàn dữ liệu cũ, backup và rollback; không thay PK trực tiếp mà chưa có kế hoạch migrate.

---

## Sprint 1 — CSDL và 16 Django models

**Mục tiêu:** hoàn tất nền tảng dữ liệu trước khi triển khai API phụ thuộc.

### Công việc

- [x] Quản lý `Account`: custom user model với UUID PK, email unique index tại `backend/accounts/models.py`.
- [x] Chuyển `PersonProfile` từ quan hệ One-to-One bắt buộc sang quan hệ Account 1—0..* PersonProfile; hỗ trợ hồ sơ DEPENDENT chưa gắn tài khoản (`backend/profiles/models.py`).
- [x] Khai báo UUID PK cho các thực thể theo tài liệu và migration dữ liệu có kiểm soát.
- [x] Hoàn thiện `PersonProfile`: `profile_type`, `full_name`, ngày sinh, giới tính, chiều cao, cân nặng, nhóm máu, liên hệ khẩn cấp, `is_archived`, `created_at`, `updated_at`.
- [x] Tạo model `Household`, `HouseholdMember`, `ProfileShare` với đầy đủ `UniqueConstraint` và quan hệ khóa ngoại.
- [x] Tạo model `Device`; đặt `device_identifier UNIQUE`, profile FK và trạng thái ghép nối/thu hồi (`backend/devices/models.py`).
- [x] Tạo model y tế `MedicalHistory`, `Allergy`, `Visit`, `Medication`, `LabResult`, `MedicalDocument` (`backend/medical_records/models.py`).
- [x] Tạo `HealthMeasurement`: đa loại chỉ số, audit timestamps, `UNIQUE(profile, idempotency_key)` và composite index (`backend/health_measurements/models.py`).
- [x] Tạo `AIInsight`, `Conversation`, `Message` theo Data Dictionary (`backend/ai_services/models.py`).
- [x] Thêm `ai_consent` mặc định false và `ai_consent_at` nullable cho Account (`backend/accounts/models.py`).
- [x] Tạo/cập nhật migrations; chạy `makemigrations`, `migrate` trên database sạch và database có dữ liệu mẫu.
- [x] Cập nhật `admin.py`/đăng ký admin cho toàn bộ các model của 8 module.

### Definition of Done

- [x] Có đủ 16 thực thể: Account, PersonProfile, Household, HouseholdMember, ProfileShare, Device, MedicalHistory, Allergy, Visit, Medication, LabResult, MedicalDocument, HealthMeasurement, AIInsight, Conversation, Message.
- [x] PK/FK, nullable, enum, default, UNIQUE và index khớp Data Dictionary.
- [x] Có test model cho unique constraints, FK, hồ sơ nhiều tài khoản và cascade deletion (`devices/tests.py`, `health_measurements/tests.py`, `households/tests.py`, `profiles/tests.py`, `ai_services/tests.py`).
- [x] Nâng cấp từ DB cũ không làm mất dữ liệu; migration guard đã hoàn thành qua `LegacyMigrationGuardTests`.

---

## Sprint 2 — PermissionService, RBAC và chống IDOR

**Mục tiêu:** xây một điểm kiểm tra quyền dùng chung ở backend trước khi mở các API đọc/ghi dữ liệu cá nhân.

### Công việc

- [x] Tạo `PermissionService`/permission classes dùng chung tại `backend/core/permissions.py`; kiểm tra JWT và xác minh quyền truy cập profile.
- [x] Cài chuỗi quyền theo Sơ đồ 2.4: Account → HouseholdMember có `ACTIVE` → vai trò → ProfileShare → PersonProfile.
- [x] Cho phép chính chủ truy cập hồ sơ liên kết; Owner có toàn quyền; Member/Caregiver kiểm tra qua quan hệ chia sẻ và household.
- [x] Phân biệt quyền thao tác trên hồ sơ chia sẻ: `VIEW_ONLY` chỉ được đọc, `VIEW_AND_LOG` được phép ghi.
- [x] Chống IDOR: Ngăn chặn truy cập trái phép hồ sơ người khác, kiểm tra quyền object-level trên backend.
- [x] Bảo đảm queryset lọc theo tập profile được cấp quyền (`PersonProfileViewSet.get_queryset`, `HealthMeasurementViewSet.get_queryset`).
- [x] Quyền quản lý Household: chỉ Owner được mời, đổi role/quyền; ngăn xóa Owner duy nhất (`_get_household_owner_membership` tại `backend/households/views.py`).
- [x] Trả mã lỗi 403 Forbidden hoặc 404 Not Found khi không đủ quyền; không làm rò rỉ dữ liệu ngoài phạm vi cho phép.

### Definition of Done

- [x] Test ma trận Owner/Member cho hồ sơ của mình, hồ sơ được chia sẻ, kiểm tra chống IDOR (`backend/core/tests/test_permissions.py`).
- [x] Test IDOR: thay `profile_id` trong URL/body bị từ chối hoặc chặn truy cập.
- [x] Test `VIEW_ONLY` đọc được nhưng ghi bị chặn theo cấp phép.
- [~] Hoàn thiện việc áp dụng `PermissionService` đồng bộ cho toàn bộ các view y bạ còn lại (MedicalHistory, Allergy, Visit,... khi triển khai API).

---

## Sprint 3 — Backend nghiệp vụ, Auth và API chuẩn hóa

**Mục tiêu:** cung cấp API dùng được và nhất quán trên các model đã ổn định, có auth/permission/validation thực sự.

### Công việc

- [x] Chuẩn hóa Account/register/login: email unique ở DB, hash mật khẩu, password validation và response code chuẩn (`backend/accounts/`).
- [~] Hoàn thiện refresh/logout: cấu hình SimpleJWT TokenRefreshView, LogoutView; thiếu cấu hình Redis Token Blacklist backend theo BR01 (`rest_framework_simplejwt.token_blacklist` với Redis cache chưa được cấu hình).
- [~] Tạo API consent riêng cho tài khoản của mình và hồ sơ DEPENDENT; xác minh quyền Owner/người giám hộ ở backend (Đã có route `auth-ai-consent` cho tài khoản cá nhân; chưa có logic kiểm tra và cấp quyền consent cho hồ sơ DEPENDENT).
- [x] Tạo CRUD `POST/GET/PUT/DELETE /profiles` và `/profiles/{id}`; hỗ trợ archive mềm thay xóa cứng (`backend/profiles/views.py`).
- [x] Tạo CRUD Household, member invite/respond/role/share/list/remove (`backend/households/views.py`, `urls.py`).
- [~] Hoàn thiện CRUD medical records (API upload/list/retrieve/delete cho `MedicalDocument` đã có; histories, allergies, visits, medications, lab-results chưa có API theo FR04/UC05; route hiện là `/api/medical/documents/`, khác contract `/medical-records/...` trong Bảng 2.52).
- [x] Tạo Health Measurement endpoints: đọc/ghi dữ liệu đo lường theo profile (`HealthMeasurementViewSet` và `HealthMeasurementBatchCreateView`).
- [x] Thêm filtering, pagination và validation miền giá trị (`HealthMeasurementPagination`).
- [~] Chuẩn hóa `backend/core/urls.py` và include app URLs (Hiện tại `devices.urls` và `health_measurements.urls` đang bị comment; routes đo lường bị đặt tạm trong `medical_records`).
- [ ] Thêm OpenAPI/Swagger schema tài liệu hóa API tự động.

### Definition of Done

- [~] Route, method, auth, permissions, schema và status codes khớp Bảng 2.41 (Mới hoàn thành nhóm accounts, profiles, households, health measurements; thiếu medical records CRUD và devices CRUD).
- [x] Anonymous nhận 401 ở endpoint yêu cầu JWT; user authenticated nhưng không đủ quyền nhận 403.
- [x] Register → login → profile setup → refresh → logout chạy end-to-end.
- [x] Create/update không tin `profile_id` do client gửi mà kiểm tra quyền thông qua `PermissionService`.
- [~] Còn tồn tại route comment trong `core/urls.py`, cần di chuyển các endpoint đo lường về đúng app `health_measurements`.

---

## Sprint 4 — Wear Sync và Offline Queue bền vững

**Mục tiêu:** không mất measurement khi mất mạng/đóng app, đồng bộ batch có kết quả theo từng bản ghi và retry an toàn.

### Backend

- [ ] Tạo Device API ghép nối, liệt kê, thu hồi; kiểm tra quyền profile đích và `device_identifier UNIQUE` (`backend/devices/views.py` hiện đang trống, chưa có URL).
- [x] Chuẩn hóa `POST /api/medical/measurements/batch/`: validate danh sách measurement, gán profile hợp lệ (`HealthMeasurementBatchCreateView`).
- [~] Trả kết quả theo từng idempotency key: `ĐÃ_TẠO`, `TRÙNG_LẶP`, `BỊ_TỪ_CHỐI` (Hiện tại batch endpoint chỉ dùng `bulk_create` cơ bản, chưa trả status chi tiết từng key theo BR07/BR08).
- [x] Dùng `UniqueConstraint(fields=['profile', 'idempotency_key'])` trên database làm chốt chặn chống trùng lặp cuối cùng.
- [ ] Cập nhật `last_synced_at` cho Device sau khi batch sync thành công (Chưa gắn liên kết cập nhật model `Device`).
- [ ] Tích hợp Redis Lock kiểm tra `idempotency_key` trước khi ghi DB theo BR07 (Chưa có cấu hình Redis).

### Flutter/Wear

- [ ] Tạo durable outbox local (SQLite/Drift), thay thế việc lưu tạm trên RAM `_pendingMeasurements` trong `dashboard_screen.dart` hoặc SharedPreferences.
- [~] Ghi measurement và idempotency key xuống local trước khi gửi dữ liệu (`MockHealthDataService` đã sinh UUID idempotency key, nhưng chưa có kho lưu trữ bền vững tại phone).
- [ ] Xây dựng State Machine cho hàng đợi: `CHỜ_GỬI`, `ĐANG_GỬI`, `ĐÃ_ĐỒNG_BỘ`, `THẤT_BẠI` có retry count và last error.
- [x] Gửi batch đo lường qua HTTP API (`HealthRepository.sendBatchMeasurements`).
- [~] Retry cơ bản khi có mạng qua `Timer.periodic`, nhưng chưa có exponential backoff và chưa chống duplicate request khi app restart.
- [x] Phân biệt lỗi HTTP và refresh token tự động qua `AuthInterceptor`.
- [x] Đồng bộ dữ liệu giả lập rõ ràng trong `main_wear.dart` với `MockHealthDataService`.

### Definition of Done

- [ ] Mất mạng, kill/restart ứng dụng: dữ liệu chưa đồng bộ vẫn còn nguyên vẹn trong Local DB SQLite và tiếp tục gửi lại khi có mạng.
- [x] Gửi lại trùng key: PostgreSQL kích hoạt `UniqueConstraint` chặn tạo trùng bản ghi.
- [~] Batch xử lý một phần: cần chuyển sang trả chi tiết từng key thay vì thất bại toàn bộ transaction khi có 1 item lỗi.
- [x] Model test chứng minh DB từ chối 2 measurement có cùng idempotency key trên một profile.

---

## Sprint 5 — Rule Engine, AI Insight/Chat, Consent BR10 và Fallback BR12

**Mục tiêu:** hoàn thiện nghiệp vụ AI ở backend; tuyệt đối không gửi dữ liệu đến Provider khi chưa có consent hợp lệ.

### Công việc

- [~] Tạo Rule Engine đánh giá sinh trắc học R01–R04: `HealthRiskAssessmentView` đã triển khai tính ngưỡng nhịp tim, huyết áp bằng NumPy, nhưng chưa tách thành service RuleEngine độc lập.
- [ ] Tạo `AIProviderService` gọi external LLM (OpenAI/Gemini/v.v.) có timeout, error handling và log bảo mật PHI.
- [ ] Tạo `InsightService`: kiểm tra profile permission → nạp dữ liệu → chạy Rule → kiểm tra BR10 consent → gọi Provider → lưu `AIInsight`.
- [~] Thực hiện BR10 ở backend trước mỗi lời gọi AI:
  - [x] Kiểm tra `ai_consent` trên Account của profile SELF (`HealthRiskAssessmentView` đã chặn 403 nếu `ai_consent=False`).
  - [ ] Kiểm tra `ai_consent` của Owner/giám hộ đối với DEPENDENT.
  - [ ] Từ chối gọi Provider nếu chưa có consent; fallback sang kết quả phân tích Rule-based.
- [ ] Thực hiện BR09 ẩn danh dữ liệu (de-identification): loại bỏ PII (tên, email, ngày sinh chính xác, liên hệ khẩn cấp) trước khi gửi prompt đến AI Provider.
- [x] Tạo API `/api/ai/assess-risk/<uuid:profile_id>/` phân tích rủi ro dựa trên chuỗi thời gian đo lường (`backend/ai_services/views.py`).
- [~] Hoàn thiện Chat API theo contract (`/conversations/`, `/messages/`): hiện `POST /api/ai/chat/<profile_id>/` đã kiểm tra quyền/consent, lưu Conversation và Message, tạo context từ measurement và trả `conversation_id`; chưa có API liệt kê/lấy lịch sử hội thoại, AI Provider, BR09/BR12 hoặc test TC07.1–TC07.5.
- [ ] Chat fallback BR12: khi AI timeout/lỗi, trả thông báo an toàn định sẵn; không lưu fallback error message giả mạo role `ASSISTANT`.
- [ ] Insight fallback BR12: tự động chuyển sang `RULE_ONLY` khi Provider gặp sự cố.
- [~] Gắn disclaimer y tế: đã có khuyến cáo sơ bộ trong response JSON của `HealthRiskAssessmentView`, cần chuẩn hóa disclaimer pháp lý trên toàn bộ API AI.

### Definition of Done

- [x] Test đánh giá rủi ro sinh trắc học API (`ai_services/tests.py:HealthRiskAssessmentApiTests`).
- [~] Test chứng minh Provider/API bị chặn khi `ai_consent = False` theo BR10 (Đã kiểm tra qua code `HealthRiskAssessmentView`, cần bổ sung test method khẳng định 403 khi consent false).
- [ ] Test kiểm tra prompt không chứa PII theo BR09; test timeout kích hoạt Fallback BR12.
- [ ] Hoàn thành API Chat Conversation và Message có kiểm soát phân quyền.

---

## Sprint 6 — Flutter: tích hợp API và hoàn thiện SCR-01–SCR-10

**Mục tiêu:** chỉ tích hợp contract đã nghiệm thu ở backend; bỏ dữ liệu giả lập khỏi luồng nghiệp vụ đang trình bày là dữ liệu thật.

### Công việc

- [~] Hợp nhất `ApiClient`: Dự án đang tồn tại 2 file `frontend/lib/core/network/api_client.dart` và `frontend/lib/services/api_client.dart` với cách cấu hình URL khác nhau, cần chuẩn hóa về một client duy nhất dùng `api_config.dart`.
- [x] Luồng xác thực SCR-01, SCR-02, SCR-03: Đăng ký, đăng nhập, lưu JWT vào `FlutterSecureStorage`, điều hướng qua `AuthGate` (`login_screen.dart`, `register_screen.dart`, `profile_setup_screen.dart`).
- [~] SCR-04 (Dashboard): Đã tải hồ sơ và measurement qua API, gửi batch pending lên backend; dữ liệu Wear/mock và hàng đợi pending chưa bền vững qua restart, chưa đạt TC05/NFR05–NFR06.
- [~] SCR-05 (Family Members): Giao diện `family_members_screen.dart` vẫn đang dùng danh sách fix cứng (`_FamilyMember(name: 'Tôi', ...)`), chưa gọi API Household backend.
- [~] SCR-06 (Devices): `devices_screen.dart` đã có giao diện đồng bộ và modal ghép nối, nhưng chưa nối Device API backend.
- [~] SCR-07 (Health Journal): `health_journal_screen.dart` tải measurement qua API; tài liệu có màn riêng `MedicalRecordsScreen`, nhưng histories/allergies/visits/medications/lab-results chưa có CRUD API/UI theo FR04.
- [~] SCR-08 (AI Assistant): `ai_assistant_screen.dart` gọi API thật cho risk và chat, giữ `conversation_id`; chat phụ `ai_chat_screen.dart` vẫn in-memory. Backend mới là rule-based, chưa đáp ứng đầy đủ R01–R04, AI Provider, BR09/BR10 cho DEPENDENT, BR12 và các TC07/TC08.
- [~] SCR-09 (Quick Add): `quick_add_screen.dart` POST measurement thủ công qua `ApiService.createManualMeasurements`; cần kiểm chứng validation theo miền, phản hồi lỗi và refresh SCR-04/SCR-07/SCR-10 theo TC04.1–TC04.4.
- [~] SCR-10 (Health Trends): `health_trends_screen.dart` đang đọc dữ liệu từ `ApiService.fetchHealthMeasurements`, cần xử lý đầy đủ các nhóm chỉ số sinh trắc khác.
- [x] Tự động Refresh Token khi gặp lỗi 401 qua `AuthInterceptor` và hỗ trợ đăng xuất an toàn xóa bộ nhớ bảo mật.
- [x] Test widget và test unit service mô phỏng dữ liệu (`frontend/test/`).

### Definition of Done

- [~] Các luồng cốt lõi Auth/Profile, Dashboard, Health Journal, Quick Add, Trends, Medical Documents và AI Assistant đã có một phần kết nối API thật; Household UI, Devices, medical CRUD ngoài documents, durable offline queue, lịch sử chat và một số trạng thái nghiệp vụ vẫn thiếu/mock. Chưa nghiệm thu đủ SCR-01–SCR-10.
- [x] Token lưu trữ bảo mật với `flutter_secure_storage`; refresh token tự động kích hoạt khi token hết hạn.
- [~] Cần xử lý triệt để trạng thái Offline / SQLite local sync thay cho biến RAM tạm thời.

---

## Sprint 7 — Kiểm thử tích hợp, bảo mật và truy vết

**Mục tiêu:** nghiệm thu yêu cầu chức năng và quy tắc nghiệp vụ trước khi đóng gói/bảo vệ.

### Công việc

- [x] Chạy toàn bộ test suite backend cho models, permission logic, data migration guard (`backend/*/tests.py`, `backend/core/tests/`).
- [x] Chạy Flutter tests (`frontend/test/`).
- [~] Thực hiện acceptance test matrix: TC01 (Auth) và TC05 (Batch Idempotency DB) đã có test tự động; TC02 (IDOR) đã có test; các TC liên quan đến AI Provider, BR10 Consent, Device Revocation và Offline Reconnect cần bổ sung test suite.
- [x] Đảm bảo cấu hình production an toàn trong `settings.py`: CSRF, HSTS, SECURE_SSL_REDIRECT, CORS và SECRET_KEY đọc từ biến môi trường `.env`.
- [ ] Cấu hình Redis Cache và Redis Token Blacklist backend theo BR01.
- [~] Cập nhật tài liệu API, OpenAPI Swagger và sơ đồ kiến trúc đồng bộ với các đường dẫn endpoint thực tế.
- [x] Rà soát và đánh giá trạng thái checklist khách quan theo tiến độ thực tế mã nguồn.

### Definition of Done

- [x] Toàn bộ test hiện có đều pass không có regression.
- [~] Test chống IDOR và test Unique Idempotency đã có; cần bổ sung test tự động cho AI Consent (BR10) và Device Pairing.
- [~] Tài liệu kỹ thuật cần cập nhật chính xác vị trí router của Health Measurements và Medical Records.

---

## Ma trận nghiệm thu tổng thể

| Phạm vi | Điều kiện tối thiểu để được tính hoàn thành | Trạng thái |
|---|---|---|
| 8 module | Authentication, Profile, Household, Medical Record, Health Measurement, Wear Sync, AI Insight, AI Chat đều có model/service/API/UI tương ứng theo phạm vi Chương 2 | [~] 16 Models đã đủ; API & UI mới hoàn thành 4/8 module (Auth, Profile, Household, Health Measurement) |
| 16 bảng | Đủ model/migration, PK/FK, nullable, enum, UNIQUE, index và test theo Data Dictionary | [x] Đã hoàn thành 16/16 model, constraints và unit tests |
| RBAC/IDOR | Backend kiểm tra Account → HouseholdMember ACTIVE → ProfileShare → PersonProfile; test chéo hồ sơ cho read/write/delete | [x] Đã hoàn thành `PermissionService` & có test chứng minh |
| Consent BR10 | Kiểm tra đúng chủ thể dữ liệu ở mỗi lần gọi Provider; không gọi khi thiếu/thu hồi consent | [~] Model Account đã có `ai_consent`; `HealthRiskAssessmentView` đã check consent tài khoản chính, nhưng chưa có kiểm tra guardian consent cho DEPENDENT và chưa có AI Provider ngoài |
| Fallback BR12 | Insight trả Rule-only khi AI lỗi; Chat trả phản hồi dự phòng không giả dạng Assistant message; có retry | [~] Đã có rule sinh trắc học cơ bản tại `HealthRiskAssessmentView`; chưa có tích hợp AI Provider ngoài và chat fallback |
| Wear/Offline | Queue bền vững, trạng thái từng item, idempotency key ổn định, batch partial result và retry sau restart | [~] Idempotency DB constraint đã có; hàng đợi Flutter hiện vẫn nằm trên RAM, chưa có SQLite Durable Outbox |
| API | Contract, auth, permission, schema, pagination, validation, status code và tests thống nhất với Chương 2 | [~] Các API Auth, Profile, Household, Batch Measurement đã hoạt động; thiếu CRUD Medical Records, Devices, AI Chat |
| Flutter SCR-01–SCR-10 | Các luồng được nối API thật; có loading/error/empty/offline | [~] SCR-01..03 đã nối API; SCR-04..10 vẫn còn các thành phần mock/in-memory |

## Ghi chú về trạng thái và kế hoạch xử lý

1. **Bảo mật & Phân quyền (BR01, BR05):**
   - RBAC và chống IDOR đã được kiểm chứng bằng test tự động qua `PermissionService`.
   - Cần bổ sung Redis cấu hình cho SimpleJWT Blacklist để hoàn thiện trọn vẹn BR01.
2. **Xử lý trùng lặp (BR07, BR08):**
   - Database đã chặn trùng lặp qua `UniqueConstraint(fields=['profile', 'idempotency_key'])`.
   - Cần bổ sung Redis Distributed Lock trên View và phản hồi chi tiết trạng thái từng key (`ĐÃ_TẠO`, `TRÙNG_LẶP`, `BỊ_TỪ_CHỐI`) trong batch response.
3. **Trí tuệ nhân tạo (BR10, BR12):**
   - Đã kiểm tra `ai_consent` trên view phân tích rủi ro cho hồ sơ chính; cần mở rộng kiểm tra quyền giám hộ đối với hồ sơ DEPENDENT.
   - Cần tách `RuleEngine` thành service riêng, bao bọc lệnh gọi LLM bằng kiểm tra consent và try/catch fallback về rule engine khi có lỗi mạng/timeout.
4. **Đồng bộ thiết bị ngoại vi & Flutter:**
   - Hoàn thiện `devices/views.py` và mở lại route `api/devices/`.
   - Chuyển `_pendingMeasurements` từ biến RAM trên Flutter sang bảng cục bộ SQLite (sqflite/drift) để đảm bảo không mất dữ liệu đo lường khi tắt ứng dụng hoặc mất nguồn.

---

## Comprehensive System Audit & Feature Test — Medical Records và AI

> Kịch bản nghiệm thu thủ công dựa trên code hiện có. Chỉ đánh dấu `[x]` sau khi chạy trên môi trường thực và lưu bằng chứng; test tự động hiện có không thay thế kiểm tra giao diện, thiết bị và cấu hình lưu trữ.

### A. Hồ sơ y tế / đơn thuốc

**Code hiện có để đối chiếu:** `MedicalDocument` lưu `profile`, `document_type`, `title`, `file`, `description`, `uploaded_at`; API ở `/api/medical/documents/`; upload multipart, tối đa 10 MiB, nhận PDF/JPEG/PNG. File được lưu dưới `private_uploads/medical_documents/<profile UUID>/...`; API không trả nội dung file trong JSON mà cung cấp endpoint download có kiểm tra quyền. Flutter `MedicalRecordsScreen` tải profile/danh sách, cho chọn profile, upload và tải/xóa tài liệu. Các model y khoa `MedicalHistory`, `Allergy`, `Visit`, `Medication`, `LabResult` hiện chưa có CRUD API tương ứng; không nghiệm thu chúng như tính năng đã hoạt động.

| ID | Bước thực hiện | Kết quả mong đợi / bằng chứng | Trạng thái |
|---|---|---|---|
| MR-01 | Đăng nhập tài khoản A; mở Hồ sơ y tế; chọn profile SELF; tải ảnh PNG/JPEG hoặc PDF đơn thuốc, nhập tiêu đề, loại `PRESCRIPTION`, mô tả; tải lên. | UI báo thành công; `GET /api/medical/documents/?profile_id=<SELF_UUID>` trả bản ghi có `id`, `profile_id`, `document_type`, `title`, `file_name`, `description`, `uploaded_at`; không có trường `file` trong response. | [ ] |
| MR-02 | Lặp MR-01 với profile DEPENDENT mà A có quyền ghi (ví dụ Bố/Mẹ đã được chia sẻ `VIEW_AND_LOG`). | Bản ghi gắn đúng UUID profile được chọn; đổi profile trong UI chỉ hiển thị tài liệu của profile đó. | [ ] |
| MR-03 | Tải xuống tài liệu vừa thêm từ UI. | `GET /api/medical/documents/<id>/download/` trả file bytes đúng; `Content-Disposition: attachment`, `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`; mở file được và nội dung khớp file nguồn. | [ ] |
| MR-04 | Thử tải `.txt`, file lớn hơn 10 MiB, thiếu token, profile UUID không hợp lệ. | File không hợp lệ trả 400 có lỗi validation; request không xác thực trả 401; UUID sai trả 400; UI giữ được trạng thái lỗi và cho thử lại. | [ ] |
| MR-05 | Đăng nhập tài khoản B không được chia sẻ profile; gọi GET list, retrieve, download bằng profile/document ID của A; thử DELETE. | Không lộ metadata/file; list rỗng hoặc 404, retrieve/download 404, DELETE bị từ chối (code hiện có kỳ vọng 403). Bản ghi của A vẫn còn nguyên. Lưu request/response đã che token. | [ ] |
| MR-06 | A xóa tài liệu qua UI, sau đó tải lại màn hình/API. | API trả 204; file và metadata không còn; UI loại bản ghi sau refresh. | [ ] |
| MR-07 | Tắt backend/mạng khi mở màn hình và khi upload/download. | UI thể hiện lỗi dễ hiểu, không kẹt loading; sau khi mạng trở lại có thể tải lại; không tạo bản ghi trùng khi người dùng chỉ retry sau khi biết request trước thất bại. | [ ] |

**Kiểm tra lưu trữ trên server:** đối chiếu file trong `MEDIA_ROOT` với `MedicalDocument.file.name`, profile UUID và kích thước; metadata DB phải tham chiếu đúng file. Không dùng media URL công khai để vượt qua endpoint download có phân quyền. Với deployment nhiều instance, xác nhận `MEDIA_ROOT` là persistent/shared storage và có backup, quota, retention; `private_uploads` trong cấu hình local không tự đảm bảo các yêu cầu production này.

**Test tự động đã tìm thấy:** `backend/medical_records/tests.py::MedicalDocumentApiTests` bao gồm upload/list/download, lọc profile, IDOR, xóa file, phần mở rộng sai và kích thước >10 MiB. Đây là bằng chứng code test có tồn tại; cần chạy suite và lưu kết quả khi nghiệm thu. Cần bổ sung/kiểm tra test cho unauthenticated request, MIME giả mạo/nội dung file thực, UI states và cấu hình storage production.

### B. Trợ lý AI và phân tích ngữ cảnh

**Giới hạn cần ghi rõ trong báo cáo:** endpoint hiện chạy rule-based cục bộ với NumPy, không phải mô hình tạo sinh/provider LLM. Chat lấy tối đa 100 phép đo trong 30 ngày, nhóm theo loại chỉ số và tạo câu trả lời dựa trên từ khóa cố định; đánh giá nguy cơ lấy tối đa 50 phép đo gần nhất. Huyết áp dùng một bản ghi `BLOOD_PRESSURE` với `value` là tâm thu, `value_secondary` là tâm trương. Vì vậy kết quả chỉ xác minh được việc truy xuất/tính toán theo các rule này; câu hỏi diễn đạt mở có thể rơi về tóm tắt mặc định, không được xem là hiểu ngôn ngữ tự nhiên.

**Chuẩn bị dữ liệu test:** dùng profile giả lập riêng; ghi 2–3 phép đo huyết áp (ví dụ 145/95, 138/88, 120/80), nhịp tim (ví dụ 72, 108), đặt `measured_at` trong 30 ngày. Ghi lại thời điểm và giá trị chính xác để đối chiếu. Không sử dụng hồ sơ/dữ liệu bệnh nhân thật trong môi trường dev hoặc báo cáo.

| ID | Câu hỏi/thao tác | Kiểm tra kết quả | Trạng thái |
|---|---|---|---|
| AI-01 | Hỏi “Huyết áp gần đây của tôi là bao nhiêu?” trên đúng profile. | Chat response phản ánh bản ghi mới nhất và trung bình 30 ngày dạng tâm thu/tâm trương; so sánh trực tiếp với DB và màn Nhật ký. | [ ] |
| AI-02 | Hỏi “Huyết áp trung bình tháng này thế nào?” | Hệ thống hiện chỉ tính cửa sổ 30 ngày, không hiểu “tháng này” theo lịch; kiểm tra kết quả được gắn nhãn trung bình 30 ngày. Ghi đây là giới hạn hợp đồng/ngôn ngữ. | [ ] |
| AI-03 | Hỏi “Nhịp tim gần đây của tôi?” rồi “Có xu hướng tăng không?” | Câu hỏi đầu nhận nhóm HEART_RATE, trung bình và thay đổi theo bản ghi cũ nhất trong tập 30 ngày; câu hỏi thứ hai có thể chỉ trả summary mặc định do rule không phân tích intent xu hướng tự do. | [ ] |
| AI-04 | Gọi `GET /api/ai/assess-risk/<profile_id>/` với dữ liệu 145/95; sau đó thử dữ liệu bình thường. | So sánh `risk_level`, `analyzed_count`, `warnings`, `recommendation`; BP ≥140 systolic hoặc ≥90 diastolic tạo cảnh báo HIGH theo rule hiện tại. Đây không phải chẩn đoán lâm sàng. | [ ] |
| AI-05 | Hỏi về số đo cũ hơn 30 ngày / profile không có dữ liệu / loại chỉ số chưa hỗ trợ. | Không được khẳng định hệ thống nhớ mọi lịch sử; phản hồi phải nói rõ không có dữ liệu trong cửa sổ phân tích khi phù hợp. | [ ] |
| AI-06 | Gửi hai lượt chat liên tiếp cùng profile, truyền `conversation_id` nhận từ lượt đầu; thử dùng ID hội thoại của user/profile khác. | Cùng hội thoại trả lại cùng `conversation_id`; hội thoại sai owner/profile bị từ chối/404; UI có loading, lỗi và khóa gửi lặp trong khi request đang chạy. | [ ] |
| AI-07 | Gọi risk/chat khi chưa đăng nhập, không có quyền profile, hoặc `ai_consent=false`. | 401 cho anonymous; 403 cho profile trái phép hoặc thiếu consent; không trả dữ liệu sức khỏe. Thử riêng profile DEPENDENT: kiểm tra hiện tại xem consent được xét theo tài khoản gọi hay người thuộc profile; yêu cầu consent đúng chủ thể/guardian là mục cần xác minh và hoàn thiện. | [ ] |

**Mở rộng hiểu câu hỏi mở:** tách `RuleEngine` (truy xuất và thống kê có kiểm chứng) khỏi `Intent/QueryService`; chuẩn hóa câu hỏi thành intent có schema allowlist (metric, time range, aggregation), chỉ cho phép query tham số hóa qua ORM và profile đã được authorize. Với LLM, gửi ngữ cảnh tối thiểu đã loại PII, bắt buộc consent theo đúng chủ thể, timeout/rate limit, không cho LLM tự truy cập DB hoặc tự đưa chẩn đoán; kiểm tra JSON output, lưu audit an toàn và fallback về rule khi provider lỗi. Viết test theo cặp câu hỏi diễn đạt khác nhau nhưng kỳ vọng cùng intent, câu ngoài phạm vi, prompt injection và profile isolation trước khi bật provider.

### C. Checklist trước nghiệm thu / báo cáo

- [ ] So khớp `Chuong2_HoanChinh.docx` với routes, request/response JSON, status code, permission, pagination và các trường UUID/date/number; ghi rõ tính năng chỉ có model nhưng chưa có API.
- [ ] Chạy migration trên DB test sạch và DB nâng cấp; xác minh FK, UNIQUE/idempotency, index, nullable, enum, cascade/SET_NULL và không sửa migration đã phát hành.
- [ ] API: thiếu/sai token, profile IDOR, input rỗng/sai kiểu/giá trị biên, upload MIME/size, lỗi DB/storage, timeout; response không để lộ traceback, token, PII hoặc đường dẫn nội bộ.
- [ ] Medical documents: upload-list-download-delete; kiểm tra quyền riêng cho list/retrieve/create/delete/download; kiểm tra file storage riêng tư, backup, quota, retention và xử lý file lỗi.
- [ ] AI: xác minh consent và quyền cho từng profile, đúng cửa sổ thời gian/dataset, hội thoại thuộc đúng owner/profile, disclaimer và giới hạn rule-based được hiển thị; không coi output là chẩn đoán.
- [ ] Flutter mọi màn/API: loading, success, empty, error, retry, pull-to-refresh/đổi profile, mounted/dispose an toàn; không hiển thị dữ liệu profile cũ sau khi chuyển thành viên.
- [ ] Authentication: token lưu/đọc cùng key, request gửi Authorization, hết hạn/401 được xử lý, logout xóa token; không log token.
- [ ] Ghi evidence cho mỗi case: build/commit, môi trường, account giả lập, profile ID đã che một phần, request/response đã bỏ token, ảnh UI, DB/file assertion và kết quả pass/fail. Không đưa PHI/secrets vào checklist hoặc repo.
- [ ] Chỉ đổi trạng thái checklist sang `[x]` sau khi có bằng chứng chạy thực tế; ghi lỗi thành issue có bước tái hiện, mức độ ảnh hưởng, owner và cách xác minh bản sửa.
