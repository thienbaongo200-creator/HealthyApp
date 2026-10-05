# Checklist tiến độ Healthy App

> Cập nhật theo trạng thái source code và tài liệu hiện có trong project tại ngày 15/09/2026.
>
> - `[x]` Đã hoàn thành
> - `[~]` Đang làm / hoàn thành một phần / cần bổ sung hoặc kiểm chứng
> - `[ ]` Chưa làm

## Tuần 3 (07/09 - 13/09/2026)

### Phân tích yêu cầu và thiết kế hệ thống

- [x] Xác định mục tiêu và phạm vi MVP trong `PROJECT_PLAN.md`.
- [x] Xác định công nghệ chính: Django, DRF, PostgreSQL, Flutter, Wear OS và JWT.
- [~] Phân tích yêu cầu chức năng: đã có mô tả trong kế hoạch và README, nhưng chưa có tài liệu phân tích yêu cầu riêng.
- [~] Thiết kế kiến trúc tổng thể Watch OS -> Flutter -> Django Backend: đã được mô tả trong README, cần tiếp tục đồng bộ với source hiện tại.
- [~] Thiết kế kiến trúc API: đã có các route auth và medical, nhưng README, frontend và backend còn lệch endpoint `/api/health/` và `/api/medical/`.
- [ ] Hoàn thiện ERD cơ sở dữ liệu thành tài liệu hoặc sơ đồ riêng.
- [~] Hoàn thiện nội dung đề cương: đã có file `ĐCCN_Ngô Quốc Thiên Bảo_Copy.docx`, chưa có bằng chứng đã hoàn thiện/duyệt.
- [x] Xác nhận đã nộp đề cương: chưa có biên nhận hoặc tài liệu xác nhận trong project.

## Tuần 4 (14/09 - 20/09/2026)

### Củng cố bảo mật và Backend Auth

- [x] Hoàn thiện cơ cấu folder cơ bản cho Django backend (`core`, `accounts`, `medical_records`, `health_metrics`) và Flutter frontend (`views`, `services`, `widgets`).
- [x] Cấu hình Django REST Framework.
- [x] Cấu hình JWT authentication mặc định cho DRF.
- [x] Triển khai đăng ký tài khoản.
- [x] Triển khai đăng nhập bằng username hoặc email.
- [x] Phát hành JWT Access Token khi đăng nhập.
- [~] Phát hành JWT Refresh Token: backend đã tạo và trả refresh token.
- [~] Hoàn thiện endpoint refresh token: backend có `/api/auth/token/refresh/`, nhưng chưa có test đầy đủ và chưa tích hợp end-to-end với Flutter.
- [~] Cấu hình rotation và blacklist refresh token: backend đã bật `ROTATE_REFRESH_TOKENS` và `BLACKLIST_AFTER_ROTATION`, chưa có test xác nhận hành vi.
- [ ] Triển khai logout/revoke refresh token rõ ràng.
- [~] Cấu hình biến môi trường: có `.env.example` và một phần database đọc từ `os.getenv()`.
- [ ] Đọc `SECRET_KEY` từ biến môi trường thay vì hardcode.
- [ ] Đọc `DEBUG` và `ALLOWED_HOSTS` từ biến môi trường.
- [ ] Loại bỏ fallback thông tin database nhạy cảm hardcode (`admin123`).
- [~] Cấu hình CORS: đã cài thư viện, thêm app và middleware.
- [ ] Thay `CORS_ALLOW_ALL_ORIGINS = True` bằng allowlist origin theo môi trường.
- [ ] Đọc cấu hình CORS từ biến môi trường.
- [x] Áp dụng `AllowAny` cho register/login.
- [x] Áp dụng `IsAuthenticated` cho profile và các API cần đăng nhập.
- [~] Phân quyền theo dữ liệu sở hữu: measurement được lọc theo user hiện tại.
- [ ] Bổ sung custom permission hoặc role/group cho phân quyền user/admin cơ bản.
- [ ] Bổ sung test anonymous request phải nhận `401`.
- [ ] Bổ sung test ngăn user truy cập dữ liệu của user khác.
- [ ] Bổ sung test refresh token, rotation và blacklist.
- [~] Hoàn thiện Flutter refresh flow: hiện frontend chỉ giữ access token trong bộ nhớ, chưa lưu refresh token và chưa tự refresh khi access token hết hạn.

## Tuần 5 (21/09 - 27/09/2026)

### Backend Core

- [ ] Tạo và hoàn thiện app `medical_records` theo phạm vi Tuần 5.
- [~] Xây dựng model `PersonProfile`: đã có model cơ bản và signal tự tạo profile.
- [ ] Xây dựng model `Household`.
- [ ] Xây dựng model `HouseholdMember`.
- [~] Hoàn thiện các API cơ bản cho profile và gia đình.
- [ ] Bổ sung migration đầy đủ cho các model Tuần 5.
- [ ] Bổ sung test cho profile, household và household member.

## Tuần 6 (28/09 - 04/10/2026)

### Các model hồ sơ sức khỏe

- [ ] Xây dựng model `Visit`.
- [ ] Xây dựng model `LabResult`.
- [ ] Xây dựng model `Medication`.
- [ ] Xây dựng model `MedicalDocument`.
- [~] Xây dựng model `HealthMeasurement`: đã có model cơ bản gồm device, thời gian đo, idempotency key và chỉ số sức khỏe.
- [ ] Hoàn thiện migration dữ liệu cho toàn bộ model Tuần 6.
- [ ] Bổ sung ràng buộc, validation và quan hệ dữ liệu đầy đủ.
- [ ] Bổ sung test model và migration.

## Tuần 7 (05/10 - 11/10/2026)

### API Django REST Framework

- [~] Xây dựng serializer cho health measurement.
- [~] Xây dựng ViewSet cho health measurement.
- [ ] Xây dựng đầy đủ serializer và ViewSet cho profile, family và medical records.
- [ ] Xây dựng API cho medical documents và measurements theo thiết kế thống nhất.
- [ ] Áp dụng phân trang.
- [ ] Áp dụng filtering và tìm kiếm.
- [~] Hỗ trợ `idempotency_key`: đã có unique constraint và batch `update_or_create` ở measurement.
- [ ] Kiểm thử đầy đủ các API, phân trang, filtering và idempotency.

## Tuần 8 (12/10 - 18/10/2026)

### Refactor Flutter App

- [~] Tổ chức frontend theo các nhóm feature hiện có: auth, home, services và widgets.
- [~] Có `ApiService` cho register, login và update profile.
- [ ] Hoàn thiện `AuthService` riêng theo kiến trúc feature-based.
- [ ] Tích hợp secure storage cho access token và refresh token.
- [ ] Hoàn thiện refresh token flow phía Flutter.
- [ ] Hoàn thiện luồng Profile.
- [ ] Hoàn thiện luồng Family.
- [ ] Hoàn thiện luồng Medical Records.
- [ ] Bổ sung test cho các luồng Flutter chính.

## Tuần 9 (19/10 - 25/10/2026)

### Tích hợp Wear OS

- [~] Có `WatchService` và `WatchSenderService` cho luồng Watch - Phone.
- [~] Có cơ chế gửi dữ liệu sức khỏe cơ bản từ frontend.
- [ ] Đọc dữ liệu cảm biến Wear OS thật.
- [ ] Chuẩn hóa timestamp cho dữ liệu đồng bộ.
- [ ] Bổ sung và kiểm tra `device_id` trong toàn bộ luồng sync.
- [ ] Triển khai offline queue.
- [ ] Triển khai batch sync hoàn chỉnh.
- [ ] Triển khai retry khi mất kết nối.
- [~] Hoàn thiện xử lý `idempotency_key` end-to-end.
- [ ] Kiểm thử Watch OS - Phone - Backend.

## Tuần 10 (26/10 - 01/11/2026)

### Tích hợp AI Service

- [ ] Xây dựng Rule-based Engine.
- [ ] Tích hợp AI Provider.
- [ ] Xây dựng model và API `AIInsight`.
- [ ] Xây dựng AI Chat cơ bản.
- [ ] Bổ sung cảnh báo mang tính tham khảo, không chẩn đoán bệnh.
- [ ] Kiểm thử AI Service với dữ liệu sức khỏe mẫu.

## Tuần 11 (02/11 - 08/11/2026)

### Kiểm thử tính năng và luồng chính

- [~] Có test cơ bản cho register, login và cập nhật profile.
- [ ] Kiểm thử đầy đủ access token và refresh token.
- [ ] Kiểm thử phân quyền và chống truy cập chéo dữ liệu.
- [ ] Kiểm thử profile, family và medical records.
- [ ] Kiểm thử dữ liệu sức khỏe.
- [ ] Kiểm thử Wear OS.
- [ ] Kiểm thử offline queue, batch sync, retry và idempotency.
- [ ] Kiểm thử AI và AI Chat.
- [ ] Sửa lỗi endpoint `/api/health/` không được đăng ký trong URL hiện tại.
- [ ] Đồng bộ lại README, frontend, backend và test theo endpoint chính thức.
- [ ] Bổ sung test regression cho các lỗi đã sửa.

## Tuần 12 (09/11 - 15/11/2026)

### Hoàn thiện giao diện và báo cáo kiểm thử

- [ ] Hoàn thiện giao diện Flutter cho các luồng MVP.
- [ ] Hoàn thiện trạng thái loading, lỗi, empty state và mất kết nối.
- [ ] Tổng hợp kết quả kiểm thử.
- [ ] Viết các chương nội dung chính của báo cáo.
- [ ] Đối chiếu giao diện với phạm vi MVP đã duyệt.

## Tuần 13 (16/11 - 20/11/2026)

### Hoàn thiện báo cáo và đóng gói

- [ ] Hoàn thiện báo cáo đồ án.
- [ ] Hoàn thiện `README.md` theo trạng thái triển khai thực tế.
- [ ] Hoàn thiện tài liệu phân tích và thiết kế.
- [ ] Cập nhật tài liệu API.
- [ ] Đóng gói mã nguồn và loại bỏ file build/cache/secret khỏi package.
- [ ] Kiểm tra `.gitignore` và các file cấu hình trước khi chia sẻ.

## Tuần 14 (23/11 - 28/11/2026)

### Kiểm tra tổng thể

- [ ] Rà soát toàn bộ chức năng MVP.
- [ ] Chạy kiểm thử tổng thể backend và frontend.
- [ ] Kiểm tra migration và dữ liệu mẫu.
- [ ] Kiểm tra cấu hình production, secret và CORS.
- [ ] Kiểm tra hiệu năng và độ ổn định của các luồng chính.
- [ ] Sửa các lỗi còn lại.
- [ ] Hoàn thiện định dạng báo cáo theo chuẩn của Khoa CNTT.

## Tuần 15 (30/11 - 06/12/2026)

### Bảo vệ đồ án

- [ ] Chuẩn bị slide và nội dung trình bày.
- [ ] Chuẩn bị kịch bản demo hệ thống.
- [ ] Tham gia báo cáo trước Hội đồng đồ án chuyên ngành.
- [ ] Ghi nhận và phân loại góp ý từ Hội đồng.
- [ ] Chỉnh sửa hệ thống, báo cáo hoặc tài liệu theo góp ý.
- [ ] Hoàn tất bản nộp cuối cùng.

## Ghi chú kiểm tra hiện tại

- `python manage.py check`: đạt, không phát hiện lỗi cấu hình Django.
- Backend test hiện tại: 5 test đạt, 2 test thất bại vì test `health_metrics` gọi `/api/health/` nhưng route này chưa được include trong `core/urls.py`.
- `flutter analyze`: đạt, không phát hiện lỗi phân tích Dart.
- Cần cập nhật các checkbox sau khi có bằng chứng triển khai hoặc kiểm thử tương ứng.
