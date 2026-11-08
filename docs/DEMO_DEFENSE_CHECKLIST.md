# HealthyApp - Checklist demo bảo vệ

Checklist này mô tả thao tác theo UI và API hiện có. Dùng tài khoản, dữ liệu
kiểm thử riêng; không dùng thông tin cá nhân thật.

## Chuẩn bị trước buổi demo

- Khởi động backend và database; đặt `API_BASE_URL` trỏ tới backend mà điện
  thoại có thể truy cập.
- Chuẩn bị một email đăng ký mới cho demo Owner và một tài khoản Member đã
  đăng ký trước để nhận lời mời Household. Đăng ký Member trước để hệ thống có
  thể tìm tài khoản bằng email.
- Backend hiện dùng LocalRuleProvider thông qua AI Provider abstraction. Mở
  **Cài đặt** và bật **Cho phép phân tích bằng Trợ lý AI** cho hồ sơ demo.
- Nếu trình diễn Wear Sync, cài app Wear riêng; cấu hình cùng
  `WATCH_SYNC_TOKEN` trên điện thoại và đồng hồ, đặt `WATCH_SYNC_URL` trên đồng
  hồ thành địa chỉ LAN của điện thoại, ví dụ
  `http://<IP-điện-thoại>:8080/sync`. Hai thiết bị phải cùng mạng và cho phép
  kết nối tới cổng 8080.
- **Tạo Household trước khi demo:** UI hiện có xem Household, mời và chấp nhận
  lời mời, nhưng chưa có thao tác tạo Household. Tạo trước bằng API đã đăng
  nhập `POST /api/households/` với JSON `{"name":"Healthy Demo Family"}`.
  Không trình bày thao tác này như một nút trong ứng dụng.
- Cho phép notification/network access nếu thiết bị hỏi. Không xóa database
  demo giữa các bước.

## 1. Đăng ký

**Màn hình:** Đăng nhập → **Đăng ký ngay**.

**Dữ liệu mẫu:**

- Tên đăng nhập: `healthy_demo_owner`
- Email liên hệ: `healthy.demo.owner@example.test`
- Mật khẩu: `HealthyDemo#2026`
- Xác nhận mật khẩu: nhập lại đúng mật khẩu

Thay email bằng địa chỉ chưa tồn tại nếu backend không chấp nhận miền `.test`.

**Thao tác:** Nhấn **Đăng ký ngay**.

**Kết quả mong đợi:** Đăng ký thành công, chuyển sang **Thiết lập hồ sơ**; chưa
cần đăng nhập lại nếu ứng dụng tự chuyển tiếp.

**Hội đồng có thể hỏi:**

- Vì sao yêu cầu xác nhận mật khẩu?
- Backend xử lý email đã tồn tại và mật khẩu không đạt chính sách thế nào?

## 2. Đăng nhập

**Màn hình:** Đăng nhập.

**Dữ liệu mẫu:** Email tài khoản vừa đăng ký và mật khẩu ở bước 1.

**Thao tác:** Nhấn **Đăng nhập**.

**Kết quả mong đợi:** Đăng nhập thành công và chuyển tới khu vực ứng dụng.
Access/refresh token được lưu để gọi API; sau khi token hết hạn, client thử
refresh rồi gửi lại yêu cầu một lần.

**Hội đồng có thể hỏi:**

- Khác nhau giữa access token và refresh token?
- Khi refresh token hết hạn hoặc bị thu hồi thì ứng dụng xử lý thế nào?

## 3. Tạo hồ sơ cá nhân

**Màn hình:** **Thiết lập hồ sơ** xuất hiện sau đăng ký; nếu đã bỏ qua, dùng
**Hồ sơ/Cài đặt** trong ứng dụng.

**Dữ liệu mẫu:**

- Giới tính: chọn một giá trị
- Ngày sinh: `01/01/1995`
- Chiều cao: `165 cm`
- Cân nặng: `60 kg`

**Thao tác:** Nhấn **Hoàn tất & Bắt đầu**.

**Kết quả mong đợi:** Hồ sơ SELF được tạo/cập nhật và ứng dụng mở Dashboard.
Nếu chưa muốn nhập thì có thể chọn **Bỏ qua, cập nhật sau**.

**Hội đồng có thể hỏi:**

- Hồ sơ SELF gắn với tài khoản ra sao?
- Dữ liệu chiều cao/cân nặng được dùng ở những phần nào?

## 4. Tạo Household

**Màn hình:** Không có thao tác tạo Household trong UI hiện tại. Màn **Quản lý
thành viên gia đình** chỉ hiển thị Household đã tồn tại.

**Dữ liệu mẫu cần chuẩn bị trước:** `Healthy Demo Family`.

**Thao tác chuẩn bị:** Dùng API backend đã xác thực:

```http
POST /api/households/
Content-Type: application/json

{"name":"Healthy Demo Family"}
```

**Kết quả mong đợi:** API trả `201 Created`, tạo Household và membership Owner
cho tài khoản hiện tại. Sau khi tải lại màn **Quản lý thành viên gia đình**,
Household xuất hiện.

**Hội đồng có thể hỏi:**

- Vì sao thao tác tạo Household không có trên UI?
- Backend bảo đảm Household có Owner thế nào?

**Lưu ý trình bày:** Nói rõ bước tạo Household là chuẩn bị dữ liệu qua API; không
giả lập một nút UI chưa có.

## 5. Chia sẻ hồ sơ trong Household

**Màn hình:** **Quản lý thành viên gia đình** (`FamilyMembersScreen`).

**Điều kiện:** Đăng nhập bằng Owner, Household đã chuẩn bị ở bước 4, tài khoản
Member đã đăng ký.

**Dữ liệu mẫu:**

- Email: email tài khoản Member đã chuẩn bị
- Vai trò: **Thành viên**

**Thao tác Owner:**

1. Mở card **Healthy Demo Family**, nhấn **Mời**.
2. Nhập email Member, chọn vai trò, nhấn **Gửi lời mời**.
3. Đăng xuất; đăng nhập tài khoản Member.
4. Mở **Quản lý thành viên gia đình**, chấp nhận lời mời bằng nút dấu kiểm.

**Kết quả mong đợi:** Owner thấy lời mời đã gửi; Member thấy lời mời đang chờ,
chấp nhận xong thì Household xuất hiện trong danh sách.

**Giới hạn hiện tại:** UI mời người dùng đặt `VIEW_ONLY` mặc định và chia sẻ hồ
  sơ Owner hiện tại; không có bộ chọn hồ sơ chia sẻ/mức quyền trong dialog.

**Hội đồng có thể hỏi:**

- Khác nhau giữa `VIEW_ONLY` và `VIEW_AND_LOG`?
- Backend kiểm tra quyền ở endpoint nào, hay chỉ ẩn nút trên giao diện?
- Vì sao UI hiện tại chỉ mời với quyền xem?

## 6. Ghi nhận chỉ số sức khỏe

**Màn hình:** Dashboard → nút **Thêm chỉ số** → **Ghi nhận chỉ số**.

**Dữ liệu mẫu đề xuất:** Chọn **Huyết áp**:

- Tâm thu: `120 mmHg`
- Tâm trương: `80 mmHg`
- Nhịp tim: `72 bpm`
- Giữ thời điểm đo hiện tại hoặc chọn ngày/giờ gần nhất

**Thao tác:** Nhấn **Lưu dữ liệu**.

**Kết quả mong đợi:** Màn ghi nhận đóng; Dashboard/nhật ký tải dữ liệu mới.
Huyết áp và nhịp tim được lưu thành các bản ghi tương ứng với nguồn `MANUAL`.
Nếu tâm thu không lớn hơn tâm trương, UI từ chối lưu.

**Hội đồng có thể hỏi:**

- Vì sao bản ghi có `source` và `idempotency_key`?
- Dữ liệu nhập tay khác gì dữ liệu Wear OS?
- Backend kiểm soát quyền ghi lên hồ sơ được chia sẻ thế nào?

## 7. Wear Sync

**Màn hình điện thoại:** Dashboard → **Thiết bị** → **Thiết bị kết nối**.
**Màn hình đồng hồ:** app Wear OS (`WearDashboard`).

**Dữ liệu mẫu:**

- Mã thiết bị: `DEMO-WATCH-001`
- Tên thiết bị: `Wear OS Demo`
- Wear app sinh nhịp tim, bước chân, calo mô phỏng.

**Thao tác:**

1. Trên điện thoại, chọn **Ghép nối thiết bị mới**, nhập mã/tên và xác nhận.
2. Mở Wear app, cấp quyền cảm biến/hoạt động nếu được hỏi.
3. Chờ đồng hồ gửi mẫu qua HTTP tới điện thoại. Kiểm tra Dashboard cập nhật và
   số bản ghi chờ đồng bộ.
4. Khi có dữ liệu chờ, vào **Thiết bị** và nhấn **Đồng bộ ngay**; chờ backend
   nhận batch rồi tải lại số đang chờ.

**Kết quả mong đợi:** Điện thoại nhận dữ liệu, lưu queue cục bộ rồi gửi batch
với `device_id`; bản ghi được server đánh dấu `WEAR_OS`. Gửi lại cùng khóa
idempotency không tạo bản ghi trùng.

**Lưu ý demo:** Đây là dữ liệu mô phỏng, không phải đo từ cảm biến thật. Phải
cấu hình URL/token và mạng LAN trước; `localhost` trên đồng hồ không trỏ tới
điện thoại. Nếu không cấu hình hoặc thiết bị không kết nối, bỏ qua demo live và
trình bày kết quả test batch đã có.

**Hội đồng có thể hỏi:**

- Queue nằm ở đâu, retry và chống trùng hoạt động thế nào?
- Vì sao thiết bị cần ghép với hồ sơ?
- Dữ liệu hiện tại là cảm biến thật hay dữ liệu mô phỏng?

## 8. AI Insight

**Điều kiện:** Có hồ sơ và dữ liệu đo; consent AI bật trong **Cài đặt**; provider
được cấu hình nếu muốn trình diễn AI bên ngoài.

**Màn hình:** Dashboard → **Tư vấn** → tab **Đánh giá nguy cơ**.

**Dữ liệu mẫu:** Dùng các bản ghi hợp lý đã nhập, ví dụ `120/80 mmHg` và
`72 bpm`; không cần nhập chỉ số bất thường để buộc sinh cảnh báo.

**Thao tác:** Nhấn **Phân tích ngay** / **Phân tích**.

**Kết quả mong đợi:** Hiển thị mức nguy cơ, số bản ghi đã phân tích, cảnh báo/
khuyến nghị và nguồn sinh kết quả (`RULE_ONLY` hoặc `RULE_AND_AI`). Kết quả là
tham khảo, không phải chẩn đoán. Khi provider lỗi, phần phân tích có thể trả về
kết quả rule-only.

**Hội đồng có thể hỏi:**

- Rule Engine làm gì trước khi gọi AI Provider?
- Consent được kiểm tra cho hồ sơ nào, ở đâu?
- Khi provider lỗi thì fallback ra sao; kết quả có được lưu không?

## 9. AI Chat

**Điều kiện:** AI consent vẫn bật cho hồ sơ đang chọn; provider sẵn sàng nếu muốn
trình diễn phản hồi ngoài.

**Màn hình:** **Tư vấn** → tab **AI Chat**.

**Câu hỏi mẫu:** `Tôi nên theo dõi chỉ số nào mỗi ngày?`

**Thao tác:** Nhập câu hỏi vào ô chat và nhấn nút gửi. Mở danh sách hội thoại để
chứng minh có thể xem lại lịch sử.

**Kết quả mong đợi:** Câu hỏi và phản hồi hiển thị trong hội thoại. Nếu provider
không khả dụng, UI báo đây là phản hồi dự phòng chưa được lưu và cho phép thử
lại; không trình bày nội dung đó như chẩn đoán.

**Hội đồng có thể hỏi:**

- Hội thoại được phân tách theo tài khoản và hồ sơ ra sao?
- Dữ liệu nào được gửi tới provider?
- Vì sao phản hồi fallback không được lưu như câu trả lời AI?

## Kết thúc demo

- Quay lại Dashboard và xác nhận hồ sơ cùng các chỉ số vẫn hiển thị.
- Không để lộ mật khẩu, token, email cá nhân hay dữ liệu sức khỏe thật trên máy
  chiếu.
- Nếu Household/API, AI provider hoặc Wear Sync chưa cấu hình sẵn, nêu rõ đó là
  bước chuẩn bị/giới hạn demo; không giả định đã chạy live.
