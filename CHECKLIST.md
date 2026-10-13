# HealthyApp — Checklist hành động theo Sprint

> Lộ trình này được lập để đưa prototype hiện tại khớp dần với `docs/Chuong2_HoanChinh.docx` (Chương 2). Sprint được sắp theo phụ thuộc kỹ thuật: **hợp đồng dữ liệu → CSDL/model → logic bảo mật/nghiệp vụ → API → đồng bộ/AI → Flutter → nghiệm thu**. Chỉ đánh dấu `[x]` khi có mã nguồn và bằng chứng kiểm thử tương ứng; UI hoặc endpoint giả lập không được tính là hoàn thành nghiệp vụ.
>
> Trạng thái ban đầu ghi nhận khi lập checklist: backend có `PersonProfile`, `HealthMeasurement`, auth cơ bản và batch endpoint; các model còn thiếu, phân quyền hộ gia đình, consent và dịch vụ AI chưa có. Flutter có các màn hình prototype; số đo thủ công và hàng đợi Wear hiện chưa đồng bộ bền vững với backend.
>
> - `[ ]` Chưa thực hiện
> - `[~]` Đã có một phần, cần sửa/bổ sung/kiểm thử
> - `[x]` Đạt DoD và có test/bằng chứng

## Quy tắc quản lý tiến độ

- [ ] Chốt tài liệu Chương 2 làm chuẩn; nếu cần thay đổi schema hoặc API thì cập nhật tài liệu/hợp đồng trước khi code.
- [ ] Tạo nhánh/PR riêng cho từng Sprint; mỗi PR gồm migration, test và ghi chú thay đổi API liên quan.
- [ ] Không bắt đầu Flutter tích hợp một endpoint trước khi schema, quyền truy cập, response schema và test API của endpoint đó đã ổn định.
- [ ] Không sửa/xóa migration đã áp dụng lên môi trường dùng chung; tạo migration mới và kiểm thử đường nâng cấp dữ liệu.
- [ ] Dùng dữ liệu kiểm thử giả lập; không đưa dữ liệu sức khỏe thật hoặc secret vào log, fixture công khai hay repository.

---

## Sprint 0 — Chốt hợp đồng và đường di trú

**Mục tiêu:** loại bỏ mơ hồ giữa Chương 2, backend đang chạy và frontend; chuẩn bị đường nâng cấp an toàn trước khi thay model.

### Công việc

- [ ] Lập bảng ánh xạ 16 thực thể, trường, PK/FK, UNIQUE, index và enum từ Data Dictionary (Bảng 2.24–2.40).
  - Tài liệu nguồn: `docs/Chuong2_HoanChinh.docx`.
  - Đầu ra: cập nhật `README.md` hoặc tài liệu API hiện có; không tạo schema thứ hai trái với Chương 2.
- [~] Chốt quy ước endpoint, tiền tố `/api`, dấu `/` cuối URL, request/response, phân trang và mã lỗi.
  - Các nhóm phải có: `/auth/*`, `/profiles`, `/households/*`, `/medical-records/*`, `/health-measurements*`, `/devices*`, `/ai-insights*`, `/conversations`, `/messages`.
  - Chốt tương thích `/api/auth/token/refresh/` hiện có với endpoint tài liệu `/auth/refresh`; cập nhật tài liệu hoặc route theo một quy ước duy nhất.
- [~] Kiểm kê dữ liệu đang lưu trong `PersonProfile`, `HealthMeasurement` và app cũ `health_metrics`; xác định ánh xạ dữ liệu sang schema đích.
  - File cần rà: `backend/medical_records/models.py`, `backend/health_metrics/models.py`, các migration hiện có.
- [ ] Viết kế hoạch migration theo giai đoạn cho PK UUID và quan hệ hiện có; xác định backup/rollback trước khi migrate dữ liệu.
- [ ] Xác định thứ tự phát hành migration và phiên bản API để tránh frontend/backend lệch hợp đồng.

### Definition of Done

- [ ] Có danh sách 16 bảng và mapping trường được đối chiếu trực tiếp với Data Dictionary.
- [~] Mọi endpoint chính có method, quyền, schema đầu vào/đầu ra và status code thống nhất.
- [ ] Có phương án bảo toàn dữ liệu cũ, backup và rollback; không thay PK trực tiếp mà chưa có kế hoạch migrate.

---

## Sprint 1 — CSDL và 16 Django models

**Mục tiêu:** hoàn tất nền tảng dữ liệu trước khi triển khai API phụ thuộc.

### Công việc

- [~] Chọn và ghi rõ cách quản lý `Account`: nếu chuyển sang custom user model, xử lý migration hiện hữu cẩn thận (không chỉ đổi `AUTH_USER_MODEL` trên database đã có dữ liệu).
  - File: `backend/accounts/models.py`, `backend/core/settings.py`, migration mới trong `backend/accounts/migrations/`.
- [~] Chuyển `PersonProfile` từ quan hệ One-to-One bắt buộc sang quan hệ Account 1—0..* PersonProfile; hỗ trợ hồ sơ DEPENDENT chưa gắn tài khoản.
  - File: `backend/medical_records/models.py` hoặc app `profiles` mới; migrations tương ứng.
- [~] Khai báo UUID PK cho các thực thể theo tài liệu và migration dữ liệu có kiểm soát.
- [~] Hoàn thiện `PersonProfile`: `profile_type`, `full_name`, ngày sinh, giới tính, chiều cao, cân nặng, nhóm máu, liên hệ khẩn cấp, `is_archived`, `created_at`, `updated_at`.
- [~] Tạo model `Household`, `HouseholdMember`, `ProfileShare`.
  - Ràng buộc: `UNIQUE(household_id, profile_id)`; `UNIQUE(member_id, profile_id)`; member có role/status và thời hạn invitation như Data Dictionary.
- [~] Tạo model `Device`; đặt `device_identifier UNIQUE`, profile FK và trạng thái ghép nối/thu hồi.
- [ ] Tạo model y tế `MedicalHistory`, `Allergy`, `Visit`, `Medication`, `LabResult`, `MedicalDocument` với FK profile và FK Visit → Medication theo tài liệu.
- [~] Thay `HealthMeasurement` hiện có bằng schema đa loại: `measurement_type`, `value`, `value_secondary`, `unit`, `measured_at`, `start_time`, `end_time`, `source`, `device` FK nullable, `idempotency_key` nullable và audit timestamps.
  - Ràng buộc: `UNIQUE(profile_id, idempotency_key)`; index `(profile_id, measurement_type, measured_at DESC)`.
- [ ] Tạo `AIInsight`, `Conversation`, `Message` theo Data Dictionary; Conversation liên kết Account và Profile, Message liên kết Conversation.
- [~] Thêm `ai_consent` mặc định false và `ai_consent_at` nullable cho Account (cùng trường/quan hệ cần thiết để biểu diễn consent người giám hộ cho DEPENDENT theo quyết định schema đã chốt).
- [~] Tạo/cập nhật migrations; chạy `makemigrations --check`, `migrate` trên database sạch và database có dữ liệu mẫu.
- [ ] Cập nhật `admin.py`/đăng ký admin cho các model cần kiểm tra vận hành.

### File/module dự kiến

- `backend/accounts/models.py`
- `backend/core/settings.py`
- `backend/profiles/` (nếu tách app) hoặc `backend/medical_records/models.py`
- `backend/households/` (nếu tách app)
- `backend/medical_records/models.py`
- `backend/devices/` (nếu tách app)
- `backend/ai_services/` (model AI có thể ở app chuyên biệt)
- `backend/*/migrations/`
- `backend/*/admin.py`

### Definition of Done

- [~] Có đủ 16 thực thể: Account, PersonProfile, Household, HouseholdMember, ProfileShare, Device, MedicalHistory, Allergy, Visit, Medication, LabResult, MedicalDocument, HealthMeasurement, AIInsight, Conversation, Message.
- [~] PK/FK, nullable, enum, default, UNIQUE và index khớp Data Dictionary; migrations tái tạo được schema trên DB sạch.
- [ ] Có test model cho unique constraints, FK, hồ sơ nhiều tài khoản và hồ sơ phụ thuộc.
- [ ] Nâng cấp từ DB cũ không làm mất dữ liệu; migration được thử trên bản sao dữ liệu và có hướng rollback.

### Ghi nhận rà soát 2026-10-13

- Sprint 0 chưa có bảng mapping 16 thực thể hoặc kế hoạch backup/rollback. README mới ghi hợp đồng cho các route auth và measurement cũ; chưa bao phủ đủ các nhóm API mục tiêu.
- Đã có `Account` custom với UUID và trường consent; `profiles.PersonProfile` hỗ trợ account nullable, UUID, hồ sơ SELF/DEPENDENT, cùng các model cơ bản cho Household, ProfileShare, Device và HealthMeasurement.
- Chưa có các model MedicalHistory, Allergy, Visit, Medication, LabResult, MedicalDocument, AIInsight, Conversation hoặc Message.
- Còn hai định nghĩa `PersonProfile` và hai định nghĩa `HealthMeasurement` trong `profiles`/`health_measurements` và `medical_records`; các schema/migration hiện chưa được hợp nhất. Model/migration chưa đủ chứng minh chuyển dữ liệu an toàn từ DB hiện hữu.
- Xác minh: `manage.py check` đạt; `makemigrations --check --dry-run` thất bại vì phát sinh đề xuất migration `accounts.0002_alter_account_user_permissions`; `manage.py test` chạy 7 test và cả 7 lỗi do test cũ còn dùng `username`, `auth.User` hoặc quan hệ profile cũ.
- Vì vậy chưa đạt DoD Sprint 0 hoặc Sprint 1; các mục `[~]` chỉ phản ánh đã có một phần code/tài liệu, không phải đã nghiệm thu.

---

## Sprint 2 — PermissionService, RBAC và chống IDOR

**Mục tiêu:** xây một điểm kiểm tra quyền dùng chung ở backend trước khi mở các API đọc/ghi dữ liệu cá nhân.

### Công việc

- [ ] Tạo `PermissionService`/permission classes dùng chung; kiểm tra JWT trước, sau đó xác minh hồ sơ đích.
  - Gợi ý: `backend/core/permissions.py` hoặc `backend/permissions/services.py`.
- [ ] Cài chuỗi quyền theo Sơ đồ 2.4: Account → HouseholdMember có `ACTIVE` → vai trò → ProfileShare → PersonProfile.
- [ ] Cho phép chính chủ truy cập hồ sơ liên kết; Owner được quyền theo Bảng 2.42; Member/Caregiver chỉ được xem hồ sơ được chia sẻ.
- [ ] Với ghi chỉ số trên hồ sơ chia sẻ, bắt buộc `VIEW_AND_LOG`; `VIEW_ONLY` chỉ được đọc.
- [ ] Member/Caregiver không được ghi hồ sơ người khác ngoài ngoại lệ được đặc tả; không cho client tự quyết `profile_id`, owner, role hoặc quyền.
- [ ] Bảo đảm mọi queryset lọc theo tập profile đã cấp quyền; kiểm tra object-level permission cho cả GET/POST/PUT/PATCH/DELETE.
- [ ] Với quyền quản lý Household: chỉ Owner được mời, đổi role/quyền, xóa thành viên; ngăn xóa Owner duy nhất; chỉ người được mời được phản hồi invitation.
- [ ] Dùng 403 cho người đã xác thực nhưng không có quyền; không trả nội dung tài nguyên ngoài phạm vi.

### File/module dự kiến

- `backend/core/permissions.py` hoặc `backend/permissions/`
- `backend/households/models.py`, `backend/households/services.py`
- `backend/profiles/permissions.py` (nếu cần adapter theo profile)
- `backend/medical_records/views.py`, `backend/medical_records/serializers.py`
- `backend/*/tests/test_permissions.py` hoặc các file test tương ứng

### Definition of Done

- [ ] Test ma trận Owner/Member/Caregiver cho hồ sơ của mình, hồ sơ được chia sẻ, hồ sơ không chia sẻ, lời mời PENDING và user ngoài Household.
- [ ] Test IDOR: thay `profile_id` trong URL/body không thể đọc, sửa, xóa hoặc tạo bản ghi trên profile trái quyền.
- [ ] Test `VIEW_ONLY` đọc được nhưng ghi bị 403; `VIEW_AND_LOG` chỉ có quyền ghi đúng loại thao tác được cho phép.
- [ ] Mọi endpoint dữ liệu cá nhân chạy permission backend; UI ẩn/hiện nút không được dùng làm lớp bảo mật.

---

## Sprint 3 — Backend nghiệp vụ, Auth và API chuẩn hóa

**Mục tiêu:** cung cấp API dùng được và nhất quán trên các model đã ổn định, có auth/permission/validation thực sự.

### Công việc

- [ ] Chuẩn hóa Account/register/login: email unique ở DB, hash mật khẩu, lỗi chung khi đăng nhập sai, password validation và response code khớp Chương 2.
  - File: `backend/accounts/views.py`, `backend/accounts/serializers.py` (tạo nếu chưa có), `backend/accounts/urls.py`, `backend/accounts/tests.py`.
- [ ] Hoàn thiện refresh/logout: rotation, blacklist/reuse behavior theo SimpleJWT; ràng buộc refresh token logout thuộc phiên/tài khoản đang xác thực.
  - Route thống nhất với `/auth/refresh`, `/auth/logout`; file `backend/core/settings.py`.
- [ ] Tạo API consent riêng cho tài khoản của mình và hồ sơ DEPENDENT; xác minh quyền Owner/người giám hộ ở backend. (Kiểm tra consent trước AI sẽ nghiệm thu ở Sprint 6.)
- [ ] Tạo CRUD `POST/GET/PUT/DELETE /profiles` và `/profiles/{id}`; hỗ trợ archive mềm thay xóa cứng.
- [ ] Tạo CRUD Household, member invite/respond/role/share/list/remove; chống trùng theo unique constraints và giữ ít nhất một Owner.
- [ ] Tạo CRUD medical records cho histories, allergies, visits, medications, lab-results, documents; kiểm tra loại file/kích thước/quyền trước khi lưu tài liệu.
- [ ] Tạo Health Measurement endpoints: tạo/đọc/cập nhật/xóa theo loại và profile; không cho sửa/xóa bản ghi nguồn thiết bị nếu đặc tả cấm.
- [ ] Thêm filtering, ordering, pagination và validation miền giá trị; trả lỗi theo field và không lưu dữ liệu sai.
- [ ] Chuẩn hóa `backend/core/urls.py` và include app URLs; gỡ hoặc chuyển endpoint legacy `/health/` sau khi đã di trú client/test.
- [ ] Thêm OpenAPI/schema hoặc bảng hợp đồng API được cập nhật cùng code.

### File/module dự kiến

- `backend/accounts/{models.py,serializers.py,views.py,urls.py,tests.py}`
- `backend/core/{settings.py,urls.py}`
- `backend/profiles/{serializers.py,views.py,urls.py,tests.py}`
- `backend/households/{serializers.py,views.py,urls.py,tests.py}`
- `backend/medical_records/{serializers.py,views.py,urls.py,tests.py}`
- `backend/devices/` và `backend/ai_services/` (API tương ứng ở các Sprint sau)

### Definition of Done

- [ ] Route, method, auth, permissions, schema và status codes khớp Bảng 2.41; contract tests bao phủ từng nhóm.
- [ ] Anonymous nhận 401 ở endpoint yêu cầu JWT; user authenticated nhưng không đủ quyền nhận 403.
- [ ] Register → login → profile setup → refresh → logout chạy end-to-end; refresh rotation/blacklist được kiểm thử.
- [ ] Create/update không tin `account_id`, `profile_id`, role hoặc source do client cung cấp nếu chưa xác minh quyền.
- [ ] Không còn route legacy mồ côi hoặc frontend/test nào dựa vào endpoint không được đăng ký.

---

## Sprint 4 — Wear Sync và Offline Queue bền vững

**Mục tiêu:** không mất measurement khi mất mạng/đóng app, đồng bộ batch có kết quả theo từng bản ghi và retry an toàn.

### Backend

- [ ] Tạo Device API ghép nối, liệt kê, thu hồi; kiểm tra quyền profile đích và `device_identifier UNIQUE`.
- [ ] Chuẩn hóa `POST /health-measurements/batch`: giới hạn kích thước, validate từng measurement, kiểm tra thiết bị/profile/quyền.
- [ ] Trả kết quả theo từng idempotency key: `ĐÃ_TẠO`, `TRÙNG_LẶP`, `BỊ_TỪ_CHỐI`, `CẦN_THỬ_LẠI`; không báo cả batch thành công nếu item lỗi.
- [ ] Dùng transaction/IntegrityError handling để unique DB là lớp chống trùng cuối; có thể thêm Redis sau khi luồng DB đã đúng, không phụ thuộc Redis để bảo đảm đúng.
- [ ] Cập nhật `last_synced_at` cho Device chỉ sau khi xử lý thành công phù hợp.

### Flutter/Wear

- [ ] Tạo durable outbox local (SQLite/Drift hoặc giải pháp local DB đã chọn), thay `_pendingMeasurements` trong RAM ở `dashboard_screen.dart`.
- [ ] Ghi measurement và idempotency key ổn định xuống local DB **trước khi** báo Phone đã nhận thành công.
- [ ] Có trạng thái hàng đợi `CHỜ_GỬI`, `ĐANG_GỬI`, `ĐÃ_ĐỒNG_BỘ`, `THẤT_BẠI`; lưu số lần thử và lỗi gần nhất.
- [ ] Gửi batch có giới hạn; ánh xạ response theo key, chỉ xóa/đánh dấu synced các bản ghi đã được backend xác nhận.
- [ ] Thêm retry khi có mạng/khởi động lại app, exponential backoff và giới hạn lần thử; không sinh key mới khi retry cùng bản ghi.
- [ ] Phân biệt lỗi mạng tạm thời, 401 (refresh rồi retry một lần), 403/validation (không retry vô hạn) và lỗi server.
- [ ] Giữ rõ trạng thái dữ liệu mô phỏng trong `main_wear.dart`; không hiển thị giả lập như cảm biến y tế thật.

### File/module dự kiến

- Backend: `backend/devices/{models.py,serializers.py,views.py,urls.py,tests.py}`
- Backend: `backend/medical_records/{models.py,serializers.py,views.py,tests.py}`
- Frontend: `frontend/lib/services/watch_service.dart`
- Frontend: `frontend/lib/services/watch_sender_service.dart`
- Frontend: `frontend/lib/services/api_service.dart` (hoặc ApiClient hợp nhất ở Sprint 7)
- Frontend: service/repository outbox mới trong `frontend/lib/services/`
- Frontend: `frontend/lib/views/home/dashboard_screen.dart`, `devices_screen.dart`
- Test: `frontend/test/` và `backend/medical_records/tests.py`, `backend/devices/tests.py`

### Definition of Done

- [ ] Mất mạng, kill/restart ứng dụng rồi có mạng lại: mọi item chưa xác nhận vẫn còn và cuối cùng được đồng bộ hoặc đánh dấu thất bại có lý do.
- [ ] Gửi lại batch/cùng key hoặc gửi song song không tạo bản ghi trùng; backend trả `TRÙNG_LẶP` cho item đã có.
- [ ] Item sai không làm mất các item hợp lệ khác; kết quả từng item cập nhật đúng trạng thái local.
- [ ] Có test batch rỗng/quá cỡ, payload sai, key lặp, concurrent duplicate và retry sau timeout.
- [ ] Nếu dùng Redis, test Redis unavailable vẫn bảo toàn tính đúng nhờ unique constraint DB.

---

## Sprint 5 — Rule Engine, AI Insight/Chat, Consent BR10 và Fallback BR12

**Mục tiêu:** hoàn thiện nghiệp vụ AI ở backend; tuyệt đối không gửi dữ liệu đến Provider khi chưa có consent hợp lệ.

### Công việc

- [ ] Tạo `RuleEngine` và các rule R01–R04 theo cấu hình tài liệu; đánh dấu rõ ngưỡng là dữ liệu thử nghiệm, không phải ngưỡng chẩn đoán y khoa.
  - Gợi ý file: `backend/ai_services/rules.py`, `backend/ai_services/tests/test_rules.py`.
- [ ] Tạo `AIProviderService` có timeout, kiểm tra cấu trúc output, xử lý lỗi Provider có logging an toàn (không log PHI/token).
  - File: `backend/ai_services/provider.py`.
- [ ] Tạo `InsightService`: kiểm tra profile permission → lấy dữ liệu tối thiểu → chạy Rule trước → kiểm tra consent → gọi AI nếu có consent → lưu `AIInsight`.
- [ ] Thực hiện BR10 ở backend trước **mỗi** lời gọi AI:
  - SELF: đọc consent của Account liên kết với profile.
  - DEPENDENT chưa có account: kiểm tra consent của Owner/người giám hộ được phép quản lý profile.
  - Không dùng consent của Member/Caregiver thay consent chủ thể dữ liệu.
  - Chưa có consent: không gọi Provider; Insight được phép trả theo Rule-only nếu phù hợp hợp đồng API.
- [ ] Thực hiện BR09: chỉ gửi nhóm tuổi thay ngày sinh; bỏ tên, email, liên hệ khẩn cấp, ngày sinh đầy đủ và tài liệu; giới hạn lịch sử/context.
- [ ] Tạo API `/ai-insights/analyze`, `/ai-insights` và kiểm tra quyền hồ sơ.
- [ ] Tạo `ChatService`, Conversation/Message APIs; validate độ dài/nội dung; xác thực quyền hội thoại và profile.
- [ ] Chat fallback BR12: khi timeout/lỗi/sai schema, trả thông báo định sẵn kèm Rule cảnh báo gần nhất nếu có, có cờ fallback và nút thử lại; **không lưu fallback như Message(ASSISTANT)**.
- [ ] Insight fallback BR12: AI lỗi thì lưu/trả kết quả Rule-only (`generated_by=RULE_ONLY`); AI thành công thì `RULE_AND_AI`.
- [ ] Luôn gắn disclaimer “chỉ mang tính tham khảo, không phải chẩn đoán”; xử lý tình huống khẩn cấp theo nội dung an toàn đã duyệt.

### File/module dự kiến

- `backend/ai_services/{models.py,permissions.py,serializers.py,views.py,urls.py}`
- `backend/ai_services/{rules.py,provider.py,insight_service.py,chat_service.py}`
- `backend/accounts/{models.py,views.py,serializers.py}` (consent)
- `backend/core/urls.py`
- `backend/ai_services/tests/` và `backend/accounts/tests.py`

### Definition of Done

- [ ] Unit tests cho từng rule, dữ liệu bất thường/thiếu dữ liệu và ngưỡng cấu hình.
- [ ] Test chứng minh Provider **không được gọi** nếu consent thiếu/đã thu hồi; gồm SELF, DEPENDENT và Member/Caregiver.
- [ ] Test payload Provider không chứa định danh bị cấm; timeout, lỗi HTTP và sai schema đều kích hoạt fallback.
- [ ] Insight fallback vẫn có kết quả Rule-based; Chat fallback không được lưu như câu trả lời Assistant và cho phép retry.
- [ ] Test quyền truy cập chéo profile/conversation; phản hồi luôn có disclaimer; không log dữ liệu sức khỏe/secret.

---

## Sprint 6 — Flutter: tích hợp API và hoàn thiện SCR-01–SCR-10

**Mục tiêu:** chỉ tích hợp contract đã nghiệm thu ở backend; bỏ dữ liệu giả lập khỏi luồng nghiệp vụ đang trình bày là dữ liệu thật.

### Công việc

- [ ] Hợp nhất `ApiService` và `AuthService` thành một client/repository có base URL, timeout, lỗi typed, access/refresh token trong Secure Storage và refresh rotation.
  - File: `frontend/lib/services/api_service.dart`, `auth_service.dart`, `api_client.dart`, `api_config.dart`.
- [ ] Sửa luồng register/login/profile setup: đăng ký thành công phải thiết lập phiên hoặc yêu cầu đăng nhập rõ ràng; SCR-03 gửi đủ trường profile và chỉ chuyển tiếp khi backend xác nhận.
  - File: `frontend/lib/views/auth/login_screen.dart`, `register_screen.dart`, `profile_setup_screen.dart`.
- [ ] SCR-04: nạp profile đang chọn, measurement gần nhất, trạng thái queue và Insight gần nhất qua API.
- [ ] SCR-05: lấy danh sách Household/member thật; invite, role, share-level, dependent profile, remove/leave; hiển thị quyền theo response nhưng backend vẫn là lớp bảo vệ.
  - File: `frontend/lib/views/home/family_members_screen.dart`.
- [ ] SCR-06: quản lý Device API và hiển thị trạng thái từng queue item, retry/thu hồi thiết bị.
  - File: `frontend/lib/views/home/devices_screen.dart`.
- [ ] SCR-07: kết hợp measurement và medical records; filter, phân trang, loading/error/empty state.
  - File: `frontend/lib/views/home/health_journal_screen.dart`.
- [ ] SCR-08: thay phản hồi chat cứng bằng Conversation/Message API; hiển thị consent theo đúng chủ thể, fallback, retry và disclaimer.
  - File: `frontend/lib/views/home/ai_assistant_screen.dart`.
- [ ] SCR-09: gửi số đo thủ công tới API; không chỉ ghi `ManualMeasurementStore`; phản hồi lỗi/403 và tránh gửi nguồn thiết bị vào luồng chỉnh sửa manual.
  - File: `frontend/lib/views/home/quick_add_screen.dart`, `manual_measurement_store.dart`.
- [ ] SCR-10: dùng `/health-measurements/statistics`; bỏ thống kê chỉ đọc dữ liệu cục bộ; cho phép chọn loại chỉ số/khoảng thời gian và mở AI Chat.
  - File: `frontend/lib/views/home/health_trends_screen.dart`.
- [ ] Đồng bộ điều hướng và đăng xuất/refresh thất bại về SCR-01; kiểm tra state không giữ nhầm profile sau khi đổi tài khoản.
- [ ] Cập nhật test widget/service; giữ các widget prototype nhưng gắn nhãn demo nếu backend chưa triển khai.

### Definition of Done

- [ ] Mỗi SCR-01 đến SCR-10 ánh xạ được tới endpoint thật theo Bảng 2.46; không còn thao tác thành công giả chỉ đổi local state.
- [ ] Token được lưu an toàn; refresh retry không tạo vòng lặp; logout gọi backend và xóa token local.
- [ ] Màn hình xử lý loading, empty, offline, 401, 403, lỗi validation, timeout và retry.
- [ ] Test widget/service cho các luồng trọng yếu; không hiển thị hồ sơ gia đình giả như dữ liệu server.

---

## Sprint 7 — Kiểm thử tích hợp, bảo mật và truy vết

**Mục tiêu:** nghiệm thu yêu cầu chức năng và quy tắc nghiệp vụ trước khi đóng gói/bảo vệ.

### Công việc

- [ ] Chạy toàn bộ test backend: migrations, models, serializers, permissions, auth, APIs, batch sync, consent, AI fallback.
- [ ] Chạy Flutter analyze, unit/widget tests và kiểm thử trên emulator/thiết bị mục tiêu.
- [ ] Thực hiện acceptance tests theo TC01–TC09 trong Chương 2, gồm đăng nhập/refresh, CRUD, batch offline/retry/idempotency, AI consent/fallback và IDOR.
- [ ] Kiểm thử dữ liệu legacy, nâng cấp từ DB đã có và khôi phục backup.
- [ ] Kiểm tra CORS/ALLOWED_HOSTS/DEBUG/SECRET, HTTPS cho môi trường triển khai; xác minh token và nội dung sức khỏe không bị ghi log.
- [ ] Cập nhật README, API contract, hướng dẫn cấu hình `.env.example`, sơ đồ ERD và ma trận truy vết requirement → model/API/UI/test.
- [ ] Rà soát toàn bộ `[~]`; chuyển thành `[x]` chỉ khi có test pass và chứng cứ kiểm tra.

### Definition of Done

- [ ] Toàn bộ test chặn regression đạt; mọi lỗi còn lại được ghi rõ và không làm sai trạng thái “đã hoàn thành”.
- [ ] Hoàn thành traceability cho 8 module, 16 bảng, endpoint chính và SCR-01–SCR-10.
- [ ] TC IDOR, BR10 consent và BR12 fallback đều có test tự động, không chỉ kiểm thử thủ công.
- [ ] README và tài liệu phản ánh đúng phiên bản/code thực tế; không chứa secret hay dữ liệu người dùng thật.

---

## Ma trận nghiệm thu tổng thể

| Phạm vi | Điều kiện tối thiểu để được tính hoàn thành |
|---|---|
| 8 module | Authentication, Profile, Household, Medical Record, Health Measurement, Wear Sync, AI Insight, AI Chat đều có model/service/API/UI tương ứng theo phạm vi Chương 2 |
| 16 bảng | Đủ model/migration, PK/FK, nullable, enum, UNIQUE, index và test theo Data Dictionary |
| RBAC/IDOR | Backend kiểm tra Account → HouseholdMember ACTIVE → ProfileShare → PersonProfile; test chéo hồ sơ cho read/write/delete |
| Consent BR10 | Kiểm tra đúng chủ thể dữ liệu ở mỗi lần gọi Provider; không gọi khi thiếu/thu hồi consent |
| Fallback BR12 | Insight trả Rule-only khi AI lỗi; Chat trả phản hồi dự phòng không giả dạng Assistant message; có retry |
| Wear/Offline | Queue bền vững, trạng thái từng item, idempotency key ổn định, batch partial result và retry sau restart |
| API | Contract, auth, permission, schema, pagination, validation, status code và tests thống nhất với Chương 2 |
| Flutter SCR-01–SCR-10 | Các luồng được nối API thật; có loading/error/empty/offline; không đánh dấu demo là dữ liệu thật |

## Ghi chú về trạng thái và phạm vi

- Checklist này là lộ trình thực hiện, không phải xác nhận các tính năng đã hoàn tất.
- Ưu tiên xử lý migration account/profile và khóa UUID trước khi phụ thuộc vào ID mới trong API; thử trên bản sao dữ liệu trước khi áp dụng vào môi trường có dữ liệu cần giữ.
- Wear OS hiện dùng dữ liệu mô phỏng. Chỉ ghi “đọc cảm biến thật” là hoàn thành khi đã tích hợp và kiểm thử nguồn cảm biến thực tế; nếu MVP chỉ cần mô phỏng thì phải ghi rõ phạm vi demo.
- Redis có thể hỗ trợ blacklist/idempotency, nhưng ràng buộc PostgreSQL và xử lý cạnh tranh mới là lớp bảo đảm cuối cho tính duy nhất.
