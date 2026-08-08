# TODO — Cập nhật README theo trạng thái dự án hiện tại

## 🔄 Các bước cập nhật README.md

- [x] Sửa URL `WatchSenderService._defaultUrl` từ `10.0.2.2:8080` → `localhost:8080`
- [x] Cập nhật phần dependencies thừa — đánh dấu đã xoá khỏi `pubspec.yaml`
- [x] Cập nhật "Quy trình dọn dẹp" — bỏ dòng template README không tồn tại
- [x] Sửa phần "Tài liệu bổ sung" — bỏ link docs không tồn tại
- [x] Rà soát tài liệu API khớp với endpoint thực tế (`/api/health/`)

## 📝 Ghi chú

Đã cập nhật `README.md` cho đúng với trạng thái code hiện tại:
- `WatchSenderService` dùng `http://localhost:8080/sync`
- `pubspec.yaml` chỉ còn `http` + `permission_handler`
- Bỏ các link `docs/ONBOARDING_GUIDE.md` và `docs/CONNECTION_DEBUG_GUIDE.md` không tồn tại

