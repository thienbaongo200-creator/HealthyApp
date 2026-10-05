# PROJECT PLAN

## 1. Mục tiêu
Xây dựng phần mềm quản lý hồ sơ sức khỏe cá nhân và gia đình, tích hợp dữ liệu sức khỏe từ Wear OS và AI hỗ trợ phân tích, cảnh báo mang tính tham khảo[cite: 1].

---

## 2. Công nghệ
- **Backend:** Django + Django REST Framework[cite: 1]
- **Database:** PostgreSQL[cite: 1]
- **Mobile:** Flutter[cite: 1]
- **Wearable:** Wear OS[cite: 1]
- **Authentication:** JWT + Refresh Token[cite: 1]
- **AI:** Rule-based Engine + AI Provider[cite: 1]

---

## 3. Phạm vi MVP

### Bắt buộc
- Authentication
- Google Login
- JWT Access/Refresh Token[cite: 1]
- PersonProfile[cite: 1]
- Household[cite: 1]
- HouseholdMember[cite: 1]
- Medical Records (Visit, LabResult, Medication, MedicalDocument)[cite: 1]
- HealthMeasurement[cite: 1]
- Wear OS[cite: 1]
- Offline queue[cite: 1]
- Batch sync[cite: 1]
- Retry[cite: 1]
- idempotency_key[cite: 1]
- Rule-based Engine[cite: 1]
- AI Provider[cite: 1]
- AIInsight[cite: 1]
- AI Chat[cite: 1]

### Không thực hiện
- Chẩn đoán bệnh[cite: 1]
- Machine Learning training[cite: 1]
- Dự đoán xác suất mắc bệnh[cite: 1]
- OCR tài liệu[cite: 1]
- Phân tích hình ảnh y tế[cite: 1]
- ECG[cite: 1]
- SpO2[cite: 1]
- Quản lý bệnh viện[cite: 1]
- Quản lý bác sĩ[cite: 1]
- Family tree phức tạp[cite: 1]
- Local LLM[cite: 1]
- Real-time streaming[cite: 1]

---

## 4. Nguyên tắc phát triển
1. Không phá vỡ chức năng đang hoạt động nếu không cần thiết.
2. Kiểm tra code hiện tại trước khi sửa.
3. Ưu tiên hoàn thiện MVP trước chức năng nâng cao.
4. AI chỉ hỗ trợ phân tích và tạo insight tham khảo[cite: 1].
5. Không xem AI là công cụ chẩn đoán y khoa[cite: 1].
6. Google Login đã được cấu hình và phải được giữ lại.
7. Kiểm thử từng module trong quá trình phát triển[cite: 1].

---

## 5. Tiến độ thực hiện (Tuần 3 – Tuần 15)

- **Tuần 3 (07 – 13/09/2026):** Phân tích yêu cầu, thiết kế hệ thống (ERD cơ sở dữ liệu, kiến trúc API). Hoàn thiện nội dung đề cương và chuẩn bị nộp[cite: 1].
- **Tuần 4 (14 – 20/09/2026):** Nộp quyển đề cương. Củng cố bảo mật & Backend Auth: cấu hình biến môi trường, CORS, hoàn thiện JWT Refresh Token và phân quyền cơ bản[cite: 1].
- **Tuần 5 (21 – 27/09/2026):** Phát triển Backend Core: tạo app medical_records, xây dựng PersonProfile, Household, HouseholdMember và các model hồ sơ sức khỏe chính[cite: 1].
- **Tuần 6 (28/09 – 04/10/2026):** Xây dựng các model còn lại: Visit, LabResult, Medication, MedicalDocument, HealthMeasurement; thực hiện migration dữ liệu cần thiết[cite: 1].
- **Tuần 7 (05 – 11/10/2026):** Xây dựng API DRF: Serializers, ViewSets cho Profiles, Family, Medical Records, Documents và Measurements; áp dụng phân trang, filtering và idempotency_key[cite: 1].
- **Tuần 8 (12 – 18/10/2026):** Refactor Flutter App: tổ chức theo feature-based, hoàn thiện AuthService, Secure Storage, refresh token và các luồng Profile, Family, Medical Records[cite: 1].
- **Tuần 9 (19 – 25/10/2026):** Tích hợp Wear OS: hoàn thiện WatchService, timestamp, device_id, offline queue, batch sync, retry và xử lý idempotency_key[cite: 1].
- **Tuần 10 (26/10 – 01/11/2026):** Tích hợp AI Service: xây dựng Rule-based Engine, AI Provider, AIInsight và AI Chat ở mức cơ bản[cite: 1].
- **Tuần 11 (02 – 08/11/2026):** Kiểm thử tính năng và luồng chính: xác thực, phân quyền, hồ sơ, dữ liệu sức khỏe, Wear OS, offline/batch sync và AI; sửa các lỗi phát sinh[cite: 1].
- **Tuần 12 (09 – 15/11/2026):** Hoàn thiện giao diện, tổng hợp kết quả kiểm thử và viết các chương nội dung chính của báo cáo[cite: 1].
- **Tuần 13 (16 – 20/11/2026):** Hoàn thiện báo cáo, README.md, tài liệu phân tích – thiết kế và đóng gói mã nguồn[cite: 1].
- **Tuần 14 (23 – 28/11/2026):** Kiểm tra tổng thể hệ thống, rà soát chức năng, kiểm thử lại và hoàn thiện định dạng báo cáo theo chuẩn của Khoa CNTT[cite: 1].
- **Tuần 15 (30/11 – 06/12/2026):** Bảo vệ đồ án: Tham gia báo cáo trước Hội đồng đồ án chuyên ngành và chỉnh sửa theo góp ý[cite: 1].