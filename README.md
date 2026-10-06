# Healthy App

Healthy App là ứng dụng theo dõi sức khỏe cá nhân gồm ứng dụng Flutter cho điện thoại, ứng dụng Flutter cho Wear OS và backend Django REST Framework. Wear OS hiện tạo dữ liệu mô phỏng; ứng dụng Phone nhận snapshot từ đồng hồ, gom thành batch và gửi lên backend để lưu theo tài khoản.

> Dự án hiện tập trung vào đăng ký/đăng nhập JWT, hồ sơ cá nhân và bản ghi sức khỏe. Dữ liệu Wear OS hiện là dữ liệu mô phỏng, không phải dữ liệu đo y tế hoặc cảm biến thật.

## Kiến trúc hệ thống

```text
Wear OS Emulator
  └─ HTTP POST http://localhost:8080/sync
       │ adb reverse (Wear Emulator → máy tính)
       │ adb forward (máy tính → Phone thật)
       ▼
Phone thật — Flutter
  ├─ HTTP listener :8080 nhận snapshot từ đồng hồ
  ├─ Gom measurement và gửi batch có JWT
  └─ Gọi Django API qua Wi-Fi LAN: 192.168.1.3:8000
       ▼
Django + Django REST Framework
  └─ PostgreSQL trên máy tính
```

Phone và máy tính cần cùng mạng Wi-Fi. Wear OS chạy trong Android Emulator và dùng hai đường chuyển tiếp ADB để gửi snapshot qua máy tính đến HTTP listener trên Phone. Backend Django phải lắng nghe trên `0.0.0.0:8000` để thiết bị Phone truy cập được qua LAN.

```text
HealthyApp/
├── backend/
│   ├── manage.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── core/                 # Settings và URL gốc của Django
│   ├── accounts/             # Đăng ký, đăng nhập, profile, JWT
│   └── medical_records/      # Profile và health measurements
└── frontend/
    ├── assets/images/        # Asset Flutter
    ├── lib/main.dart         # Điểm vào ứng dụng Phone
    ├── lib/main_wear.dart    # Điểm vào ứng dụng Wear OS
    ├── lib/services/         # API, auth, listener và sender
    ├── lib/views/            # Màn hình đăng nhập, hồ sơ và dashboard
    └── lib/widgets/
```

## Phiên bản công nghệ

Các phiên bản dưới đây được đối chiếu với cấu hình dự án và môi trường hiện có ngày **05/10/2026**. “Đã cài” là phiên bản tìm thấy trong môi trường trên máy hiện tại; “khai báo” là phiên bản yêu cầu trong manifest của repo. Các constraint bắt đầu bằng `^` là khoảng phiên bản tương thích, không phải một phiên bản cố định.

| Công nghệ | Khai báo/cấu hình dự án | Đã cài hoặc đã resolve trên máy hiện tại |
|---|---|---|
| Python | `requirements.txt` không pin Python; môi trường nên dùng Python 3.13 | Python **3.13.14** trong `backend/venv` |
| Django | `Django==6.1` trong `backend/requirements.txt` | Django **6.0.6** trong `backend/venv` |
| Django REST Framework | `djangorestframework==3.18.0` | **3.17.1** trong `backend/venv` |
| django-cors-headers | `4.9.0` | **4.9.0** |
| djangorestframework-simplejwt | `5.5.1` | **5.5.1** |
| psycopg2-binary | `2.9.12` | **2.9.12** |
| PyJWT | `2.13.0` | **2.13.0** |
| python-dotenv | `1.1.1` | **1.2.3** |
| python-decouple | `3.8` | **3.8** |
| Flutter | Yêu cầu tối thiểu theo `pubspec.lock`: Flutter `>=3.38.4` | Flutter **3.47.5 stable** |
| Dart | `environment.sdk: ^3.12.2` trong `pubspec.yaml` | Dart **3.13.4** |
| `http` | Constraint `^1.2.0` | **1.6.0** trong `pubspec.lock` |
| `dio` | Constraint `^5.11.1` | **5.11.1** |
| `permission_handler` | Constraint `^12.0.3` | **12.0.3** |
| `google_sign_in` | Constraint `^6.2.1` | **6.3.0** |
| `flutter_secure_storage` | Constraint `^11.1.1` | **11.1.1** |
| Android Gradle Plugin | `settings.gradle.kts` | **9.0.1** |
| Kotlin Gradle Plugin | `settings.gradle.kts` | **2.3.20** |
| Gradle Wrapper | `gradle-wrapper.properties` | **9.1.0** |
| Java target / Android min SDK | `app/build.gradle.kts` | Java target **17**; Android `minSdk = 28` |
| PostgreSQL Server | Backend dùng engine `django.db.backends.postgresql`; repo không pin phiên bản server | Chưa xác định từ source; tài liệu dự án yêu cầu PostgreSQL **14+** |

**Lưu ý về backend:** môi trường `backend/venv` đang lệch với `requirements.txt`: Django đang là 6.0.6 thay vì 6.1, DRF là 3.17.1 thay vì 3.18.0, và `python-dotenv` là 1.2.3 thay vì 1.1.1. Cài requirements vào một virtual environment mới sẽ sử dụng các phiên bản pin trong file. Không xem phiên bản đang cài và phiên bản yêu cầu là đồng nhất.

## Yêu cầu môi trường

- Windows, macOS hoặc Linux; các ví dụ bên dưới dùng PowerShell trên Windows.
- Python **3.13** và `pip`.
- PostgreSQL **14 trở lên**, đã cài và đang chạy; tạo database cùng tài khoản dùng cho ứng dụng.
- Flutter SDK **3.38.4 trở lên** và Dart theo `frontend/pubspec.yaml`.
- Android Studio/Android SDK, JDK 17-compatible với Android Gradle Plugin của dự án, ADB và Wear OS Emulator.
- Điện thoại Android thật bật USB debugging; Phone và máy tính cùng mạng Wi-Fi.
- IP Wi-Fi của máy tính trong cấu hình hiện tại: **`192.168.1.3`**. Nếu địa chỉ DHCP thay đổi, cập nhật `.env` hoặc truyền URL mới bằng `--dart-define`.

## Cài đặt Backend

Mở PowerShell tại thư mục dự án:

```powershell
cd D:\HealthyApp\backend
py -3.13 -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
Copy-Item .env.example .env
```

Sửa `backend/.env` với thông tin PostgreSQL trên máy tính. Các tên biến dưới đây được hỗ trợ bởi `backend/core/settings.py`:

```dotenv
SECRET_KEY=<chuỗi bí mật đủ dài>
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,192.168.1.3,10.0.2.2

DB_NAME=healthapp
DB_USER=healthy_user
DB_PASSWORD=<mật khẩu PostgreSQL>
DB_HOST=localhost
DB_PORT=5432

CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

Tạo database `healthapp` và user PostgreSQL tương ứng trước khi chạy migration. Từ thư mục `backend`, chạy:

```powershell
python manage.py migrate
python manage.py check
python manage.py test
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:8000
```

Backend lắng nghe trên mọi interface tại cổng `8000`; Phone truy cập API qua `http://192.168.1.3:8000`. Cho phép cổng `8000` qua firewall Windows. `backend/.env` chứa secret và mật khẩu, không commit file này.

## Chạy hệ thống: Phone thật + Wear OS Emulator + Django

### Bước 1 — Khởi chạy Backend

Thực hiện cài đặt và cấu hình Backend ở trên. Giữ terminal chạy Django:

```powershell
cd D:\HealthyApp\backend
.\venv\Scripts\Activate.ps1
python manage.py runserver 0.0.0.0:8000
```

Lưu ý: Đảm bảo máy tính và điện thoại kết nối cùng một mạng Wi-Fi. (IP LAN của máy tính trong ví dụ này là 192.168.1.5)

### Bước 2 — Khởi chạy App trên điện thoại thật

Kết nối điện thoại qua Gỡ lỗi không dây (Wireless Debugging):
- Trên điện thoại, vào Cài đặt > Tùy chọn nhà phát triển > Bật gỡ lỗi không dây.
- Chọn ghép nối thiết bị (bằng mã QR hoặc mã ghép nối) với Android Studio trên máy tính để thiết lập kết nối không dây

Kiểm tra thiết bị: 
- Mở terminal và chạy lệnh sau để lấy device ID thực tế của điện thoại:

```powershell
adb devices
```

Lấy IP LAN của máy tính:
- Chạy lệnh trên PowerShell để tìm địa chỉ IPv4 của Wi-Fi:

```powershell
ipconfig (Ví dụ: 192.168.1.5)
```

Chạy từ thư mục Flutter:

```powershell
cd D:\HealthyApp\frontend
flutter pub get
flutter run -t lib/main.dart -d <YOUR_DEVICE_ID> --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000/api
```

Ví dụ thực tế: 
```powershell
flutter run -t lib/main.dart -d adb-R5CX826Q9VB-IjsOKx._adb-tls-connect._tcp --dart-define=API_BASE_URL=[http://192.168.1.5:8000/api](http://192.168.1.5:8000/api)
```

Trong ứng dụng, mở dashboard để Phone khởi tạo HTTP listener tại cổng `8080`. API URL mặc định đã trỏ tới IP trên, nhưng lệnh trên truyền giá trị rõ ràng để có thể dễ thay đổi nếu IP máy tính đổi.

### Bước 3 — Tạo ADB forward/reverse cho Wear OS Emulator

Khởi động Wear OS Emulator trong Android Studio, giữ điện thoại kết nối qua ADB và xác định đúng hai device ID bằng `adb devices`. Mở terminal mới và chạy:

```powershell
adb -s <phone-device-id> forward tcp:8080 tcp:8080
adb -s <wear-device-id> reverse tcp:8080 tcp:8080
```

`adb reverse` chuyển cổng `8080` trên Wear Emulator về cổng `8080` của máy tính; `adb forward` chuyển tiếp cổng máy tính tới listener trên Phone thật. Giữ cả hai kết nối ADB hoạt động trong khi thử nghiệm. Nếu thiết bị ngắt kết nối, chạy lại các lệnh này.

### Bước 4 — Khởi chạy Wear OS app và kiểm tra đồng bộ

Mở terminal khác:

```powershell
cd D:\HealthyApp\frontend
flutter run -t lib/main_wear.dart -d <wear-device-id> --dart-define=WATCH_SYNC_URL=http://localhost:8080/sync
```

Wear OS mặc định dùng `http://localhost:8080/sync`; `WATCH_SYNC_URL` ở trên ghi rõ endpoint cho emulator. Mở chế độ **Vận động** để gửi mẫu mỗi 5 giây; chế độ nghỉ gửi mỗi 60 giây. Kiểm tra log của Phone để xác nhận có nhận snapshot và sau đó đồng bộ batch lên Django.

## API chính

Các endpoint được đăng ký trong `backend/core/urls.py` và app URLs:

| Method | Endpoint | Mục đích | Quyền |
|---|---|---|---|
| `POST` | `/api/auth/register/` | Tạo tài khoản và profile | Công khai |
| `POST` | `/api/auth/login/` | Đăng nhập, trả JWT | Công khai |
| `PATCH` | `/api/auth/profile/` | Cập nhật profile người dùng hiện tại | JWT |
| `POST` | `/api/auth/logout/` | Logout/revoke refresh token | JWT |
| `POST` | `/api/auth/token/refresh/` | Cấp access token mới | Refresh token |
| `GET`, `POST` | `/api/medical/measurements/` | Liệt kê/tạo measurement của người dùng | JWT |
| `GET`, `PUT`, `PATCH`, `DELETE` | `/api/medical/measurements/<id>/` | Đọc/sửa/xóa measurement thuộc người dùng | JWT |
| `POST` | `/api/medical/measurements/batch/` | Tạo nhiều measurement trong một request | JWT |

Đăng nhập bằng Flutter gọi `POST /api/auth/login/` với JSON `{"account":"<username-or-email>","password":"<password>"}`. `account` được hỗ trợ bởi `LoginView` tùy chỉnh; đây không phải payload mặc định của `TokenObtainPairView`. Lỗi kết nối, timeout và mã HTTP được ghi dưới tag `LoginScreen`; xem trên thiết bị bằng `flutter logs -d <phone-device-id>`. Không ghi password hoặc JWT vào log.

Measurement lưu `device_id`, `measured_at`, `idempotency_key`, `heart_rate`, `steps`, `calories` và `activity_state`. Mỗi batch nhận tối đa 500 mẫu; endpoint liệt kê phân trang 100 bản ghi. Backend lọc dữ liệu theo người dùng đã xác thực và dùng cặp profile + idempotency key để chống tạo trùng khi gửi lại.

## Kiểm tra Flutter

Từ `frontend/`:

```powershell
flutter analyze
flutter test
```

## Ghi chú triển khai và bảo mật

- HTTP và `android:usesCleartextTraffic="true"` hiện phục vụ phát triển trong mạng LAN. Production cần HTTPS và cấu hình Android Network Security phù hợp.
- `DEBUG=True` và các host LAN chỉ dùng trong môi trường phát triển; trước khi triển khai cần tắt debug, giới hạn `ALLOWED_HOSTS`, CORS và quản lý secret ngoài Git.
- CORS chủ yếu áp dụng cho trình duyệt/Flutter Web; app Flutter Android native gọi API không chịu chính sách CORS của trình duyệt.
- Dữ liệu Wear OS hiện là dữ liệu mô phỏng, không thay thế tư vấn hoặc chẩn đoán y tế.
- Không commit `backend/.env`, mật khẩu, khóa ký ứng dụng hoặc file tài liệu cá nhân.

## License

Dự án phục vụ mục đích học tập và quản lý sức khỏe cá nhân.

## LAN troubleshooting (physical Android phone)

`API_BASE_URL` is a compile-time `String.fromEnvironment` value. The default `10.0.2.2` is for Android Emulator only. For a real phone, use the current IPv4 address of the PC's Wi-Fi adapter; `localhost` on the phone means the phone itself. Wireless ADB installs and debugs the app but does not tunnel API traffic.

On Windows, run `ipconfig`, identify the Wi-Fi IPv4 address (not `169.254.x.x`), then start Django bound to all interfaces:

```powershell
cd D:\HealthyApp\backend
python manage.py runserver 0.0.0.0:8000
```

Verify Django locally and the listening port from Windows:

```powershell
curl.exe -i http://127.0.0.1:8000/api/auth/login/
Test-NetConnection -ComputerName <LAN-IP> -Port 8000
```

A `405 Method Not Allowed` for GET on the login URL still confirms the server was reached. From the phone browser, open `http://<LAN-IP>:8000/`. If local PC access works but phone access fails, check that Windows classifies Wi-Fi as a Private network, allow inbound TCP 8000 in Windows Firewall, and check the router for AP/client isolation. Ensure phone and PC are on the same non-guest network.

Run the app with the actual PC address (replace the placeholder):

```powershell
cd D:\HealthyApp\frontend
flutter run -t lib/main.dart -d <phone-device-id> --dart-define=API_BASE_URL=http://<LAN-IP>:8000/api
```

Inspect device logs and the URL logged by ApiService:

```powershell
flutter logs -d <phone-device-id>
adb -s <phone-device-id> logcat -c
adb -s <phone-device-id> logcat | Select-String 'ApiService|LoginScreen|CLEARTEXT|SocketException|Connection refused'
```

Login posts JSON `{"account":"username-or-email","password":"..."}` to `POST /api/auth/login/`; the custom Django view accepts that shape and returns an `access` JWT. It allows anonymous login and does not require a CSRF token because the API uses JWT, not session authentication. CORS is enforced by browsers and does not block native Android HTTP requests. Never log passwords or JWTs.
