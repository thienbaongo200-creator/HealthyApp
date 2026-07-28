# Healthy App 🏥

Ứng dụng quản lý sức khỏe cá nhân với kiến trúc **Backend (Django) + Frontend (Flutter)**.

---

## 📁 Tổng quan cấu trúc dự án

```
healthy_app/
├── venv                   
├── README.md                     # Tài liệu dự án (file này)
├── backend/                      # Backend API - Django 6.0.6
│   ├── manage.py                 # Django CLI quản lý project
│   ├── accounts/                 # App: Quản lý tài khoản người dùng
│   │   ├── __init__.py
│   │   ├── admin.py              # Cấu hình admin (đang trống)
│   │   ├── apps.py               # AppConfig: name = 'health_app'
│   │   ├── models.py             # Models (đang trống)
│   │   ├── tests.py              # Unit tests (đang trống)
│   │   ├── views.py              # Views (đang trống)
│   │   └── migrations/
│   │       └── __init__.py
│   ├── core/                     # Django project config chính
│   │   ├── __init__.py
│   │   ├── asgi.py               # ASGI config (cho async/WebSocket)
│   │   ├── settings.py           # Settings: SQLite, Debug=True, chưa có app tùy chỉnh
│   │   ├── urls.py               # URL routing (chỉ có admin/)
│   │   └── wsgi.py               # WSGI config (cho deploy truyền thống)
│   └── health_metrics/           # App: Quản lý chỉ số sức khỏe
│       ├── __init__.py
│       ├── admin.py              # Cấu hình admin (đang trống)
│       ├── apps.py               # AppConfig: name = 'health_project'
│       ├── models.py             # Models (đang trống)
│       ├── tests.py              # Unit tests (đang trống)
│       ├── views.py              # Views (đang trống)
│       └── migrations/
│           └── __init__.py
└── frontend/                     # Frontend Mobile App - Flutter
    ├── pubspec.yaml              # Cấu hình pub: Dart SDK ^3.12.2
    ├── pubspec.lock              # Lock file dependencies
    ├── analysis_options.yaml     # Linting rules
    ├── README.md                 # README mặc định của Flutter
    ├── lib/
    │   └── main.dart             # Entry point: Counter app mặc định
    ├── test/
    │   └── widget_test.dart      # Widget test mặc định
    ├── android/                  # Cấu hình nền tảng Android
    │   ├── build.gradle.kts
    │   ├── settings.gradle.kts
    │   ├── gradle.properties
    │   └── app/
    │       └── build.gradle.kts
    ├── ios/                      # Cấu hình nền tảng iOS
    │   ├── Runner/
    │   ├── Runner.xcodeproj/
    │   └── Runner.xcworkspace/
    ├── web/                      # Cấu hình nền tảng Web
    │   ├── index.html
    │   ├── manifest.json
    │   └── icons/
    ├── linux/                    # Cấu hình nền tảng Linux Desktop
    │   ├── CMakeLists.txt
    │   ├── flutter/
    │   └── runner/
    ├── macos/                    # Cấu hình nền tảng macOS Desktop
    │   ├── Flutter/
    │   ├── Runner/
    │   └── Runner.xcodeproj/
    └── windows/                  # Cấu hình nền tảng Windows Desktop
        ├── CMakeLists.txt
        ├── flutter/
        └── runner/
```

---

## 🏗️ Kiến trúc chi tiết

### Backend — Django (`backend/`)

| Thành phần | Mô tả |
|-----------|-------|
| **Django version** | 6.0.6 |
| **Database** | SQLite (`db.sqlite3`) |
| **Debug** | `True` (đang ở chế độ development) |
| **Project name** | `core` |
| **Apps** | `accounts` (health_app) — quản lý người dùng, `health_metrics` (health_project) — quản lý chỉ số sức khỏe |
| **URLs** | Chỉ có route `/admin/` |
| **Tình trạng** | Đang trong giai đoạn khởi tạo — models, views, admin đều là boilerplate |

#### Các app backend

1. **`accounts`** — App xác thực & quản lý người dùng
   - AppConfig: `health_app`
   - Models: chưa định nghĩa
   - Views: chưa implement
   - Admin: chưa đăng ký

2. **`health_metrics`** — App quản lý chỉ số sức khỏe
   - AppConfig: `health_project`
   - Models: chưa định nghĩa
   - Views: chưa implement
   - Admin: chưa đăng ký

### Frontend — Flutter (`frontend/`)

| Thành phần | Mô tả |
|-----------|-------|
| **Dart SDK** | `^3.12.2` |
| **Version** | `1.0.0+1` |
| **Framework** | Flutter với Material Design |
| **Entry point** | `lib/main.dart` (Counter app mặc định) |
| **Nền tảng hỗ trợ** | Android, iOS, Web, Linux, macOS, Windows |

#### Flutter dependencies chính
- `flutter` (SDK)
- `cupertino_icons: ^1.0.8`
- `flutter_test` (dev)
- `flutter_lints: ^6.0.0` (dev)

---

## 🚀 Hướng dẫn chạy dự án

### Yêu cầu

| Công nghệ | Phiên bản (khuyến nghị) |
|-----------|------------------------|
| Python | >= 3.10 |
| Django | 6.0.6 |
| Flutter | Tương thích Dart SDK ^3.12.2 |
| Dart | ^3.12.2 |

### Backend

```bash
# Di chuyển vào thư mục backend
cd backend

# Tạo virtual environment (khuyến nghị)
python -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate   # Windows

# Cài đặt dependencies
pip install django

# Chạy migrations
python manage.py migrate

# Tạo superuser (cho admin)
python manage.py createsuperuser

# Chạy development server
python manage.py runserver
```

Truy cập: http://localhost:8000/admin/

### Frontend

```bash
# Di chuyển vào thư mục frontend
cd frontend

# Cài đặt dependencies
flutter pub get

# Chạy app
flutter run
```

---

## 🗺️ Lộ trình phát triển (suggested)

- [ ] **Backend**: Định nghĩa Models cho User profiles & Health Metrics
- [ ] **Backend**: Xây dựng REST API endpoints
- [ ] **Backend**: Kết nối & cấu hình CORS cho Flutter
- [ ] **Frontend**: Thiết kế UI màn hình chính
- [ ] **Frontend**: Kết nối API backend
- [ ] **Frontend**: Xử lý authentication (login/register)
- [ ] **Backend**: Thêm unit tests & API tests
- [ ] **Deploy**: Cấu hình production (DEBUG=False, database production, v.v.)

---

## 📄 License

Dự án này được phát triển với mục đích học tập và quản lý sức khỏe cá nhân.

