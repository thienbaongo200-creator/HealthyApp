# Báo cáo rà soát bảo mật — Sprint 2

- **Ngày:** 2026-10-13
- **Phạm vi:** PermissionService, RBAC, chia sẻ hồ sơ, chống IDOR, quản lý Household và test liên quan.
- **Kết luận:** Sprint 2 chưa đạt Definition of Done. Rà soát không xác nhận được khai thác trái phép trên endpoint hiện có; tuy nhiên, các thiếu sót kiểm soát và test dưới đây ngăn việc nghiệm thu bảo mật.

## Phát hiện

| # | Severity | File | Lines | Phát hiện | Confidence |
|---|----------|------|-------|-----------|------------|
| 1 | 🟡 MEDIUM | [backend/medical_records/views.py](./backend/medical_records/views.py) | 35-37, 40-49 | Measurement queryset dùng `ProfileShare.can_view`/`is_active` không tồn tại và lọc `member` bằng tập `PersonProfile`. List/detail chưa được chứng minh hoạt động hoặc giới hạn đúng. Nhánh household thu thập mọi profile ACTIVE mà không ràng buộc role/share; nếu chỉ sửa lỗi truy vấn mà giữ phạm vi này, có nguy cơ cấp quyền quá rộng. Không xác nhận đã có rò rỉ dữ liệu. | 9/10 |
| 2 | 🟡 MEDIUM | [backend/core/permissions.py](./backend/core/permissions.py) | 52-60 | Nhánh cấp quyền ProfileShare không kiểm tra HouseholdMember có trạng thái ACTIVE, trong khi membership có thể PENDING. Chưa xác nhận được route hiện tại cho phép khai thác trạng thái này; cần xác minh trạng thái membership trước khi áp dụng share. | 8/10 |
| 3 | ⚪ LOW | [backend/households/views.py](./backend/households/views.py) | 1-3 | Chưa có API quản lý Household tương ứng; vì vậy chưa có kiểm soát thực thi Owner-only, bảo vệ Owner duy nhất hoặc giới hạn phản hồi invitation cho invitee. Đây là thiếu sót triển khai trong phạm vi Sprint 2, không phải khai thác đã xác nhận. | 10/10 |
| 4 | ⚪ LOW | [backend/core/tests/test_permissions.py](./backend/core/tests/test_permissions.py) | 39-65 | Test hiện có kiểm tra owner, outsider và quyền share ở service-level nhưng chưa phủ caregiver, household-owner với hồ sơ khác, PENDING membership hoặc HTTP authorization. Không có test API chứng minh IDOR/list-detail hoặc kiểm soát retrieve/create/update/partial_update/destroy. | 10/10 |

## Kiểm soát đã xác nhận một phần

- [backend/core/settings.py](./backend/core/settings.py) cấu hình JWT authentication và `IsAuthenticated` mặc định.
- [backend/core/permissions.py](./backend/core/permissions.py) có `PermissionService` kiểm tra đăng nhập, quyền owner, membership OWNER ACTIVE và cấp chia sẻ `VIEW_ONLY`/`VIEW_AND_LOG`.
- [backend/medical_records/serializers.py](./backend/medical_records/serializers.py) không cho serializer measurement nhận trường `profile` tùy ý; batch endpoint gán profile SELF của tài khoản đã xác thực.
- Batch endpoint kiểm tra quyền ghi và trả 403 khi target profile bị từ chối.

Các biện pháp trên không chứng minh toàn bộ endpoint dữ liệu cá nhân được bảo vệ. Router medical hiện chỉ đăng ký measurements; chưa xác minh được CRUD profile/household hoặc kiểm soát object-level trên đầy đủ phương thức HTTP.

## Kiểm thử được rà soát

- [backend/core/tests/test_permissions.py](./backend/core/tests/test_permissions.py): owner, outsider, `VIEW_ONLY` và `VIEW_AND_LOG` ở service-level.
- [backend/medical_records/tests.py](./backend/medical_records/tests.py): batch creation/idempotency; chưa có kiểm tra 403/IDOR.
- [backend/households/tests.py](./backend/households/tests.py): ràng buộc model/cascade; chưa có test luồng mời, quản lý quyền hoặc owner duy nhất.

## Hướng xử lý

1. Sửa queryset measurement dựa trên quan hệ và field thật của `ProfileShare`, chỉ đưa profile vào queryset khi role/membership/share grant quyền tương ứng; viết test list/detail chéo profile.
2. Buộc share path xác minh membership ACTIVE và áp dụng ma trận role/share thống nhất cho đọc/ghi.
3. Trước khi mở API Household, triển khai kiểm tra Owner-only, giữ lại Owner cuối cùng và chỉ cho invitee phản hồi lời mời.
4. Bổ sung API tests cho Owner/Member/Caregiver, PENDING, user ngoài Household, IDOR bằng profile ID trên URL/body, 403 khi ghi với `VIEW_ONLY`, và giới hạn thao tác của `VIEW_AND_LOG`.
