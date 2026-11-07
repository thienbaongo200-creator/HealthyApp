# HealthyApp — Báo cáo kiểm toán kỹ thuật

**Ngày kiểm toán:** 05/11/2026 (Asia/Saigon)  
**Phạm vi:** Các tệp hiện có trong repository, bao gồm cả trạng thái chưa commit tại thời điểm kiểm toán. Chỉ rà soát tĩnh; không sửa mã nguồn, không chạy test hoặc migration.  
**Độ tin cậy:** Nhận xét dựa trên mã và cấu hình, trừ khi có ghi chú khác. Đây không phải kiểm thử xâm nhập trên production hay kiểm tra cơ sở dữ liệu đang chạy.

## Tóm tắt

Code hiện có ứng dụng Flutter, API Django/DRF, chia sẻ hồ sơ/hộ gia đình, ghi nhận chỉ số sức khỏe, CRUD hồ sơ y tế và các endpoint AI chat/đánh giá rủi ro. Hệ thống có một số kiểm soát quyền truy cập và kiểm tra đầu vào đáng kể; test hiện có cũng bao phủ nhiều luồng quan trọng. Các rủi ro lớn nhất trước khi triển khai là HTTP listener trên điện thoại không xác thực nhưng nhận dữ liệu sức khỏe từ các thiết bị khác trong LAN; cấu hình cho phép dùng HTTP khi build release; và sai lệch giữa migration, phiên bản dependency và tài liệu. Module thiết bị chưa có API/luồng sử dụng, còn Wear OS hiện chỉ tạo dữ liệu mô phỏng, chưa tích hợp cảm biến thật.

Repository có nhiều thay đổi chưa commit ở backend auth/settings/requirements và nhiều màn hình Flutter. Báo cáo đánh giá đúng trạng thái hiện tại và không chỉnh sửa các thay đổi đó. Một số ghi chú audit cũ mô tả trạng thái mã trước đây. Tệp `docs/DACN_Ngo_Quoc_Thien_Bao.docx` được nhắc trong ghi chú cũ không có trong danh sách `docs/` hiện tại, vì vậy chưa thể đối chiếu đầy đủ báo cáo đồ án với mã nguồn.

## 1. Công nghệ và môi trường

| Công nghệ | Khai báo trong repository | Quan sát ở shell hiện tại | Khớp? |
|---|---|---|---|
| Python | Không pin; README yêu cầu 3.13 | 3.13.14 | Có, theo README |
| Django | `6.1` (`backend/requirements.txt`) | 5.2.18 | **Không** |
| DRF | `3.18.0` | 3.17.1 | **Không** |
| SimpleJWT | `5.5.1` | 5.5.1 | Có |
| PostgreSQL driver | `psycopg2-binary==2.9.12` | Không cài trong Python interpreter hiện tại | **Không / interpreter này không chạy được app với PostgreSQL** |
| PostgreSQL server | Không pin; README yêu cầu 14+ | Không có `psql`/không xác định được phiên bản server | Chưa rõ |
| Google GenAI | `>=1.0,<2` | 2.30.1 | **Không; vượt giới hạn trên đã khai báo** |
| google-auth | `>=2.38,<3` | 2.62.0 | Có |
| NumPy | `>=1.26,<3` | 2.5.4 | Có |
| Flutter / Dart | README yêu cầu Flutter >=3.38.4; Dart constraint `^3.12.2` | Không tìm thấy SDK trong shell hiện tại | Chưa rõ |
| Flutter lockfile | Không có `frontend/pubspec.lock` trong danh sách hiện tại | Không áp dụng | **Không có tập dependency Flutter đã resolve để tái lập** |

Các phiên bản “đã cài” trong README phản ánh `backend/venv` của một môi trường trước đó. Python interpreter hiện tại dùng Django 5.2.18 và DRF 3.17.1, không khớp manifest. Do đó, kết quả runtime/test ở shell này sẽ không đại diện cho môi trường được khai báo. `google-genai` hiện nằm ngoài constraint `<2`; cần đồng bộ trước khi dựa vào hành vi của SDK. Chưa xác minh được PostgreSQL server và phiên bản Flutter/Dart thực tế. `asgiref`, `sqlparse`, `PyJWT`, `tzdata` được pin trực tiếp dù một số là dependency bắc cầu của Django/SimpleJWT; chỉ nên giữ pin trực tiếp nếu có ràng buộc tương thích cụ thể. Không thấy `python-decouple` được import/sử dụng. Frontend khai báo cả `http` và `dio`; cả hai đều có nơi sử dụng, nhưng tồn tại hai tầng HTTP client và logic refresh token chồng lấn.

## 2. Kiến trúc và ranh giới module

| Mức độ | Nhận xét | Bằng chứng | Đề xuất |
|---|---|---|---|
| Cao | `backend/core/permissions.py` là dịch vụ quyền dùng chung, import Profiles và Households, đồng thời xử lý consent và chia sẻ. Medical, AI và profile views cùng gọi vào đây. Cách này tập trung policy nhưng tạo coupling rộng và dễ khiến ngữ nghĩa vai trò khác nhau giữa module. | `PermissionService`, `IsProfileOwnerOrShared` | Tách policy truy cập hồ sơ thành module chuyên biệt, định nghĩa rõ năng lực như xem, ghi measurement, sửa hồ sơ y tế và dùng AI; các module sử dụng policy đó thay vì import model chéo tùy tiện. |
| Cao | `medical_records/views.py` cùng xử lý CRUD measurement, batch sync, hồ sơ y tế và lưu tài liệu. File này bao trùm nhiều miền nghiệp vụ và chứa luồng xử lý batch dài, tùy biến. | `HealthMeasurementViewSet`, `HealthMeasurementBatchCreateView`, các record viewset, `MedicalDocumentViewSet` | Tách API measurement/sync sang app tương ứng; giữ medical record/document trong miền hồ sơ y tế. |
| Trung bình | Hai cách triển khai profile API cùng tồn tại: `PersonProfileViewSet` và `ProfileListCreateView`/`ProfileDetailView` cũ. URL đưa profile API ra cả `/api/` và `/api/profiles/`; hành vi archive, serializer và create không đồng nhất. | `backend/core/urls.py`; `backend/profiles/views.py` | Chọn một route/view chuẩn và có kế hoạch ngừng alias cũ. |
| Trung bình | Flutter có `ApiService` dùng `http`, `AuthenticatedHttpClient`, cùng `core/network/api_client.dart` dùng Dio và client riêng trong `ai_service.dart`. Logic refresh/auth được triển khai ở nhiều tầng. | `frontend/lib/services/api_service.dart`, `authenticated_http.dart`, `ai_service.dart`, `frontend/lib/core/network/api_client.dart` | Dùng một API client và một bộ điều phối refresh token. |
| Trung bình | Một số screen/service gộp UI, gọi API, quản lý state và xử lý nghiệp vụ; cách giới hạn profile/measurement khác nhau giữa các màn hình. | `dashboard_screen.dart`, `ai_assistant_screen.dart`, `api_service.dart` | Chuyển orchestration sang repository/controller; giữ widget tập trung vào hiển thị. |
| Thấp | Còn file placeholder/import scaffold; app Device đã đăng ký nhưng route bị comment. | `core/urls.py`, `devices/views.py`, `health_measurements/views.py` | Xóa scaffold hoặc hoàn thiện endpoint trước khi mô tả là module được hỗ trợ. |

Rà soát tĩnh chưa xác định được vòng phụ thuộc import trực tiếp. Tuy vậy, `medical_records.views` import `accessible_profiles_for` từ module API/view của Profiles. Đây là phụ thuộc tầng không phù hợp; nên chuyển truy vấn policy này về service/domain layer của Profiles.

## 3. Cơ sở dữ liệu và migration

Các model hiện có gồm `Account`, `PasswordResetCode`, `PersonProfile`, `Household`, `HouseholdMember`, `ProfileShare`, `Device`, `HealthMeasurement`, `MedicalHistory`, `Allergy`, `Visit`, `Medication`, `LabResult`, `MedicalDocument`, `AIInsight`, `Conversation` và `Message`. Như vậy các khái niệm dữ liệu chính được yêu cầu đều có model trong code. Các app có migration, nhưng chưa kiểm tra catalog DB, trạng thái migration đang áp dụng, index thực tế hoặc chất lượng dữ liệu do không có PostgreSQL server khả dụng.

| Mức độ | Nhận xét | Bằng chứng | Đề xuất |
|---|---|---|---|
| Cao | `PersonProfile.account` và `created_by` đều có thể null độc lập; không có constraint bắt buộc ít nhất một trường sở hữu/người tạo. Profile mồ côi không thể xác định quyền hoặc consent một cách tin cậy. | `backend/profiles/models.py` | Thêm invariant ở DB/lifecycle và xác định rõ xử lý khi xóa tài khoản/chuyển quyền sở hữu. |
| Cao | `PasswordResetCode` có `attempts` nhưng không có constraint giới hạn số row cho mỗi account. `ForgotPasswordView` xóa mã cũ rồi tạo mã mới ngoài transaction; request đồng thời có thể để lại nhiều mã còn hiệu lực. | `backend/accounts/models.py`, `accounts/views.py` | Dùng transaction và invariant một mã/account; giới hạn tần suất theo email/account ngoài giới hạn theo IP. |
| Trung bình | `HealthMeasurement.idempotency_key` nullable/blank trong khi unique constraint là `(profile, idempotency_key)`. PostgreSQL cho phép nhiều NULL, nên chỉ request có key mới được chống trùng. | `backend/health_measurements/models.py` | Bắt buộc key cho luồng ingest hoặc thêm constraint có điều kiện và ghi rõ semantics cho nhập tay. |
| Trung bình | Model measurement dùng unit dạng chuỗi tự do và cột decimal chung cho nhiều loại dữ liệu. Chỉ serializer kiểm tra một số loại; ghi trực tiếp qua ORM/admin có thể vi phạm quy tắc domain. | Model/serializer `HealthMeasurement` | Chuẩn hóa kiểm tra loại/unit tại domain boundary và thêm DB constraint khi phù hợp. |
| Trung bình | `MedicalDocument.visit` và `MedicalDocument.profile` là hai FK độc lập; không bảo đảm visit thuộc cùng profile. Serializer cũng không kiểm tra quan hệ này, trong khi Medication/LabResult có kiểm tra qua serializer dùng chung. | `medical_records/models.py`, `MedicalDocumentSerializer` | Kiểm tra visit và profile cùng chủ; thêm invariant DB nếu schema cho phép. |
| Trung bình | `HouseholdMember.account` nullable, đồng thời thành viên còn được biểu diễn bằng profile. Mô hình hai định danh làm kiểm tra truy cập phức tạp và có thể tạo membership không rõ chủ thể. | `households/models.py`, `PermissionService` | Chốt account hay profile là định danh thành viên và cưỡng chế invariant đó. |
| Trung bình | Chưa thấy composite index cho các truy vấn danh sách thường dùng như `Conversation(account, profile, updated_at)` hoặc `Message(conversation, created_at)` ngoài index FK. | `ai_services/models.py` | Chỉ thêm index sau khi kiểm tra query plan và tải thực tế. |
| Trung bình | `PersonProfile` có cả đường liên kết `account` và `created_by`; khi xóa account thì profile được bỏ liên kết thay vì xóa, trong khi record con bị cascade nếu xóa profile. Quy tắc lưu giữ/quyền riêng tư chưa rõ trong code. | `profiles/models.py`, các record model | Quy định và thực thi quy trình xóa account, archive, xuất dữ liệu và purge. |
| Thấp | `Device.device_identifier` unique toàn cục thay vì theo account/profile; hiện không có API runtime để đăng ký hoặc thu hồi thiết bị. | `devices/models.py`, `core/urls.py` | Chốt phạm vi định danh và đưa registry vào sử dụng hoặc gỡ bỏ. |

Migration có trong repository nhưng chưa chạy kiểm tra migration mới hoặc migrate trên DB sạch. Ghi chú audit cũ cho rằng các model medical không có CRUD route đã lỗi thời: `medical_records/urls.py` hiện đăng ký histories, allergies, visits, medications, lab results, documents và measurements.

## 4. API và mức độ frontend sử dụng

Các nhóm endpoint hiện được mount dưới `/api`:

| Nhóm endpoint | Use case | Có frontend gọi? | Có khai báo test? |
|---|---|---:|---:|
| `/auth/register`, `/login`, `/google`, `/forgot-password`, `/reset-password`, `/profile`, `/ai-consent`, `/logout`, `/refresh` | Tài khoản, consent, xác thực | Có; luồng Google/reset còn phụ thuộc cấu hình | Có test auth; mức bao phủ từng endpoint khác nhau |
| `/token`, `/token/refresh` | Endpoint SimpleJWT tương thích | Client gọi refresh; obtain-pair có vẻ không dùng | Chưa xác nhận test endpoint obtain trực tiếp |
| `/profiles/` và alias profile dưới `/api/` | Hồ sơ cá nhân/người phụ thuộc | Có | Có |
| `/households/`, members, invitations, leave | Hộ gia đình và chia sẻ | Có | Có |
| `/medical/measurements/`, `/medical-records/measurements/`, `/health-measurements/` | Alias CRUD measurement | Có; các luồng dùng path khác nhau | Có |
| `/medical-records/{documents,histories,allergies,visits,medications,lab-results}/` | Hồ sơ y tế | Có dùng documents; chưa thấy frontend CRUD histories/allergies/visits/medications/lab-results | Có test API backend cho medical records |
| `/ai/assess-risk`, `/ai/chat`, conversations/messages | Đánh giá rủi ro, chat và lịch sử | Có | Có |
| `/devices/` và `/health/` | Endpoint thiết bị/sức khỏe cũ | Không mount; `sendHealthData()` gọi `/health/` nhưng route hiện không tồn tại | Chỉ có test model Device, không có test endpoint |

Vấn đề thiết kế API: nhiều alias trỏ tới cùng resource (`/api/medical/`, `/api/medical-records/`, `/api/health-measurements/`); profile API cũng bị trùng; endpoint SimpleJWT obtain được mở song song với custom login; status batch dùng chuỗi theo ngôn ngữ cho từng item khiến client parsing dễ vỡ. `HealthMeasurementBatchCreateView` nhận tối đa 100 item và trả HTTP 200; README vẫn ghi 500. `ProfileView.patch` gán trực tiếp gender/height/weight mà không qua serializer kiểm tra đầy đủ, nên dữ liệu số sai định dạng có thể gây lỗi server/DB. `MedicalDocumentViewSet` chỉ có list/retrieve/create/delete, không có update; README chưa nêu giới hạn này.

Thống kê tĩnh: có **80 phương thức test backend** và **15 khai báo test Flutter**. Không chạy test và không khẳng định kết quả pass/fail trong báo cáo này.

## 5. Bảo mật và kiểm soát truy cập

| Mức độ | Nhận xét | Bằng chứng / tác động | Đề xuất |
|---|---|---|---|
| **Cao** | `WatchService` bind `InternetAddress.anyIPv4` tại cổng 8080 và nhận mọi POST `/sync` không xác thực, không giới hạn kích thước, không kiểm tra schema hoặc chống phát lại. Thiết bị trong LAN có thể bơm snapshot tùy ý vào stream của điện thoại; điện thoại sau đó gửi measurement dưới account/profile đang đăng nhập. | `frontend/lib/services/watch_service.dart`; dashboard sync handler | Xác thực thông điệp từ đồng hồ (challenge/token hoặc platform channel), bind loopback nếu kiến trúc cho phép, giới hạn body/schema, kiểm tra timestamp/giá trị và từ chối ID đã dùng. |
| **Cao** | Giá trị mặc định `API_BASE_URL` là HTTP (`10.0.2.2`) và README hướng dẫn HTTP qua LAN; cấu hình Android cho phép cleartext. Nếu build release không override, credential, JWT và hồ sơ sức khỏe có thể truyền dạng plaintext. | `frontend/lib/services/api_config.dart`, Android manifest/config, README | Bắt buộc HTTPS cho release nếu không có cấu hình rõ ràng; tách flavor dev/prod và tắt cleartext ngoài môi trường phát triển. |
| **Cao** | Reset mật khẩu không thu hồi refresh token/session hiện có. Refresh token bị đánh cắp vẫn dùng được đến khi hết hạn (mặc định 7 ngày). | `ResetPasswordView`, SimpleJWT settings | Blacklist token còn hiệu lực khi reset hoặc duy trì token/session version để kiểm tra ở bước xác thực. |
| **Cao** | Google OAuth Web client ID được hard-code. Đây không phải private secret, nhưng gây khó tách môi trường/client và xoay cấu hình; audience được cố định. | `accounts/views.py: GOOGLE_WEB_CLIENT_ID` | Đưa client ID hợp lệ vào settings và khai báo rõ audience Android/Web được chấp nhận. |
| **Cao** | Ngữ cảnh sức khỏe được gửi tới Gemini khi có consent, nhưng chưa có chính sách rõ về tối thiểu hóa/ẩn danh dữ liệu, cũng chưa lưu phiên bản consent, mục đích hay audit record. Nội dung người dùng được ghép trực tiếp vào prompt và có thể chứa prompt injection. | `ai_services/services/assistant.py`, `providers/gemini.py`, `AiConsentView` | Xác định phạm vi/phiên bản consent và lưu giữ dữ liệu; giảm dữ liệu gửi đi; phân định rõ dữ liệu và lời nhắc không đáng tin cậy; công bố cách provider xử lý dữ liệu. |
| **Trung bình** | Kiểm tra upload dựa vào phần mở rộng và MIME do client cung cấp; `application/octet-stream` được chấp nhận cho cả ba phần mở rộng, không kiểm tra nội dung bytes. Tệp giả dạng PDF/ảnh có thể được lưu. | `MedicalDocumentSerializer.validate_file` | Kiểm tra magic bytes, quét malware, lưu ngoài web root và chỉ phục vụ qua download đã xác thực. |
| **Trung bình** | `file_url` là URL cũ và download redirect tới URL này. Redirect bên ngoài có thể tiết lộ IP/referrer và bỏ qua kiểm soát lưu trữ file riêng tư; giá trị DB cũ được tin cậy. | `MedicalDocumentViewSet.download` | Bỏ redirect URL ngoài cho tài liệu nhạy cảm hoặc allowlist host lưu trữ đáng tin cậy và thiết lập chính sách redirect an toàn. |
| **Trung bình** | CORS cho phép mọi origin khi `DEBUG=True`; an toàn trong phát triển cục bộ nhưng production phụ thuộc người vận hành tắt DEBUG. | `core/settings.py` | Tách settings deployment và kiểm tra cấu hình DEBUG/CORS/HTTPS khi khởi động production. |
| **Trung bình** | Access token sống 60 phút, refresh 7 ngày; có rotation và blacklist nhưng logic refresh client tồn tại ở nhiều HTTP client. | `SIMPLE_JWT`, Flutter network clients | Chọn lifetime theo rủi ro, hợp nhất refresh logic và bổ sung thu hồi session theo thiết bị. |
| **Trung bình** | Email được tra cứu không phân biệt hoa thường nhưng `EmailField(unique=True)` trên PostgreSQL phân biệt hoa thường; manager chỉ chuẩn hóa domain theo Django. Có thể tạo account email khác chữ hoa/thường. | `Account.email`, `RegisterView` | Chuẩn hóa toàn bộ email và enforce unique constraint không phân biệt hoa thường. |
| **Thấp** | Forgot-password trả thông báo chung, hash OTP, mã có thời hạn và giới hạn số lần thử; nhưng rate limit hiện dựa trên scoped throttle và có thể chủ yếu theo IP. Endpoint cho phép tối đa 5 lần/giờ theo cấu hình. | `ForgotPasswordView`, settings | Thêm khóa/giám sát theo account/email, vẫn giữ phản hồi không tiết lộ account có tồn tại hay không. |

Không thấy Django secret/API key hard-code trong settings đã kiểm tra: `SECRET_KEY` bắt buộc lấy từ môi trường và Gemini key đọc từ env. Google OAuth client ID là cấu hình public, không phải API secret. Quyền truy cập object nhìn chung được giới hạn theo profile; test hiện có kiểm tra truy cập từ người ngoài, membership pending và một số trường hợp caregiver. Audit này không chạy fuzz IDOR/BOLA trực tiếp trên API.

## 6. Đối chiếu RBAC

Code định nghĩa `OWNER`, `MEMBER`, `CAREGIVER` trên `HouseholdMember`, cùng `VIEW_ONLY` và `VIEW_AND_LOG` trên `ProfileShare`. Đây chưa phải ma trận quyền hoàn chỉnh; việc enforce được chia giữa `PermissionService`, view/serializer và các cổng consent.

| Vai trò/quyền | Hành vi đang có | Sai lệch / điểm cần chốt |
|---|---|---|
| Owner | Chủ hộ quản lý member; chủ/người tạo profile có thể sửa; được ghi measurement. | Chủ sở hữu được xác định qua `profile.account`, `created_by` hoặc membership owner trong household; chưa quy định chuyển giao/xóa. |
| Member + VIEW_ONLY | Xem profile được chia sẻ; không ghi measurement. | Sửa medical record yêu cầu `edit`, do đó VIEW_ONLY là chỉ đọc; cần xác nhận chính sách xem/tải document. |
| Member + VIEW_AND_LOG | `PermissionService` cho phép measurement-write trừ khi role là CAREGIVER. | `IsProfileOwnerOrShared` xem POST là `edit`, không phải `measurement_write`; hành vi khác nhau giữa batch và tạo measurement thường. |
| Caregiver | Có chặn caregiver xem measurement nếu owner chưa bật AI consent; role bị chặn ghi measurement. | Consent AI đang bị dùng chung như consent xem sức khỏe; cần nêu rõ consent cho chia sẻ hồ sơ hay chỉ xử lý AI. |
| Member pending | Kiểm tra quyền yêu cầu trạng thái ACTIVE. | Chỉ kiểm tra hết hạn khi người dùng phản hồi invitation; invitation hết hạn vẫn tồn tại cho đến lúc có thao tác. |

**Sai lệch ma trận RBAC:** Quyền “xem measurement” chỉ yêu cầu owner AI consent đối với người xem được gắn caregiver; các member chia sẻ khác không chịu cùng cổng consent. AI Chat và diễn giải risk yêu cầu consent để gọi LLM, nhưng rule-only risk vẫn dùng được khi không consent. Vì vậy `ai_consent` hiện có nhiều nghĩa: xử lý provider, caregiver xem dữ liệu và diễn giải AI. Nên tách policy và công bố ma trận quyền rõ ràng.

## 7. Đồng bộ Wear OS

Luồng hiện tại: Wear OS tạo dữ liệu mô phỏng → POST HTTP tới listener trên điện thoại → dashboard chuyển snapshot thành HEART_RATE/STEPS/CALORIES → queue trong RAM của điện thoại → batch API với profile/idempotency key. Backend giới hạn batch 100 và dùng unique `(profile, idempotency_key)` chống tạo row trùng. Chưa có Device API được mount, chưa gắn device (`device=None`), chưa xác thực nguồn dữ liệu và chưa tích hợp Health Services/cảm biến thật.

| Mức độ | Nhận xét | Bằng chứng | Đề xuất |
|---|---|---|---|
| Cao | Listener điện thoại không xác thực, không giới hạn body hoặc chống trùng; snapshot phát lại có thể được nhận và chuyển thành key do client sinh. | `watch_service.dart`, dashboard callback | Bảo vệ ingress và dùng event ID ổn định từ nguồn. |
| Trung bình | Queue offline chỉ nằm trong RAM; mất khi app bị đóng/restart. Chưa có trạng thái bền vững hoặc exponential backoff. | Queue trong `dashboard_screen.dart` | Lưu bền vững item pending/acknowledged/rejected; retry có giới hạn, exponential backoff và jitter. |
| Trung bình | Wear gửi từng snapshot lên phone; chưa thấy timer/threshold gom batch tại phone. Batch API tối đa 100 item. | `main_wear.dart`, dashboard | Quy định ngưỡng flush và chia request theo giới hạn 100. |
| Trung bình | Dữ liệu Wear được xác nhận là mock, nhưng UI có thể khiến người dùng tưởng đó là phép đo thật. | `mock_health_data_service.dart`, `main_wear.dart` | Gắn nhãn dữ liệu mô phỏng trên UI và metadata lưu trữ. |
| Trung bình | Client có thể truyền `source` trong batch serializer và server lưu giá trị đó mà không ép thành `WEAR_OS`; người dùng đã đăng nhập có thể tự gắn nhãn nguồn. | `HealthMeasurementFieldsSerializer.source`, batch view | Gán source ở server theo luồng ingest đã xác thực; từ chối nguồn tự khai báo. |

Ghi chú cũ cho rằng chưa có batch là không còn đúng; batch và idempotency phía backend đã có. Tuy vậy, độ bền queue và xác thực nguồn vẫn còn thiếu.

## 8. Module AI

Thành phần AI gồm `RiskRuleEngine` xác định kết quả theo quy tắc, Gemini provider qua `AssistantProvider`, local fallback, bảng `AIInsight`, bảng conversation/message, endpoint risk/chat và lịch sử. Consent được kiểm tra trước khi chat qua `authorized_profile`; risk rule chạy không cần consent, còn phần diễn giải tùy chọn chỉ gửi summary khi có consent. Chat chỉ lưu phản hồi provider thành công; fallback trả HTTP 503 và không lưu.

| Mức độ | Nhận xét | Bằng chứng | Đề xuất |
|---|---|---|---|
| Cao | `AIInsight` không có serializer, endpoint hoặc luồng ghi; kết quả risk tạo theo request và không lưu thành insight. Model hiện là schema chưa dùng. | `ai_services/models.py`, `ai_services/views.py` | Triển khai vòng đời insight (tạo, dismiss, provenance) hoặc xóa model chưa dùng và mô tả risk là on-demand. |
| Cao | AI consent là một boolean/timestamp có thể thay đổi, không ghi policy/version/provider/purpose. Tắt consent không ảnh hưởng conversation đã lưu. | `Account.ai_consent`, `AiConsentView` | Lưu lịch sử/phạm vi/phiên bản consent; định nghĩa lưu giữ và xóa dữ liệu sau khi thu hồi. |
| Trung bình | Risk engine lấy 50 mẫu nhịp tim/BP gần nhất không giới hạn thời gian, trong khi context summary chỉ lấy 30 ngày. Dữ liệu cũ có thể ảnh hưởng risk hiện tại; chỉ cần BP cũ cũng khiến kết quả được xem là đủ dữ liệu. | `risk_engine.py` và `build_health_context()` | Đồng bộ cửa sổ dữ liệu và quy định freshness theo loại measurement. |
| Trung bình | Ngưỡng được hard-code (`120 bpm`, 6.000 bước, 300 kcal), không xét tuổi, bệnh lý, đơn vị hay nguồn lâm sàng. | `RiskRuleEngine` | Gắn nhãn heuristic giáo dục, ghi nguồn/ngữ cảnh và xác nhận chuyên môn; không trình bày như chẩn đoán y tế. |
| Trung bình | `build_health_context()` lấy tối đa 100 row rồi tạo prompt; chưa có đánh giá chính thức về tối thiểu hóa dữ liệu. Prompt injection từ câu hỏi người dùng chưa được xử lý ngoài chỉ dẫn văn bản. | `assistant.py`, Gemini provider | Giữ ranh giới dữ liệu có cấu trúc, giới hạn độ dài input và bổ sung đánh giá an toàn. |
| Trung bình | `generate_reply` chỉ bắt `ProviderError`; lỗi bất ngờ khác có thể trả 500 thay vì fallback có kiểm soát. | `assistant.py`, `gemini.py` | Chuẩn hóa lỗi provider/network thành typed errors và xử lý timeout rõ ràng. |
| Thấp | `numpy` chỉ được dùng để tính trung bình đơn giản, làm tăng dependency triển khai. | `assistant.py` | Dùng `statistics.mean` nếu không có nhu cầu NumPy khác. |

Không thấy prompt file bị bỏ quên; prompt Gemini được viết trực tiếp trong `providers/gemini.py`. Fallback đã có và test unit hiện có bao phủ. Kiểm soát hallucination/rò rỉ dữ liệu hiện chủ yếu dựa vào prompt; chưa thấy output safety filter, bộ đánh giá AI chính thức hoặc chính sách lưu giữ dữ liệu của provider.

## 9. Chất lượng code và code không dùng

| File/khu vực | Nhận xét | Hướng xử lý |
|---|---|---|
| `backend/medical_records/views.py` | Logic measurement API nằm trong app medical records, trong khi `health_measurements/views.py` là placeholder. | Chuyển API measurement chuẩn về `health_measurements`. |
| `backend/core/urls.py` | `/api/` và `/api/profiles/` cùng include profile URLs; `/api/medical/` và `/api/medical-records/` cũng trùng. | Chọn route chuẩn và có thời hạn ngừng alias. |
| `frontend/lib/services/api_service.dart` | `sendHealthData()` gọi `/api/health/` chưa mount; còn path batch cũ bên cạnh path đang dùng. | Xóa method mồ côi hoặc mount endpoint tương thích đã được tài liệu hóa. |
| `frontend/lib/core/network/api_client.dart`, `data/repositories/health_repository.dart`, `presentation/blocs/health_ai/*` | Tầng Dio/repository/BLoC tồn tại song song với screen gọi `AiApiService` và static `ApiService`; có dấu hiệu kiến trúc dở dang/chưa dùng hết. | Xác nhận call graph, xóa đường đi chết hoặc chuyển toàn bộ screen sang một repository architecture. |
| `backend/devices/views.py`, `backend/health_measurements/views.py` | Còn placeholder/import mặc định; route Device bị comment. | Xóa scaffold hoặc triển khai API dự kiến. |
| `frontend/lib/views/home/ai_chat_screen.dart` | Có màn hình chat thứ hai bên cạnh `ai_assistant_screen.dart`; tìm kiếm tĩnh chưa xác định được có thể điều hướng tới màn hình này không. | Kiểm tra navigation rồi xóa hoặc đánh dấu prototype. |
| `frontend/lib/services/api_service.dart` | Singleton/service xử lý auth, token, profile, measurement, household và document; phạm vi trách nhiệm rộng. | Tách repository theo domain sau khi hợp nhất transport. |
| `backend/accounts/serializers.py` | `RegisterSerializer` lặp validation đăng ký, nhưng `RegisterView` tự xử lý thủ công. | Dùng một serializer/service để tránh lệch quy tắc. |
| `backend/core/settings.py` | Biến SMTP `MAILERS` được gán nhưng Django dùng các `EMAIL_*`; `MAILERS` có vẻ không được dùng. | Xóa biến hoặc cấu hình đúng các email setting thực tế. |
| `README.md` | Ví dụ payload login mâu thuẫn (`email` và `account`), batch max cũ (500 thay vì 100), hướng dẫn chạy bị lặp và bảng version cũ. | Cập nhật tài liệu theo contract hiện tại và giữ một hướng dẫn chạy chuẩn. |

Không thấy cấu hình formatter/linter riêng cho Python. Flutter có `analysis_options.yaml`, nhưng không có SDK nên không khẳng định kết quả analyzer. Magic number tập trung ở ngưỡng risk, timeout/retry, cổng listener, dung lượng upload và batch cap; nên gom thành hằng số/cấu hình có tài liệu. Chưa có đủ bằng chứng để kết luận widget bị duplicate trên diện rộng, nhưng `ai_chat_screen.dart` và `ai_assistant_screen.dart` cùng mục đích.

## 10. Kiểm toán test

Thống kê tĩnh: **80 phương thức test backend**, **15 khai báo test Flutter**. Các vùng test gồm account/auth, cấu hình JWT, quyền profile/household, medical-record endpoint/upload, CRUD/batch/idempotency measurement, AI consent/fallback/history và Flutter refresh/profile selection/widget. Không chạy test và không có report coverage trong checkout; do đó không thể đưa ra phần trăm coverage có căn cứ. Coverage đo được là **chưa xác định (0% được đo)**, không có nghĩa là “0% code được test”.

Các khoảng trống test có khả năng cần bổ sung theo đối chiếu code/test: cạnh tranh khi tạo OTP reset, thu hồi JWT cũ khi reset mật khẩu, chuẩn hóa email, lỗi gửi mail/cấu hình SMTP, cấu hình audience/client ID Google, xác thực/giới hạn body/chống phát lại listener, giả mạo source trong batch, duplicate batch đồng thời trên PostgreSQL thật, kiểm tra document và visit cùng profile, kiểm tra magic bytes PDF, tính nhất quán API alias, chặn cleartext ở release, và phục hồi queue sau restart/retry. Test declaration chỉ cho thấy có ý định kiểm tra; không chứng minh test đã pass.

## 11. Đối chiếu tài liệu

Tài liệu hiện có: `README.md`, `PROJECT_PLAN.md`, `CHECKLIST.md`, `docs/MIGRATION_AND_BACKUP_PLAN.md`, `alignment/final/{audit_summary.md,spec_conflicts.md,decision_list.md,spec_trace.csv}`. Không có thesis `.docx`, nguồn/ảnh ERD hoặc Data Dictionary riêng trong danh sách hiện tại. Vì vậy, việc đối chiếu từng chương, sơ đồ với schema và FR/UC/TC bị **giới hạn do thiếu tài liệu nguồn**; ghi chú audit cũ chỉ được xem là bối cảnh, không coi là bằng chứng đã xác nhận.

Các sai lệch README xác minh được:

1. Batch max ghi 500, trong khi code giới hạn 100 (`HealthMeasurementBatchSerializer`).
2. Login được mô tả hai lần với key khác nhau (`email` và `account`); backend chấp nhận cả hai nên chạy được nhưng contract không thống nhất.
3. Bảng technology mô tả version `backend/venv` của môi trường cũ, không phải shell hiện tại; cần ghi ngày hoặc bỏ.
4. Bảng API thiếu Google login, password reset, consent, chia sẻ household/profile, AI và medical record routes.
5. README mô tả profile API nhưng code mở cả `/api/` lẫn `/api/profiles/`.
6. README nói measurement lưu `device_id`, `heart_rate`, `steps`, `calories`, `activity_state`; model backend lưu các row typed (`measurement_type`, `value`, `unit`, timestamps) và sync không gắn Device (`device=None`).
7. Code hiện mount CRUD medical-history/allergy/visit/medication/lab-result, trái với ghi chú alignment cũ cho rằng chưa có.
8. `audit_report.md` và `alignment/final/audit_summary.md` phản ánh code/test cũ, có endpoint table, batch semantics, availability tài liệu và security findings đã lỗi thời. Không dùng làm bằng chứng release hiện tại.

Không thể đối chiếu `spec_trace.csv` và `spec_conflicts.md` với thesis do thiếu tài liệu được dẫn. Các khẳng định về mã rule Chương 2, field Data Dictionary và mapping TC cần để trạng thái “chưa xác minh” đến khi có tài liệu nguồn.

## 12. Kết luận và điểm số

### A. Critical — cần xử lý trước bảo vệ hoặc triển khai bên ngoài

Rà soát tĩnh chưa xác nhận được lỗ hổng backend có thể khai thác công khai trên Internet. Tuy vậy, trước khi triển khai bên ngoài cần khắc phục listener phone không xác thực và bắt buộc HTTPS cho release. Đây là blocker vì dữ liệu sức khỏe và token nhạy cảm.

### B. High — ưu tiên cao

1. Đồng bộ dependency với `requirements.txt`: Django 5.2 so với 6.1, DRF 3.17 so với 3.18, GenAI 2.x so với `<2`, và thiếu PostgreSQL driver trong interpreter đang dùng.
2. Thu hồi refresh token khi đổi/reset mật khẩu.
3. Xác định vòng đời sở hữu profile/consent và chuẩn hóa tính duy nhất của email.
4. Tách AI consent khỏi quyền chia sẻ dữ liệu sức khỏe cho caregiver; tài liệu hóa ma trận vai trò/năng lực.
5. Triển khai hoặc gỡ các cam kết/module chưa dùng như `AIInsight` và Device registry.

### C. Medium — nên xử lý

1. Kiểm tra nội dung bytes khi upload, kiểm tra document/visit cùng profile và bảo vệ phân phối tài liệu riêng tư.
2. Làm queue Wear bền vững, có retry/backoff giới hạn và ingress đồng hồ xác thực/idempotent.
3. Hợp nhất profile/measurement routes, serializer, status contract và API client.
4. Đồng bộ độ mới dữ liệu risk với yêu cầu sản phẩm; nêu rõ giới hạn sàng lọc.
5. Cập nhật README và audit cũ; ghi nhận phiên bản DB/môi trường có thể tái lập.

### D. Low — cải thiện sau

1. Xóa scaffold/import backend không dùng và các dependency pin dư thừa sau khi xác nhận không cần.
2. Hợp nhất serializer đăng ký và các màn hình chat Flutter.
3. Chỉ thêm index truy vấn sau khi đo query plan thực tế.

### E. Điểm kiến trúc (10 là tốt nhất)

| Hạng mục | Điểm | Căn cứ |
|---|---:|---|
| Kiến trúc | 6/10 | Có module lớn rõ ràng nhưng view import chéo tầng, trùng route/view và nhiều network stack Flutter. |
| Bảo mật | 4/10 | Có profile scoping, JWT rotation, phản hồi reset chung, kiểm tra size/type upload; nhưng listener LAN không xác thực, cleartext mặc định và reset token chưa thu hồi là rủi ro lớn. |
| Database | 6/10 | Có UUID/FK/unique constraint và lịch sử migration; invariant ownership/visit/idempotency và trạng thái DB thật còn thiếu/chưa xác minh. |
| API Design | 5/10 | Có DRF endpoint và batch idempotency; nhưng alias trùng, tài liệu/payload/status không nhất quán và profile patch chưa validate. |
| AI Module | 5/10 | Có provider abstraction, rule deterministic, consent gate và fallback; AIInsight chưa dùng, consent quá chung, quản trị context/ngưỡng còn hạn chế. |
| Tài liệu | 4/10 | Có README và alignment artifacts nhưng contract/version đã cũ; thiếu thesis/ERD làm giảm traceability. |
| Khả năng bảo trì | 5/10 | Có test và app module; client/service trùng, file lớn, endpoint chết và thay đổi chưa commit làm tăng nguy cơ lệch. |

**Đánh giá chung:** phù hợp làm prototype đồ án với nhiều luồng đã triển khai; chưa nên mô tả là hệ thống xử lý dữ liệu y tế sẵn sàng production cho đến khi xử lý các khoảng trống bảo mật, dependency, consent và khả năng tái lập. Điểm số chỉ dựa trên bằng chứng trong repository, không đánh giá chất lượng runtime.

## Giới hạn xác minh

- Không chạy test, analyzer, migration, API live hoặc truy vấn database.
- Shell có Python 3.13.14; các phiên bản package quan sát được ở §1. Không tìm thấy Flutter/Dart SDK hay PostgreSQL server.
- Không có môi trường production, secret store, cấu hình hạ tầng, ERD/Data Dictionary hoặc thesis DOCX được nhắc đến.
- Worktree đã có thay đổi trước audit; báo cáo phản ánh trạng thái quan sát được và không quy kết thay đổi/lỗi cho tác giả hay commit cụ thể.
