# HealthyApp Dynamic & Static Audit Report

- Thời điểm tạo: 2026-10-22T17:25:58+07:00
- Chế độ: static audit + runtime test; chỉ ghi đè `audit_report.md`, không sửa `CHECKLIST.md`.
- Backend test sử dụng `--keepdb` để giữ nguyên database test đã có.

## Static Audit Findings

| Trạng thái | Hạng mục | Kết quả / giới hạn | Bằng chứng |
|---|---|---|---|
| **PASS / FOUND** | PersonProfile relation_type | Model khai báo field relation_type. | `backend/profiles/models.py:31` |
| **PASS / FOUND** | Profile serializer | Serializer có xử lý relation_type. | `backend/profiles/serializers.py:88` |
| **PASS / FOUND** | Backend permission service | Có cấu trúc permission dùng chung. | `backend/core/permissions.py:6` |
| **PASS / FOUND** | Profile scoped CRUD | ViewSet hồ sơ y tế lọc theo profile. | `backend/medical_records/views.py:302` |
| **PASS / FOUND** | Medical serializers | Có serializer cho các loại hồ sơ y tế. | `backend/medical_records/serializers.py:29` |
| **PASS / FOUND** | Medical routes | Các route hồ sơ được đăng ký qua DRF router. | `backend/medical_records/urls.py:15` |
| **PASS / FOUND** | AI Chat endpoint | Có endpoint nhận câu hỏi và xử lý hội thoại. | `backend/ai_services/views.py:112` |
| **PASS / FOUND** | Conversation history | Có endpoint liệt kê lịch sử hội thoại. | `backend/ai_services/views.py:182` |
| **PASS / FOUND** | Conversation messages | Có endpoint đọc tin nhắn hội thoại. | `backend/ai_services/views.py:202` |
| **PASS / FOUND** | AI consent check | Backend kiểm tra consent của hồ sơ. | `backend/ai_services/views.py:45` |
| **PASS / FOUND** | AI history serializers | Có serializer cho hội thoại và tin nhắn. | `backend/ai_services/serializers.py:6` |
| **PASS / FOUND** | AI API service | Service tích hợp API đánh giá nguy cơ và Chat. | `frontend/lib/services/ai_service.dart:89` |
| **PASS / FOUND** | AI assistant screen | Màn hình AI Assistant có trong ứng dụng. | `frontend/lib/views/home/ai_assistant_screen.dart:10` |
| **PASS** | Bearer token cho API lịch sử AI Chat | Không còn header Authorization hardcode dạng ******. | `frontend/lib/services/ai_service.dart` |
| **WARNING** | Device API mount | Route devices đang bị comment trong core URL config; module Wear Sync chưa có Device API mount. | `backend/core/urls.py` |
| **PASS / FOUND** | Báo cáo đồ án: DACN_Ngo_Quoc_Thien_Bao.docx | Tìm thấy báo cáo tại vị trí được hỗ trợ. | `docs/DACN_Ngo_Quoc_Thien_Bao.docx` |
| **PASS / FOUND** | CHECKLIST.md | Được tham chiếu chỉ đọc; script không ghi hoặc cập nhật file này. | `CHECKLIST.md` |

## Chương 3 - Kết quả Thực nghiệm & Kiểm thử Hệ thống

### Bảng 3.x. Kết quả kiểm thử Backend

Lệnh: `C:\Users\ASUS\AppData\Local\Programs\Python\Python313\python.exe manage.py test --keepdb --verbosity 2`  
Kết quả tổng: **PASS**; thời gian: **279.10 giây**; tổng pass: **79**; tổng fail/error: **0**; skip: **0**.

| Module | Số test chạy | Pass | Fail/Error | Skip | Trạng thái |
|---|---:|---:|---:|---:|---|
| Authentication & Consent | 8 | 8 | 0 | 0 | **PASS** |
| AI Insight & AI Chat | 18 | 18 | 0 | 0 | **PASS** |
| Core / Integration | 17 | 17 | 0 | 0 | **PASS** |
| Wear Sync / Device | 2 | 2 | 0 | 0 | **PASS** |
| Health Measurement | 2 | 2 | 0 | 0 | **PASS** |
| Household / RBAC | 9 | 9 | 0 | 0 | **PASS** |
| Medical Record | 19 | 19 | 0 | 0 | **PASS** |
| Profile | 4 | 4 | 0 | 0 | **PASS** |

### Bảng 3.y. Kiểm thử Frontend và phân tích tĩnh

| Công cụ | Số test / lỗi | Trạng thái | Thời gian | Ghi chú |
|---|---:|---|---:|---|
| `flutter test` | 11 pass / 0 fail | **PASS** | 19.35s | Widget/unit test |
| `flutter analyze` | 0 issue | **PASS** | 45.81s | Static analyzer |

### Bảng 3.z. Các API endpoint cốt lõi đã mount

Danh sách được lấy trực tiếp từ Django URL resolver sau khi nạp cấu hình ứng dụng; method lấy từ action map hoặc handler class.

| Method | Endpoint | Handler | URL name | Permission class |
|---|---|---|---|---|
| POST | `/api/auth/register/` | RegisterView | auth-register | AllowAny |
| POST | `/api/auth/login/` | LoginView | auth-login | AllowAny |
| PATCH | `/api/auth/profile/` | ProfileView | auth-profile | IsAuthenticated |
| GET, PATCH | `/api/auth/ai-consent/` | AiConsentView | auth-ai-consent | IsAuthenticated |
| POST | `/api/auth/logout/` | LogoutView | auth-logout | IsAuthenticated |
| POST | `/api/auth/refresh/` | TokenRefreshView | auth-refresh | None (view-defined) |
| POST | `/api/auth/token/` | TokenObtainPairView | token_obtain_pair | None (view-defined) |
| POST | `/api/auth/token/refresh/` | TokenRefreshView | token_refresh | None (view-defined) |
| GET, POST | `/api/profiles/` | ProfileListCreateView | profile-list | IsAuthenticated |
| DELETE, GET, PATCH, PUT | `/api/profiles/<uuid:pk>/` | ProfileDetailView | profile-detail | IsAuthenticated |
| GET, POST | `/api/households/` | HouseholdListCreateView | household-list | IsAuthenticated |
| GET | `/api/households/<uuid:household_id>/` | HouseholdDetailView | household-detail | IsAuthenticated |
| POST | `/api/households/<uuid:household_id>/leave/` | HouseholdLeaveView | household-leave | IsAuthenticated |
| GET, POST | `/api/households/<uuid:household_id>/members/` | HouseholdMemberListCreateView | household-member-list | IsAuthenticated |
| DELETE, PATCH | `/api/households/<uuid:household_id>/members/<uuid:member_id>/` | HouseholdMemberDetailView | household-member-detail | IsAuthenticated |
| GET | `/api/households/invitations/` | InvitationListView | invitation-list | IsAuthenticated |
| POST | `/api/households/invitations/<uuid:member_id>/respond/` | InvitationResponseView | invitation-respond | IsAuthenticated |
| POST | `/api/medical/measurements/batch/` | HealthMeasurementBatchCreateView | measurement-batch | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/measurements/` | HealthMeasurementViewSet | measurement-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/measurements/<pk>/` | HealthMeasurementViewSet | measurement-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/documents/` | MedicalDocumentViewSet | medical-document-list | IsAuthenticated |
| DELETE, GET | `/api/medical/documents/<pk>/` | MedicalDocumentViewSet | medical-document-detail | IsAuthenticated |
| GET | `/api/medical/documents/<pk>/download/` | MedicalDocumentViewSet | medical-document-download | IsAuthenticated |
| GET, POST | `/api/medical/histories/` | MedicalHistoryViewSet | medical-history-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/histories/<pk>/` | MedicalHistoryViewSet | medical-history-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/allergies/` | AllergyViewSet | allergy-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/allergies/<pk>/` | AllergyViewSet | allergy-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/visits/` | VisitViewSet | visit-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/visits/<pk>/` | VisitViewSet | visit-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/medications/` | MedicationViewSet | medication-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/medications/<pk>/` | MedicationViewSet | medication-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical/lab-results/` | LabResultViewSet | lab-result-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical/lab-results/<pk>/` | LabResultViewSet | lab-result-detail | IsProfileOwnerOrShared |
| GET | `/api/medical/` | APIRootView | api-root | IsAuthenticated |
| GET | `/api/medical/<drf_format_suffix:format>` | APIRootView | api-root | IsAuthenticated |
| POST | `/api/medical-records/measurements/batch/` | HealthMeasurementBatchCreateView | measurement-batch | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/measurements/` | HealthMeasurementViewSet | measurement-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/measurements/<pk>/` | HealthMeasurementViewSet | measurement-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/documents/` | MedicalDocumentViewSet | medical-document-list | IsAuthenticated |
| DELETE, GET | `/api/medical-records/documents/<pk>/` | MedicalDocumentViewSet | medical-document-detail | IsAuthenticated |
| GET | `/api/medical-records/documents/<pk>/download/` | MedicalDocumentViewSet | medical-document-download | IsAuthenticated |
| GET, POST | `/api/medical-records/histories/` | MedicalHistoryViewSet | medical-history-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/histories/<pk>/` | MedicalHistoryViewSet | medical-history-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/allergies/` | AllergyViewSet | allergy-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/allergies/<pk>/` | AllergyViewSet | allergy-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/visits/` | VisitViewSet | visit-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/visits/<pk>/` | VisitViewSet | visit-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/medications/` | MedicationViewSet | medication-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/medications/<pk>/` | MedicationViewSet | medication-detail | IsProfileOwnerOrShared |
| GET, POST | `/api/medical-records/lab-results/` | LabResultViewSet | lab-result-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/medical-records/lab-results/<pk>/` | LabResultViewSet | lab-result-detail | IsProfileOwnerOrShared |
| GET | `/api/medical-records/` | APIRootView | api-root | IsAuthenticated |
| GET | `/api/medical-records/<drf_format_suffix:format>` | APIRootView | api-root | IsAuthenticated |
| POST | `/api/health-measurements/batch/` | HealthMeasurementBatchCreateView | measurement-batch | IsProfileOwnerOrShared |
| GET, POST | `/api/health-measurements/` | HealthMeasurementViewSet | measurement-list | IsProfileOwnerOrShared |
| DELETE, GET, PATCH, PUT | `/api/health-measurements/<uuid:pk>/` | HealthMeasurementViewSet | measurement-detail | IsProfileOwnerOrShared |
| GET | `/api/ai/conversations/` | AiConversationListView | ai-conversation-list | IsAuthenticated |
| GET | `/api/ai/conversations/<uuid:conversation_id>/messages/` | AiConversationMessagesView | ai-conversation-messages | IsAuthenticated |
| GET | `/api/ai/assess-risk/<uuid:profile_id>/` | HealthRiskAssessmentView | ai-risk-assessment | IsAuthenticated |
| POST | `/api/ai/chat/<uuid:profile_id>/` | AiChatSessionView | ai-chat-session | IsAuthenticated |

## Giới hạn và diễn giải

- Số lượng test/module lấy từ output verbose lúc chạy. Nếu runner dừng trước summary, trạng thái được ghi UNKNOWN hoặc NOT RUN, không suy diễn thành pass.
- Route table xác nhận URL đã mount trong Django; không thay thế kiểm thử quyền, response contract hay tích hợp thiết bị thực.
- Kết quả Flutter phụ thuộc Flutter SDK và dependencies đã được cài trong môi trường chạy.
