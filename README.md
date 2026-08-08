# ⌚ Healthy App — Hệ Thống Theo Dõi Sức Khỏe Thời Gian Thực

> **Healthy App** là hệ thống theo dõi chỉ số sức khỏe thời gian thực, kết nối **đồng hồ Wear OS → ứng dụng điện thoại Android → Django Backend**. Hệ thống đo nhịp tim, đếm bước chân, tính lượng calo tiêu thụ và đồng bộ dữ liệu lên server để lưu trữ, quản lý lịch sử.

[![Django](https://img.shields.io/badge/Backend-Django%206.0-092E20?logo=django)](https://www.djangoproject.com/)
[![DRF](https://img.shields.io/badge/API-Django%20REST%20Framework-red)](https://www.django-rest-framework.org/)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter%203.x-02569B?logo=flutter)](https://flutter.dev/)
[![Wear OS](https://img.shields.io/badge/Wear%20OS-Supported-00C9A7?logo=wearos)](https://wearos.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 📑 Mục lục

- [📌 Giới thiệu dự án](#-giới-thiệu-dự-án)
- [🏗️ Kiến trúc hệ thống](#️-kiến-trúc-hệ-thống)
- [⚙️ Yêu cầu môi trường](#️-yêu-cầu-môi-trường)
- [🚀 Hướng dẫn cài đặt & khởi chạy](#-hướng-dẫn-cài-đặt--khởi-chạy)
- [🔌 Tài liệu API](#-tài-liệu-api)
- [🧹 Quy trình dọn dẹp dự án](#-quy-trình-dọn-dẹp-dự-án)
- [🛠️ Roadmap phát triển](#️-roadmap-phát-triển)
- [📚 Tài liệu bổ sung](#-tài-liệu-bổ-sung)

---

## 📌 Giới thiệu dự án

### 🎯 Mục tiêu

Xây dựng hệ thống **đo & đồng bộ chỉ số sức khỏe theo thời gian thực**:

```
⌚ Đồng hồ Wear OS (cảm biến)  →  📱 Điện thoại Android (hiển thị & đệm dữ liệu)  →  🖥️ Django Backend (lưu trữ & phân tích)
```

### ✨ Chức năng chính

| Chức năng | Mô tả | Trạng thái |
|-----------|-------|:----------:|
| ❤️ **Đo nhịp tim** | Hiển thị nhịp tim real-time (bpm) từ đồng hồ | ✅ Hoàn thành |
| 👣 **Đếm bước chân** | Đếm số bước trong ngày | ✅ Hoàn thành |
| 🔥 **Đo calo** | Tính toán lượng calo tiêu thụ (kcal) | ✅ Hoàn thành |
| 📡 **Đồng bộ API** | Gửi dữ liệu sức khỏe lên Django REST API | ✅ Hoàn thành |
| ⌚ **Kết nối Wear OS ↔ Phone** | Giao tiếp qua HTTP (Watch ↔ Phone ↔ Server) | ✅ Hoàn thành |
| 🔐 **Xác thực người dùng** | Đăng ký, đăng nhập, token authentication | 🔜 Phát triển |
| 📈 **Lịch sử & Biểu đồ** | Xem lại dữ liệu sức khỏe theo ngày/tuần/tháng | 🔜 Phát triển |
| 🏃 **Mục tiêu cá nhân** | Đặt mục tiêu bước chân/calo hàng ngày | 🔜 Phát triển |
| 📦 **Gửi Batch dữ liệu** | Gom nhiều bản ghi gửi 1 lần | 🔜 Phát triển |

> 📝 **Ghi chú:** Ở giai đoạn hiện tại, đồng hồ Wear OS đang **mô phỏng dữ liệu bằng bộ sinh dữ liệu giả** (`Random()`) để demo luồng kết nối. Việc đọc cảm biến thật nằm trong roadmap.

---

## 🏗️ Kiến trúc hệ thống

### 🔄 Sơ đồ luồng dữ liệu (Data Flow)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ 1️⃣  WEAR OS (Đồng hồ)                                                     │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │  Flutter Wear App  (frontend/lib/main_wear.dart)                    │  │
│ │  • Đọc cảm biến: nhịp tim, bước chân, calo                           │  │
│ │  • WatchSenderService: đóng gói JSON                                 │  │
│ └──────────────────────────┬───────────────────────────────────────────┘  │
│                            │  HTTP POST  (mỗi 5 giây / batch)            │
│                            ▼  http://<phone_ip>:8080/sync                │
├────────────────────────────────────────────────────────────────────────────┤
│ 2️⃣  PHONE APP (Điện thoại Android)                                        │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │  Flutter Mobile App  (frontend/lib/main.dart)                       │  │
│ │  • WatchService.initPhoneListener() — HTTP Server port 8080         │  │
│ │  • Nhận dữ liệu → Cập nhật Dashboard (setState)                     │  │
│ │  • Buffer/Batch dữ liệu cục bộ (Hive/SQLite — roadmap)              │  │
│ │  • ApiService.sendHealthData() → gọi REST API                       │  │
│ └──────────────────────────┬───────────────────────────────────────────┘  │
│                            │  HTTP (REST API)                             │
│                            ▼  POST http://10.0.2.2:8000/api/health/       │
├────────────────────────────────────────────────────────────────────────────┤
│ 3️⃣  DJANGO BACKEND (Server)                                               │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │  Django 6.0 + Django REST Framework                                 │  │
│ │  • core/          → settings, urls, wsgi/asgi                      │  │
│ │  • health_metrics → model HealthData + serializer + view           │  │
│ │  • accounts       → xác thực người dùng (đang phát triển)          │  │
│ │  • Database: SQLite (dev) / PostgreSQL (production)                │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

### 💻 Tech Stack

| Thành phần | Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|:---------:|---------|
| 🖥️ **Backend** | Django | ≥ 6.0 | Web framework chính |
| 🖥️ **REST API** | Django REST Framework | ≥ 3.15 | Xây dựng API endpoints |
| 🖥️ **CORS** | django-cors-headers | ≥ 4.0 | Cho phép Flutter app gọi API |
| 🗄️ **Database** | SQLite / PostgreSQL | 14+ (PSQL) | Lưu trữ dữ liệu sức khỏe |
| 📱 **Frontend** | Flutter | 3.x | Cross-platform UI |
| 🎯 **Ngôn ngữ UI** | Dart | ^3.12.2 | Ngôn ngữ lập trình Flutter |
| 🌐 **HTTP Client** | `http` (Dart package) | ^1.2.0 | Gọi API & truyền dữ liệu Watch ↔ Phone |
| ⌚ **Wear OS** | Flutter Wear App | 3.x | App chạy trên đồng hồ |
| 🔐 **Permissions** | `permission_handler` | ^12.0.3 | Xin quyền cảm biến |
| 🗄️ **Local Storage** | Hive / SQLite | *(roadmap)* | Buffer dữ liệu khi mất mạng |

> ⚠️ **Lưu ý kiến trúc:** Dự án hiện dùng **HTTP làm giao thức truyền tin** giữa Watch → Phone (thay vì `watch_connectivity`) để dễ chạy trên emulator. Trong kiến trúc production, Phone app sẽ **buffer dữ liệu cục bộ** rồi **gửi theo batch** lên server để tiết kiệm băng thông & pin.

---

## ⚙️ Yêu cầu môi trường

| Công nghệ | Phiên bản | Kiểm tra | Ghi chú |
|-----------|:---------:|----------|---------|
| **Python** | ≥ 3.10 | `python --version` | Bắt buộc cho Django |
| **Django** | ≥ 6.0 | `django-admin --version` | Cài qua pip |
| **Flutter SDK** | 3.x (≥ 3.44) | `flutter --version` | Bao gồm cả Dart SDK |
| **Dart SDK** | ^3.12.2 | `dart --version` | Đi kèm Flutter SDK |
| **Android Studio** | Hedgehog+ | `flutter doctor` | Cài Android SDK + Emulator |
| **Android Emulator** | API 30+ | AVD Manager | Tạo 2 AVD: Phone & Wear OS |
| **Wear OS Emulator** | Wear OS 3+ | AVD Manager | Cần Google Play Services |
| **PostgreSQL** | 14+ | *(tùy chọn)* | Chỉ cho production |
| **Git** | ≥ 2.0 | `git --version` | Quản lý phiên bản |

### 📌 Chạy `flutter doctor` để kiểm tra môi trường

```bash
flutter doctor
```

Đảm bảo tất cả các mục đều hiện ✅ (đặc biệt là **Android toolchain** và **Android Studio**).

---

## 🚀 Hướng dẫn cài đặt & khởi chạy

### 🗂️ Cấu trúc dự án

```
healthy_app/
├── README.md                  # Tài liệu này
├── TODO.md                    # Kế hoạch phát triển
├── .gitignore                 # Chống commit file rác (venv, cache, db, build)
├── backend/                   # 🖥️ Django Backend
└── frontend/                  # 📱 Flutter Frontend
```

---

### 🖥️ Bước 1 — Backend (Django)

```bash
# 1. Di chuyển vào thư mục backend
cd backend

# 2. Tạo virtual environment (đặt NGAY TRONG backend/)
python -m venv venv

# 3. Kích hoạt venv
#    Windows (PowerShell):
venv\Scripts\activate
#    Linux / macOS:
# source venv/bin/activate

# 4. Cài đặt dependencies
pip install -r requirements.txt

# 5. Chạy migrations (tạo database)
python manage.py migrate

# 6. Tạo superuser (cho Django Admin)
python manage.py createsuperuser

# 7. Chạy development server
python manage.py runserver
```

> ✅ Backend chạy tại **`http://localhost:8000/`**
> - Django Admin: `http://localhost:8000/admin/`
> - API Health: `http://localhost:8000/api/health/`

---

### 📱 Bước 2 — Frontend (Flutter Phone App)

```bash
# 1. Di chuyển vào thư mục frontend
cd frontend

# 2. Cài đặt dependencies
flutter pub get

# 3. Kiểm tra cấu hình API (quan trọng!)
```

**⚙️ Cấu hình IP cho API:**

File cấu hình: `frontend/lib/services/api_service.dart`

```dart
// MẶC ĐỊNH: dùng cho Android Emulator (10.0.2.2 = localhost của máy host)
static const String baseUrl = 'http://10.0.2.2:8000/api';

// Trên thiết bị thật: đổi thành IP LAN của máy tính
// static const String baseUrl = 'http://192.168.1.10:8000/api';

// Trên Web/Desktop: đổi thành localhost
// static const String baseUrl = 'http://localhost:8000/api';
```

**Chạy app trên Phone Emulator:**

```bash
# Đảm bảo AVD Phone đang bật
flutter emulators --launch <phone_avd_id>

# Chạy app trên Android Emulator
flutter run -d android
```

---

### ⌚ Bước 3 — Wear OS App (Emulator)

```bash
# 1. Tạo AVD Wear OS (Wear OS 3+, có Google Play)
#    Android Studio → Device Manager → Create Device → Chọn "Wear OS"

# 2. Chạy app Wear với target là main_wear.dart
cd frontend
flutter run -d <wear_avd_id> --target lib/main_wear.dart
```

> ⚙️ **Cấu hình địa chỉ Phone cho Watch:**
> File: `frontend/lib/services/watch_sender_service.dart`
>
> ```dart
> // MẶC ĐỊNH: localhost:8080/sync — trỏ tới HTTP listener của Phone app
> // (chạy trên cùng thiết bị/emulator, phone app bind port 8080)
> static const String _defaultUrl = 'http://localhost:8080/sync';
>
> // Trên thiết bị thật / emulator khác: đổi thành IP LAN của điện thoại
> // static const String _defaultUrl = 'http://192.168.1.20:8080/sync';
> ```

---

### 🔌 Bước 4 — Kiểm tra luồng hoạt động

| Bước | Kiểm tra | Kết quả mong đợi |
|:----:|----------|------------------|
| 1 | Backend `runserver` | Server chạy tại `localhost:8000` |
| 2 | `GET http://127.0.0.1:8000/api/health/` | Trả về JSON array |
| 3 | `curl -X POST http://127.0.0.1:8000/api/health/ -H "Content-Type: application/json" -d "{\"heart_rate\":70,\"steps\":1000,\"calories\":50.5}"` | Trả về `201 Created` |
| 4 | Chạy Phone App trên emulator | Dashboard hiển thị 3 thẻ chỉ số |
| 5 | Chạy Wear App | Đồng hồ gửi dữ liệu mỗi 5 giây → Phone nhận → Phone đẩy lên Server |
| 6 | `GET http://127.0.0.1:8000/api/health/` (lại) | Có thêm bản ghi mới từ Phone |

> 📌 **Lưu ý quan trọng khi test trên emulator:**
> - `10.0.2.2` là địa chỉ đặc biệt để Android Emulator truy cập `localhost` của máy host.
> - Backend phải cấu hình `ALLOWED_HOSTS` chứa `10.0.2.2` (xem phần Troubleshooting).
> - Android 9+ chặn HTTP trần → đã bật `android:usesCleartextTraffic="true"` trong `AndroidManifest.xml`.

---

## 🔌 Tài liệu API

### 📡 Danh sách endpoints

| Method | Endpoint | Mô tả | Authentication | Trạng thái |
|--------|----------|-------|:--------------:|:----------:|
| `GET` | `/admin/` | Django Admin Dashboard | 🔐 Required | ✅ |
| `GET` | `/api/health/` | Lấy danh sách bản ghi sức khỏe | ❌ AllowAny (tạm) | ✅ |
| `POST` | `/api/health/` | Tạo 1 bản ghi sức khỏe mới | ❌ AllowAny (tạm) | ✅ |
| `POST` | `/api/v1/health/batch/` | Gửi nhiều bản ghi 1 lần (batch) | 🔜 Planned | 🔜 Phát triển |

---

### 1️⃣ `GET /api/health/`

Lấy danh sách lịch sử đo sức khỏe (tối đa 50 bản ghi mới nhất nếu chưa đăng nhập).

**Request:**

```http
GET /api/health/ HTTP/1.1
Host: localhost:8000
```

**Response — `200 OK`:**

```json
[
  {
    "id": 1,
    "user": null,
    "heart_rate": 72,
    "steps": 5423,
    "calories": 245.5,
    "created_at": "2026-07-29T10:30:00Z"
  },
  {
    "id": 2,
    "user": null,
    "heart_rate": 85,
    "steps": 1200,
    "calories": 89.3,
    "created_at": "2026-07-29T09:15:00Z"
  }
]
```

---

### 2️⃣ `POST /api/health/`

Tạo một bản ghi sức khỏe mới (dữ liệu gửi từ Flutter lên).

**Request:**

```http
POST /api/health/ HTTP/1.1
Host: localhost:8000
Content-Type: application/json

{
  "heart_rate": 75,
  "steps": 3200,
  "calories": 156.7
}
```

**Response — `201 Created`:**

```json
{
  "id": 3,
  "user": null,
  "heart_rate": 75,
  "steps": 3200,
  "calories": 156.7,
  "created_at": "2026-07-29T14:00:00Z"
}
```

**Response — `400 Bad Request` (thiếu trường bắt buộc):**

```json
{
  "heart_rate": ["This field is required."]
}
```

---

### 3️⃣ `POST /api/v1/health/batch/` *(Đang phát triển)*

Gửi nhiều bản ghi cùng lúc trong một request. Đây là endpoint **khuyến nghị cho production** để giảm số lượng HTTP request, tiết kiệm pin và băng thông.

**Request:**

```http
POST /api/v1/health/batch/ HTTP/1.1
Host: localhost:8000
Content-Type: application/json

{
  "records": [
    {
      "heart_rate": 72,
      "steps": 5423,
      "calories": 245.5,
      "timestamp": "2026-07-29T10:30:00Z"
    },
    {
      "heart_rate": 85,
      "steps": 1200,
      "calories": 89.3,
      "timestamp": "2026-07-29T10:35:00Z"
    },
    {
      "heart_rate": 91,
      "steps": 1800,
      "calories": 120.0,
      "timestamp": "2026-07-29T10:40:00Z"
    }
  ]
}
```

**Response — `201 Created`:**

```json
{
  "status": "success",
  "message": "Đã lưu 3 bản ghi thành công.",
  "created_ids": [10, 11, 12]
}
```

**Response — `400 Bad Request` (dữ liệu không hợp lệ):**

```json
{
  "status": "error",
  "message": "Có 1 bản ghi không hợp lệ.",
  "errors": [
    {
      "index": 1,
      "error": {
        "heart_rate": ["This field is required."]
      }
    }
  ]
}
```

> 💡 **Lưu ý:** Endpoint batch hiện đang trong roadmap phát triển. Backend hiện tại chỉ hỗ trợ `POST /api/health/` (single record). Kiến trúc batch sẽ được triển khai khi hoàn thiện tính năng buffer dữ liệu cục bộ trên Phone app.

---

## 🧹 Quy trình dọn dẹp dự án

> 🧹 **Ghi chú:** Dự án hiện không còn kèm script tự động dọn dẹp (`clean_project.ps1`). Vui lòng dùng các lệnh thủ công bên dưới để dọn file rác.

### 🗑️ Danh sách file/thư mục có thể xoá

| Nhóm | File / Thư mục | Lý do |
|:----:|----------------|-------|
| 🐍 **Python cache** | `backend/**/__pycache__/`, `*.pyc` | Cache biên dịch Python, tự sinh lại |
| 🏗️ **Build cache** | `frontend/build/`, `.dart_tool/`, `.flutter-plugins` | Build artifacts, tự sinh lại |
| 📱 **Android build** | `frontend/android/.gradle/`, `frontend/android/app/build/` | Build cache Gradle |
| 🗄️ **DB tạm** | `backend/db.sqlite3` | Database dev, có thể reset |
| 📄 **IDE files** | `frontend/frontend.iml`, `.idea/` | File cấu hình IDE, không cần trong VCS |
| 📦 **Deps thừa (Flutter)** | *(đã xoá)* — `watch_connectivity`, `pedometer`, `cupertino_icons` | Đã loại khỏi `pubspec.yaml` |
| 📦 **Deps thừa (Python)** | *(không có)* | Backend đã dọn: chỉ giữ Django + DRF + CORS |
| 🐍 **VirtualEnv sai vị trí** | `venv/` (thư mục gốc) | Phải đặt trong `backend/venv/` (đã khắc phục) |
| 🖥️ **Platform thừa** | `frontend/ios/`, `web/`, `linux/`, `macos/`, `windows/` | Đã xoá — dự án chỉ dùng Android + Wear OS |

### 🧹 Lệnh dọn dẹp nhanh (PowerShell)

```powershell
# ===== Xoá Python cache =====
Get-ChildItem -Path "backend" -Recurse -Directory -Filter __pycache__ | Remove-Item -Recurse -Force
Get-ChildItem -Path "backend" -Recurse -Filter *.pyc | Remove-Item -Force

# ===== Xoá Flutter build cache =====
Remove-Item -Recurse -Force "frontend\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\.dart_tool" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\android\.gradle" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\android\app\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\android\.idea" -ErrorAction SilentlyContinue

# ===== Xoá DB tạm =====
Remove-Item -Force "backend\db.sqlite3" -ErrorAction SilentlyContinue

# ===== Xoá IDE files =====
Remove-Item -Force "frontend\frontend.iml" -ErrorAction SilentlyContinue

# ===== Xoá platform thừa (tuỳ chọn) =====
# Remove-Item -Recurse -Force "frontend\ios" -ErrorAction SilentlyContinue
# Remove-Item -Recurse -Force "frontend\web" -ErrorAction SilentlyContinue
# Remove-Item -Recurse -Force "frontend\linux" -ErrorAction SilentlyContinue
# Remove-Item -Recurse -Force "frontend\macos" -ErrorAction SilentlyContinue
# Remove-Item -Recurse -Force "frontend\windows" -ErrorAction SilentlyContinue
```

### 🧹 Lệnh dọn dẹp nhanh (Bash / Linux / macOS)

```bash
# ===== Xoá Python cache =====
find backend -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find backend -type f -name "*.pyc" -delete

# ===== Xoá Flutter build cache =====
rm -rf frontend/build frontend/.dart_tool frontend/android/.gradle
rm -rf frontend/android/app/build frontend/android/.idea

# ===== Xoá DB tạm =====
rm -f backend/db.sqlite3

# ===== Xoá IDE files =====
rm -f frontend/frontend.iml

# ===== Xoá platform thừa (tuỳ chọn) =====
# rm -rf frontend/ios frontend/web frontend/linux frontend/macos frontend/windows
```

### 📦 Dọn dẹp dependencies thừa trong `pubspec.yaml`

> ✅ **Đã hoàn tất:** `frontend/pubspec.yaml` hiện chỉ còn giữ các dependencies thực sự sử dụng:
>
> ```yaml
> dependencies:
>   flutter:
>     sdk: flutter
>   http: ^1.2.0                    # Gọi API Django
>   permission_handler: ^12.0.3    # Quản lý quyền truy cập
> ```
>
> Các gói đã được xoá trước đó (không cần làm lại): `watch_connectivity`, `pedometer`, `cupertino_icons`.

Sau khi thay đổi dependencies, chạy lại để cập nhật lockfile:

```bash
cd frontend
flutter pub get
```

### 🗂️ Cấu trúc dự án sau khi dọn dẹp

```
healthy_app/
├── README.md                           # Tài liệu dự án (file này)
├── TODO.md                             # Kế hoạch phát triển
│
├── backend/                            # 🖥️ Django Backend
│   ├── manage.py                       # CLI Django
│   ├── requirements.txt                # Dependencies Python
│   ├── core/                           # Project config
│   │   ├── __init__.py
│   │   ├── settings.py                 # Cấu hình Django
│   │   ├── urls.py                     # URL routing
│   │   ├── wsgi.py                     # WSGI entrypoint
│   │   └── asgi.py                     # ASGI entrypoint
│   ├── accounts/                       # Auth app (đang phát triển)
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── tests.py
│   │   ├── views.py
│   │   └── migrations/
│   │       └── __init__.py
│   └── health_metrics/                 # Health Metrics app ✅
│       ├── __init__.py
│       ├── admin.py                    # Django Admin config
│       ├── apps.py
│       ├── models.py                   # HealthData model
│       ├── serializers.py              # HealthDataSerializer
│       ├── tests.py
│       ├── urls.py                     # /api/health/ routing
│       ├── views.py                    # GET/POST handler
│       └── migrations/
│           ├── __init__.py
│           └── 0001_initial.py
│
└── frontend/                           # 📱 Flutter Frontend
    ├── pubspec.yaml                    # Dependencies
    ├── analysis_options.yaml           # Lint rules
    ├── lib/
    │   ├── main.dart                   # Phone App (Dashboard)
    │   ├── main_wear.dart              # Wear OS App
    │   └── services/
    │       ├── api_service.dart        # REST API Client
    │       ├── watch_service.dart      # HTTP Server listener
    │       └── watch_sender_service.dart # HTTP sender
    ├── test/
    │   └── widget_test.dart            # Widget test
    └── android/                        # Android platform config
        ├── build.gradle.kts
        ├── settings.gradle.kts
        ├── gradle.properties
        └── app/
            ├── build.gradle.kts
            └── src/
                ├── main/
                │   ├── AndroidManifest.xml
                │   ├── kotlin/.../
                │   │   └── MainActivity.kt
                │   └── res/.../
                ├── debug/
                │   └── AndroidManifest.xml
                └── profile/
                    └── AndroidManifest.xml
```

---

## 🛠️ Roadmap phát triển

> Chi tiết đầy đủ tại [TODO.md](./TODO.md)

| Mức độ | Mục tiêu | Thời gian dự kiến |
|:------:|----------|:-----------------:|
| 🔴 **Cao** | Bảo mật (Secret Key, Debug, CORS), Accounts App, Frontend implement, Sửa test | Tuần 1–2 |
| 🟡 **Trung bình** | Hiệu năng (pagination, batch API, validation), Testing (unit + widget), Flutter architecture | Tuần 3–4 |
| 🟢 **Thấp** | Code quality, UX/UI, Documentation, Deploy & CI/CD | Tuần 5–6 |

---

## 📚 Tài liệu bổ sung

> 📝 **Ghi chú:** Các tài liệu `ONBOARDING_GUIDE.md` và `CONNECTION_DEBUG_GUIDE.md` trước đây được link trong thư mục `docs/` hiện **không còn tồn tại** trong dự án. Nội dung hữu ích đã được tổng hợp trực tiếp vào README này (phần Hướng dẫn cài đặt, Kiểm tra luồng, và Quy trình dọn dẹp).

| Tài liệu | Mô tả | Vị trí |
|----------|-------|--------|
| 📋 **Kế hoạch phát triển** | TODO chi tiết theo từng tuần | `TODO.md` |
| 📖 **README này** | Giới thiệu, hướng dẫn cài đặt, API, dọn dẹp | `README.md` |

---

### 📄 License

Dự án này được phát triển với mục đích **học tập và quản lý sức khỏe cá nhân**.

---

> ⭐ **Nếu bạn thấy dự án hữu ích, hãy để lại một star trên GitHub!**
