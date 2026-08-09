# TODO — Healthy App (Dọn dẹp dự án & Viết README)

## ✅ Nhiệm vụ 1: Đánh giá và lọc sạch File thừa
- [x] Phân tích cây thư mục & danh sách file hiện có
- [x] Xác định các nhóm file/thư mục KHÔNG CẦN THIẾT
- [x] Xác định dependencies thừa trong `pubspec.yaml`
- [x] Viết lệnh Terminal (PowerShell/Bash) để xoá nhanh
- [x] Tạo script `clean_project.ps1` (Windows) tiện chạy

## ✅ Nhiệm vụ 2: Tạo file README.md chuẩn đồ án
- [x] Mục 1: Tên dự án & giới thiệu tổng quan
- [x] Mục 2: Kiến trúc hệ thống (Data Flow + Tech Stack)
- [x] Mục 3: Yêu cầu môi trường (Prerequisites)
- [x] Mục 4: Hướng dẫn cài đặt & khởi chạy (runserver, emulator, IP 10.0.2.2)
- [x] Mục 5: Tài liệu API (GET/POST /api/health/ + POST /api/v1/health/batch/)
- [x] Mục 6: Cấu trúc cây thư mục chuẩn sau dọn dẹp
- [x] Ghi đè nội dung mới vào file `README.md`

## 🔧 Việc phụ trợ
- [x] Tạo `backend/requirements.txt` (hiện backend chưa có file này)
- [x] Hướng dẫn chạy dọn dẹp & `flutter pub get` sau khi bỏ deps thừa

---

## 🛠️ Nhiệm vụ 3: Sửa lỗi & cập nhật `dashboard_screen.dart`
- [x] Phân tích nguyên nhân (dấu `}` đặt sai vị trí làm `_buildConnectionStatus` nằm ngoài class)
- [x] Sửa cấu trúc: đưa `_buildConnectionStatus` vào trong `_DashboardScreenState`
- [x] Giữ nguyên logic nhận dữ liệu (stream, API, HTTP listener)
- [x] Dùng lại các state `_heartRate`, `_steps`, `_calories`, `_wearConnected` trong UI mới
- [x] Viết lại `build()` theo sườn giao diện mới (header, health status, activity row, chart, action buttons)
- [x] Dùng `_HealthBarChart` từ `_heartRateHistory` (hết cảnh báo unused widget)
- [x] Sử dụng `GradientButton` & dùng `_refreshData` (hết cảnh báo unused function)
- [x] Chạy `flutter analyze` để xác nhận không còn lỗi

---

## 🎯 Kết quả

### 📁 Các file đã tạo / sửa
| File | Hành động | Mô tả |
|------|-----------|-------|
| `README.md` | ✏️ Ghi đè | README mới, chuyên nghiệp, đầy đủ 6 mục |
| `backend/requirements.txt` | ➕ Tạo mới | Danh sách dependencies Python chuẩn |
| `clean_project.ps1` | ➕ Tạo mới | Script dọn dẹp file rác (Windows PowerShell) |
| `TODO.md` | ✏️ Cập nhật | Đánh dấu hoàn tất tất cả công việc |

### ⚠️ Các bước thủ công còn lại bạn cần làm
1. **Dọn dẹp file rác:** chạy `.\clean_project.ps1` trong PowerShell
2. **Cập nhật deps Flutter (nếu muốn xoá thư viện thừa):** sửa `frontend/pubspec.yaml` — bỏ `watch_connectivity`, `pedometer`, `cupertino_icons` → chạy `flutter pub get`
3. **Chạy backend:** `cd backend && python -m venv venv && venv\Scripts\activate && pip install -r requirements.txt && python manage.py migrate && python manage.py runserver`
