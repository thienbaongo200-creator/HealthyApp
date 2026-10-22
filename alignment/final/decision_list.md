# Danh sách quyết định cần duyệt

Các ước lượng là khoảng công sức kỹ thuật, gồm triển khai, kiểm thử và dự phòng; không phải số liệu đo. Ước lượng sẽ được điều chỉnh nếu khảo sát sâu phát hiện phụ thuộc/migration. Chưa có hạng mục nào được triển khai trong giai đoạn 1.

## P0 — Sai khác nhỏ, tác động trực tiếp tới tiêu chí kiểm thử

### D01 — Đăng ký tài khoản và mã lỗi

- **Đặc tả:** UC02/Bảng 2.7 và TC01.2 yêu cầu xác nhận mật khẩu, kiểm tra độ mạnh, email trùng trả 409; Bảng 2.41 ghi POST `/auth/register`.
- **Hiện trạng:** `backend/accounts/views.py:29-64` không kiểm tra `password_confirm`, dùng kiểm tra mật khẩu tối thiểu 6 ký tự và trả 400 khi email trùng. `RegisterSerializer` có kiểm tra xác nhận nhưng view không dùng serializer. Flutter có biểu mẫu xác nhận.
- **A:** Dùng serializer chuẩn, password validation của Django, giữ khớp với giao diện, duplicate trả 409. **2–4 giờ.**
- **B:** Chỉ bổ sung kiểm tra confirmation/độ mạnh và 409 trong view hiện có. **1–2 giờ.**
- **C:** Không sửa; đánh dấu UC02/TC01.2 chưa đạt và sửa báo cáo sau khi tác giả quyết định. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Thấp; cần rà soát giao diện và test đăng ký hiện có.
- **Ảnh hưởng Chương 3:** UC02, FR01; TC01.2; phần tài khoản ở 3.2/3.3 và phụ lục kết quả.
- **Khuyến nghị:** B, ít thay đổi nhất để khớp chính xác các mã trạng thái và luồng đã khóa.

### D02 — Thời hạn JWT theo CF1/CF2 và refresh khi 401

- **Đặc tả:** Bảng 2.50 CF1 = 60 giây, CF2 = 1 ngày; refresh rotation/blacklist; UC01/UC07 luồng thay thế và Bảng 2.45 yêu cầu refresh khi gặp 401.
- **Hiện trạng:** `backend/core/settings.py:94-104` đặt Access 60 phút, Refresh 7 ngày; rotation/blacklist bật. `frontend/lib/services/api_service.dart` không xử lý refresh tổng quát; `frontend/lib/services/ai_service.dart` gọi HTTP riêng.
- **A:** Đặt cấu hình sản xuất/kiểm thử riêng theo CF1/CF2 và thống nhất interceptor/refresh toàn bộ API Flutter. **3–6 giờ.**
- **B:** Chỉ khớp CF1/CF2 ở settings kiểm thử và hoàn thiện refresh cho client đang dùng. **2–4 giờ.**
- **C:** Không sửa; ghi khác biệt, không tuyên bố TC02.1/02.2 đạt. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Cần xác định override thử nghiệm, tránh làm token hết hạn quá nhanh ở môi trường dùng thường ngày; không cần migration.
- **Ảnh hưởng Chương 3:** Bảng CF1/CF2, mô tả xác thực; TC02.1/02.2 và yêu cầu NFR01.
- **Khuyến nghị:** A, tách rõ mặc định và override kiểm thử để không nhầm 60 giây với 60 phút.

### D03 — Bất biến nguồn WEAR_OS và batch status

- **Đặc tả:** BR06/BR07, UC06, TC04.3/05.3/05.4; Bảng 2.41 quy định batch trả 200 và bản ghi WEAR_OS không sửa/xóa thủ công.
- **Hiện trạng:** `backend/health_measurements/serializers.py` cho phép client truyền `source`/`device`; `HealthMeasurementViewSet` là ModelViewSet không chặn update/delete theo source. `backend/medical_records/views.py:145-270` giới hạn lô 100 nhưng trả 201 khi toàn bộ bản ghi hợp lệ.
- **A:** Chặn giả nguồn/ghi đè/xóa WEAR_OS ở serializer và view, chuẩn hóa batch status theo hợp đồng. **3–5 giờ.**
- **B:** Chỉ khóa update/delete và sửa status trả về; không thay đổi giao thức tạo dữ liệu Wear. **1.5–3 giờ.**
- **C:** Không sửa; ghi rõ chênh lệch và không tuyên bố TC04.3/05.4 đạt. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Thấp-trung bình; phải giữ nguyên idempotency và phản hồi từng phần.
- **Ảnh hưởng Chương 3:** Đồng bộ, tính toàn vẹn; TC04.3/05.3/05.4.
- **Khuyến nghị:** A vì hiện trạng cho phép client gán nguồn thiết bị và sửa dữ liệu vốn được thiết kế bất biến.

### D04 — Consent cho AI Insight

- **Đặc tả:** BR10, UC08, Bảng 2.44: thiếu consent thì không gọi provider và trả Rule-based RULE_ONLY; Bảng 2.41 có endpoint analyze.
- **Hiện trạng:** `backend/ai_services/views.py:15-35` yêu cầu consent trong `authorized_profile` và từ chối 403; `RiskRuleEngine` trả dữ liệu nhưng chưa được biến thành bản ghi insight.
- **A:** Tách quyền truy cập khỏi consent; tính Rule trước, chỉ gọi provider khi consent hợp lệ, lưu/đánh dấu RULE_ONLY hoặc RULE_AND_AI đúng schema. **8–14 giờ** (phụ thuộc D08).
- **B:** Trả kết quả Rule-only khi không consent, chưa persist Insight/không gọi Gemini cho Insight. **3–5 giờ.**
- **C:** Không hiện thực AI Insight; ghi “đã thiết kế, chưa hiện thực”, không báo TC08.1–08.3 Pass. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** A cần quyết định về schema AIInsight; nếu cần migration, dừng phần migration để xin duyệt theo quy định.
- **Ảnh hưởng Chương 3:** UC08, BR10/BR12, TC08.1–08.3; nhóm AI Insight ở 3.2/3.3.
- **Khuyến nghị:** B trước nếu chưa duyệt migration; đây là cách tối thiểu để đáp ứng rõ hành vi no-consent trong UC08.

### D05 — Fallback AI Chat không được lưu như phản hồi hợp lệ

- **Đặc tả:** BR12, UC09 và Bảng 2.44 yêu cầu lỗi provider trả fallback riêng, có cờ fallback, cho thử lại và không lưu như Message ASSISTANT.
- **Hiện trạng:** `backend/ai_services/services/assistant.py:50-73` fallback sang LocalRuleProvider; `backend/ai_services/views.py:38-75` sau đó luôn lưu phản hồi với role ASSISTANT. Response không có cờ fallback. Gemini timeout hiện 10 giây, không phải CF7 30 giây.
- **A:** Trả contract fallback có flag/message retry, không lưu assistant fallback; kiểm thử provider error/timeout/schema. **4–7 giờ.**
- **B:** Phân biệt provider fallback bằng metadata response và không lưu tin nhắn fallback. **2–4 giờ.**
- **C:** Không sửa; ghi Chat fallback chưa hiện thực đúng đặc tả. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Trung bình; cần xử lý lịch sử hội thoại sau lỗi và tránh làm UI hiển thị success-shaped response.
- **Ảnh hưởng Chương 3:** BR12, TC07.3; bảng kết quả AI Chat và hạn chế.
- **Khuyến nghị:** A, vì điều kiện an toàn yêu cầu không trình bày nội dung fallback như câu trả lời AI thật.

### D06 — Ma trận quyền household/Caregiver

- **Đặc tả:** BR04/BR05, Bảng 2.42/2.47, UC04/UC06; shared Caregiver read-only, Member có VIEW_AND_LOG, thành viên có thể xem danh sách/rời hộ.
- **Hiện trạng:** `backend/core/permissions.py:52-120` có object permission; quyền `edit` được dùng chung cho dữ liệu y tế/measurement/Chat. `households/views.py:92-290` chỉ cho Owner xem danh sách thành viên và xử lý xóa thành viên; chưa có luồng rời nhóm của thành viên.
- **A:** Tách quyền theo thao tác/dữ liệu và hoàn thiện list/leave flows, giữ nguyên các vai trò trong tài liệu. **5–9 giờ.**
- **B:** Chỉ sửa caregiver shared read-only và ngăn shared VIEW_AND_LOG ghi hồ sơ y tế/Chat; chưa bổ sung leave flow. **2–4 giờ.**
- **C:** Không sửa; nêu rõ UC04/ma trận chưa được hiện thực đầy đủ. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Trung bình; có thể ảnh hưởng tests RBAC và hành vi đã có của VIEW_AND_LOG.
- **Ảnh hưởng Chương 3:** Bảng 2.42/2.47, BR04/BR05, TC03.3/TC09.1–09.3.
- **Khuyến nghị:** A để không biến quyền nhập chỉ số thành quyền ghi mọi loại dữ liệu.

### D13 — HTTPS, giới hạn tần suất và log dữ liệu sức khỏe

- **Đặc tả:** NFR02/Bảng 2.45 yêu cầu HTTPS, xử lý 429 và không log token/dữ liệu sức khỏe.
- **Hiện trạng:** `backend/core/settings.py:28-83` bật redirect/HSTS khi DEBUG=False, nhưng `frontend/lib/services/api_config.dart:1-8` mặc định HTTP. REST framework chưa khai báo throttle classes. Wear client/listener debug-log payload.
- **A:** Xóa log payload, cấu hình API URL HTTPS theo môi trường, thêm throttle phù hợp sau khi chốt ngưỡng. **3–6 giờ.**
- **B:** Chỉ loại dữ liệu sức khỏe khỏi log và đảm bảo production URL HTTPS; chưa bật throttling nếu chưa có ngưỡng. **1.5–3 giờ.**
- **C:** Không sửa; báo cáo giới hạn cấu hình và không tuyên bố đạt NFR02/429. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** HTTPS cần endpoint TLS thực tế; không đo/chọn ngưỡng rate-limit thay tác giả.
- **Ảnh hưởng Chương 3:** Mục bảo mật, CF/NFR; bằng chứng log và endpoint deployment.
- **Khuyến nghị:** B, vì sửa log/transport có phạm vi nhỏ; rate limit cần ngưỡng được duyệt.

## P1 — Chức năng nghiệp vụ quan trọng còn thiếu

### D07 — CRUD hồ sơ y tế

- **Đặc tả:** FR04, UC05, Bảng 2.31–2.36, Bảng 2.41 và SCR-07 yêu cầu 6 nhóm: bệnh sử, dị ứng, lần khám, thuốc, xét nghiệm, tài liệu.
- **Hiện trạng:** Models có trong `backend/medical_records/models.py:11-164`; API router hiện đăng ký tài liệu và measurement, không có CRUD cho 5 nhóm còn lại (`backend/medical_records/urls.py:1-15`). Nhiều cột/kiểu khác Data Dictionary.
- **A:** Đưa schema khớp Data Dictionary, API/serializer/permission cho đủ 6 nhóm, Flutter UI và test. **24–40 giờ.**
- **B:** Dùng models hiện có, triển khai API và UI tối thiểu; ghi rõ các khác biệt schema chưa được giải quyết. **14–24 giờ.**
- **C:** Không hiện thực; Chương 3 ghi “đã thiết kế, chưa hiện thực”. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Cao; phương án A có thể yêu cầu migration và chuyển đổi dữ liệu. Nếu cần migration, dừng để xin duyệt, không chạy trên DB phát triển.
- **Ảnh hưởng Chương 3:** FR04/UC05, TC06.1–06.3, SCR-07, phần giới hạn.
- **Khuyến nghị:** B nếu không được duyệt migration; A chỉ sau khi xác nhận schema và kế hoạch rollback.

### D08 — Persist AIInsight đúng schema và gọi provider khi có consent

- **Đặc tả:** FR07, UC08, Bảng 2.38/2.41/2.43/2.44; Insight gồm period, risk, triggered rules, content, generated_by.
- **Hiện trạng:** `backend/ai_services/models.py:7-28` dùng schema khác; `backend/ai_services/views.py:28-35` chỉ trả kết quả engine, không persist/call AI Provider.
- **A:** Khớp Data Dictionary, implement analyze/history endpoints, AI context tối thiểu và fallback, UI history. **12–20 giờ.**
- **B:** Persist kết quả Rule-only theo schema tối giản, chưa tích hợp diễn giải AI Insight. **7–12 giờ.**
- **C:** Không hiện thực; ghi trung thực chức năng chưa triển khai và để UC08 không đạt. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Cao; schema hiện tại khác yêu cầu, có khả năng migration. Cần D04 chốt consent/fallback; migration phải xin duyệt trước.
- **Ảnh hưởng Chương 3:** FR07/UC08, TC08.1–08.3, bảng Insight và mục tiêu phân tích nguy cơ.
- **Khuyến nghị:** A nếu chấp thuận migration; nếu không, C trung thực hơn việc gọi endpoint hiện có là AI Insight.

### D09 — API quản lý hội thoại và tin nhắn

- **Đặc tả:** FR08, UC09, Bảng 2.39–2.40/2.41 và SCR-08 yêu cầu list/detail/delete conversation, list messages và POST message.
- **Hiện trạng:** Có Conversation/Message model và một endpoint POST `/api/ai/chat/<profile_id>/`; chưa có các endpoint quản lý/lịch sử theo bảng API.
- **A:** Implement toàn bộ endpoint và cập nhật UI hội thoại/lịch sử, permissions, test. **8–14 giờ.**
- **B:** Implement list conversation và messages read-only tối thiểu; giữ chat send endpoint hiện có. **4–7 giờ.**
- **C:** Không hiện thực lịch sử; nêu rõ AI Chat chỉ là prototype gửi/nhận một phiên. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Trung bình; kiểm tra ownership, soft delete trong Data Dictionary và UX.
- **Ảnh hưởng Chương 3:** FR08/UC09, TC07.1/07.3, SCR-08 và bảng kết quả Chat.
- **Khuyến nghị:** B là mức tối thiểu để người dùng xem lại hội thoại.

### D10 — Device API và ghép nối thiết bị

- **Đặc tả:** FR06, UC07, Device Data Dictionary, Bảng 2.41, SCR-06 yêu cầu ghép nối/xem/thu hồi.
- **Hiện trạng:** `Device` model hiện có; không có `devices/urls.py` hoặc route/view. Wear prototype tạo dữ liệu giả và gửi HTTP tới listener điện thoại, không gắn server Device.
- **A:** Device CRUD/permission, pairing/revoke và tích hợp với lô đo. **8–14 giờ.**
- **B:** API ghép nối/revoke tối giản và gắn `device_id` khi batch sync; giữ nguồn dữ liệu prototype. **5–9 giờ.**
- **C:** Không triển khai device management; ghi Wear OS là prototype truyền dữ liệu giả, không phải đồng bộ thiết bị thật. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** A cần thiết bị/emulator nếu kiểm thử tích hợp; không yêu cầu migration nếu dùng model hiện tại.
- **Ảnh hưởng Chương 3:** UC07, TC05.1/05.2, SCR-06; ghi rõ phần cần thao tác thủ công.
- **Khuyến nghị:** B; giới hạn đúng scope nguyên mẫu, không khẳng định tích hợp cảm biến thật.

### D11 — API thống kê sức khỏe

- **Đặc tả:** FR05/UC06, Bảng 2.41 và SCR-10 yêu cầu GET `/health-measurements/statistics` trả min/max/avg, nhóm theo ngày/tuần.
- **Hiện trạng:** Không có route thống kê; Flutter tải raw measurements và tự nhóm một phần trong `health_trends_screen.dart`.
- **A:** Backend endpoint có lọc hồ sơ/loại/khoảng thời gian/unit group và UI dùng response chuẩn. **5–8 giờ.**
- **B:** Giữ client-side aggregation nhưng bổ sung min/max/average đúng output, chỉ với tập raw dữ liệu hiện có. **2–4 giờ.**
- **C:** Không triển khai statistics; ghi SCR-10/TC04.1 chưa hiện thực đầy đủ. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Thấp-trung bình; cần chốt timezone và cách tính huyết áp.
- **Ảnh hưởng Chương 3:** FR05, TC04.1, UC06, SCR-10.
- **Khuyến nghị:** A để đồng nhất backend API và tránh tính thống kê trên dữ liệu phân trang thiếu.

### D12 — Hàng đợi đồng bộ bền vững, trạng thái và backoff

- **Đặc tả:** BR08, UC07, NFR05/NFR06, Bảng 2.1/2.46 yêu cầu offline durable queue, bốn trạng thái và exponential backoff.
- **Hiện trạng:** `frontend/lib/views/home/dashboard_screen.dart:53-273` giữ Wear queue trong List RAM; flush theo timer cố định 30 giây; không persist hay hiển thị đầy đủ bốn trạng thái. `ManualMeasurementStore` không tích hợp vào hàng đợi Wear.
- **A:** Local persistent queue, migration phiên bản dữ liệu cục bộ (nếu cần), state machine 4 trạng thái, retry/backoff và UI. **8–14 giờ.**
- **B:** Persist queue bằng secure/local storage hiện có và retry định kỳ; hiển thị CHỜ_GỬI/THẤT_BẠI tối thiểu. **5–8 giờ.**
- **C:** Không hiện thực offline durability; đánh dấu TC05.1/05.2 “chưa hiện thực” và cần thao tác thiết bị. **0 giờ mã.**
- **Rủi ro/phụ thuộc:** Trung bình; cần xác định lưu trữ local phù hợp và kiểm thử đóng/mở app; không có emulator thì ghi MANUAL_TODO.
- **Ảnh hưởng Chương 3:** TC05.1/05.2, NFR05/NFR06, 3.1.2/3.1.3.
- **Khuyến nghị:** B để khắc phục mất dữ liệu khi app đóng, không mở rộng thành đồng bộ hai chiều.

## Gói ước lượng và đề xuất thứ tự

- **Gói P0 (D01–D06, D13):** khoảng **20,5–37 giờ**, tính theo phương án khuyến nghị của từng quyết định (D01=B, D02=A, D03=A, D04=B, D05=A, D06=A, D13=B).
- **Gói P0 + P1 (thêm D07–D09, D11–D12):** khoảng **60,5–104 giờ**, giả định D07=B, D08=A, D09=B, D11=A, D12=B; chưa gồm D10 ghép nối thiết bị.
- **Gói tối đa P0 + P1 + D10:** khoảng **68,5–118 giờ**, giả định D10=A; tích hợp Wear OS phần cứng thật có thể cần thêm thời gian/thiết bị và chưa ước lượng ở đây.
- Nếu không duyệt migration và chọn D08=C, trừ **12–20 giờ** khỏi các gói P0+P1 tương ứng.
- **Gói tối thiểu để báo cáo và mã nhất quán nhất:** P0 phương án A/B theo từng quyết định; chọn D07=A/B tùy duyệt migration; D08=A nếu duyệt migration, nếu không chọn C; D09=B; D11=A; D12=B; D10=C nếu chỉ giữ Wear OS dạng nguyên mẫu.
- Mọi hạng mục cần migration phải dừng trước khi chạy migration nếu chưa được duyệt. Không thực hiện phase 2 cho tới khi nhận được lựa chọn của tác giả.
