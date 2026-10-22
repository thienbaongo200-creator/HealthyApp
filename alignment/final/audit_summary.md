# Tóm tắt rà soát giai đoạn 1

- Nhánh hiện tại: `align/chapter3`, tạo từ `dev` tại commit `de92e18`.
- Worktree đã có thay đổi chưa commit trước khi bắt đầu; giữ nguyên, không stage/commit các thay đổi này. Không sửa mã nguồn hay `.docx`.
- Nguồn: `docs/DACN_Ngo_Quoc_Thien_Bao.docx` (tên khác file được nêu trong yêu cầu). Trích xuất cục bộ bằng XML; không dùng pandoc/python-docx vì không cài. Đã đọc phần đặc tả và Phụ lục A/B; một số nhãn trong sơ đồ nhúng không đọc được rõ.
- Trace gồm **358 đơn vị**: 167 MỘT PHẦN; 8 THIẾU; 60 KHÁC; 79 CHƯA CHẠY; 32 KHỚP; 11 THIẾU / KHÁC; 1 ĐẶC TẢ MÂU THUẪN. Có 26 hàng TC, 135 hàng trường Data Dictionary, 37 hàng API và 42 luồng UC riêng (9 chính, 33 thay thế). Các trạng thái là rà soát tĩnh, không phải kết quả test.
- Test trong phiên này: **CHƯA CHẠY** theo yêu cầu giai đoạn 1. Thống kê tĩnh: 54 test method Django và 7 khai báo test Flutter; chưa có bộ test ánh xạ một-một với 26 TC được tìm thấy. Không kết luận Pass/Fail. Môi trường đọc được: Python 3.13.14; Flutter 3.47.5; Dart 3.13.4; `psql` 18.4; PostgreSQL server, emulator và hiệu năng chưa chạy/xác minh.

## 15 điểm quan trọng

1. Registration backend không kiểm tra `password_confirm`; email trùng trả 400 thay vì 409.
2. JWT đang dùng Access 60 phút/Refresh 7 ngày, khác CF1 60 giây/CF2 1 ngày.
3. Refresh rotation/blacklist có; auto-refresh không dùng nhất quán ở các API Flutter.
4. Consent API thực tế là GET/PATCH `/api/auth/ai-consent/`, khác PUT `/auth/consent`; chưa có quản lý consent dependent qua API.
5. MedicalRecord models tồn tại nhưng chỉ API documents được mount; histories/allergies/visits/medications/lab-results chưa có CRUD API.
6. MedicalRecord model fields không đồng nhất Data Dictionary ở nhiều bảng, đặc biệt MedicalHistory, Visit, LabResult, MedicalDocument.
7. HealthMeasurement có CRUD/batch/idempotency, nhưng `source=WEAR_OS` không bất biến với update/delete và có thể do client truyền.
8. Batch giới hạn 100; response toàn bộ thành công là 201, trong khi Bảng 2.41 ghi 200.
9. Chưa có `/health-measurements/statistics`; biểu đồ hiện xử lý phía Flutter.
10. Chưa có Device API; Wear OS prototype sinh dữ liệu giả và gửi HTTP tới listener điện thoại.
11. Wear queue chỉ ở RAM, không đủ bốn trạng thái và không có exponential backoff.
12. Risk engine chưa lưu AIInsight theo schema; một mẫu nhịp tim cao không kích hoạt R01 do gate yêu cầu ít nhất 3 mẫu; có thêm rule cảnh báo huyết áp ngoài R01–R04.
13. Chat chỉ có một endpoint send; không có API history. Provider fallback bị lưu như tin nhắn ASSISTANT, không có fallback flag.
14. HTTPS/HSTS được cấu hình có điều kiện DEBUG=False, nhưng URL mặc định Flutter là HTTP; Wear debug logs ghi dữ liệu sức khỏe.
15. Bảng 2.51 có đúng 26 mã nhưng các bảng khác dẫn nhiều mã không tồn tại; Chương 3 cũ chứa số liệu cũ không được tái sử dụng.

## Quyết định cần duyệt

- P0: **D01–D06, D13** — đăng ký, JWT/refresh, bất biến nguồn/batch, consent/Insight, fallback Chat, RBAC, bảo mật/log.
- P1: **D07–D09, D11–D12** — hồ sơ y tế, AIInsight, hội thoại, thống kê, queue bền vững.
- **D10** — API thiết bị/ghép nối; phương án C có thể giữ Wear OS đúng phạm vi nguyên mẫu.
- Ước lượng theo các phương án khuyến nghị: P0 **20,5–37 giờ**; P0+P1 **60,5–104 giờ**; tối đa gồm D10=A **68,5–118 giờ**. Nếu D08=C để tránh migration thì giảm tương ứng 12–20 giờ.
- Chi tiết A/B/C, công sức, rủi ro và ảnh hưởng báo cáo ở `decision_list.md`.

## Các mâu thuẫn báo cáo cần tác giả quyết định

- Dẫn mục 2.10 không tồn tại.
- TC được dẫn nhưng không có trong Bảng 2.51.
- CF1/CF2/CF7 khác nhau giữa Bảng 2.50 và Chương 3 cũ.
- Phạm vi quyền Caregiver cần viết rõ “hồ sơ được chia sẻ” so với “hồ sơ của chính mình”.
- Khoảng trống Bảng 2.15–2.22.
- NFR09 ghi Django 6.0.6, trong khi Bảng 2.23/2.49 và requirements ghi 6.1.
- Gemini được ghi ở nhãn hình nhưng chưa có mô tả/tài liệu tham khảo rõ trong văn bản.
- Nội dung Chương 3 cũ tự ghi là lần chạy trước đồng bộ, không dùng làm kết quả mới.

## Đầu ra và trạng thái

- Có: `alignment/final/spec_trace.csv`, `alignment/final/spec_conflicts.md`, `alignment/final/decision_list.md`, `alignment/final/audit_summary.md`.
- Chưa tạo `chapter3/final/`, không chạy kiểm thử, không đo HTTP/performance, không seed/migrate database, không lưu bằng chứng chạy.
- Dừng tại giai đoạn 1 theo yêu cầu. Chờ quyết định theo dạng `Duyệt: D01=A, D02=B, ...`; không triển khai giai đoạn 2 trước khi nhận duyệt.
