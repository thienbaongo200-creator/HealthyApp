# Báo cáo rà soát bảo mật — Sprint 2

- **Ngày:** 2026-10-13
- **Phạm vi:** PermissionService, RBAC, chia sẻ hồ sơ, chống IDOR, quản lý Household và test liên quan.
- **Kết luận ban đầu:** Sprint 2 chưa đạt Definition of Done. Rà soát không xác nhận được khai thác trái phép trên endpoint hiện có; tuy nhiên, các thiếu sót kiểm soát và test dưới đây ngăn việc nghiệm thu bảo mật.
- **Cập nhật xác minh sau sửa:** hai vấn đề measurement queryset và active-membership share path được đánh dấu đã sửa theo phần dưới đây. Sprint 2 vẫn chưa đạt DoD do các thiếu sót Household API và test ma trận/IDOR còn lại.

## Phát hiện

| # | Severity | File | Lines | Phát hiện | Confidence |
|---|----------|------|-------|-----------|------------|
| 1 | ⚪ LOW | [backend/households/views.py](./backend/households/views.py) | 1-3 | Chưa có API quản lý Household tương ứng; vì vậy chưa có kiểm soát thực thi Owner-only, bảo vệ Owner duy nhất hoặc giới hạn phản hồi invitation cho invitee. Đây là thiếu sót triển khai trong phạm vi Sprint 2, không phải khai thác đã xác nhận. | 10/10 |
| 2 | ⚪ LOW | [backend/core/tests/test_permissions.py](./backend/core/tests/test_permissions.py) | 39-65 | Test hiện có kiểm tra owner, outsider và quyền share ở service-level nhưng chưa phủ caregiver, household-owner với hồ sơ khác, PENDING membership hoặc HTTP authorization. Không có test API chứng minh IDOR/list-detail hoặc kiểm soát retrieve/create/update/partial_update/destroy. | 10/10 |

## Follow-up fixes verified

- **FIXED — Measurement queryset relation/fields:** `HealthMeasurementViewSet.get_queryset()` now filters shares using `member__profile`, active membership, and `share_level`, matching the actual `ProfileShare` model fields.
- **FIXED — Active share membership:** `PermissionService` now requires the linked `HouseholdMember` to be ACTIVE before granting share access.
- **FIXED — Cross-household role scope (previous HIGH finding):** household profiles are included only from household IDs where this user has an ACTIVE OWNER membership. A regression test verifies that an account who is OWNER in one household but only MEMBER in another cannot list measurements from the second household.
- **Validation:** `manage.py test medical_records.tests` passed (6 tests); the regression test plus `core.tests.test_permissions` passed (4 tests); `git diff --check` passed.

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

1. Trước khi mở API Household, triển khai kiểm tra Owner-only, giữ lại Owner cuối cùng và chỉ cho invitee phản hồi lời mời.
2. Bổ sung API tests cho Owner/Member/Caregiver, PENDING, user ngoài Household, IDOR bằng profile ID trên URL/body, 403 khi ghi với `VIEW_ONLY`, và giới hạn thao tác của `VIEW_AND_LOG`.
