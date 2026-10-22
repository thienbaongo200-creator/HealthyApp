# Mâu thuẫn và điểm cần làm rõ trong báo cáo

Nguồn được đối chiếu: `docs/DACN_Ngo_Quoc_Thien_Bao.docx`. Chương 1–2 được dùng làm đặc tả; Chương 3, Kết luận và Tóm tắt chỉ được dùng để nhận diện cấu trúc và các nội dung cũ, không dùng làm bằng chứng kiểm thử.

## 1. Dẫn chiếu “mục 2.10” không tồn tại

- **Vị trí/trích dẫn:** Mở đầu, Phạm vi nghiên cứu: “Phạm vi triển khai nguyên mẫu được chốt tại mục 2.10 của Chương 2.” Chương 3 cũ tiếp tục ghi: “Các giá trị thiết kế ở Bảng 2.50 đã được chốt theo cấu hình triển khai (mục 2.10)” và “quy ước ở mục 2.10”.
- **Mâu thuẫn:** Chương 2 không có mục 2.10. Mục lục và nội dung Chương 2 kết thúc ở phần 2.9; nội dung chương chuyển sang Chương 3.
- **Đề xuất:** Tác giả xác định mục/bảng đúng muốn dẫn. Không tự thay số mục khi chưa biết nơi lưu phạm vi triển khai nguyên mẫu.

## 2. Mã TC được dẫn nhưng không có trong Bảng 2.51

- **Vị trí/trích dẫn:** Bảng 2.51 tuyên bố “26 kịch bản”; danh sách thực tế gồm 26 mã từ TC01.1 đến TC09.3. Bảng 2.5, NFR01, đoạn RBAC và Bảng 2.52 lại dẫn các mã như TC01.4, TC02.3, TC03.4, TC04.4, TC04.5, TC05.5, TC06.4, TC06.5, TC07.4, TC07.5, TC08.4, TC08.5 và TC09.4.
- **Mâu thuẫn:** Các mã trên không có hàng/kịch bản tương ứng trong Bảng 2.51. Vì vậy không thể dùng chúng làm bằng chứng kết quả nếu không bổ sung hoặc sửa dẫn chiếu.
- **Đề xuất:** Giữ nguyên 26 kịch bản của Bảng 2.51 và sửa các dẫn chiếu ở những bảng khác về mã hiện có; hoặc tác giả quyết định bổ sung kịch bản và cập nhật số lượng/ma trận.

## 3. CF1, CF2 và CF7 không nhất quán giữa thiết kế và Chương 3 cũ

- **Vị trí/trích dẫn:** Bảng 2.50 ghi CF1 = “60 giây”, CF2 = “1 ngày”, CF7 = “30 giây”. Bảng 3.1 cũ ghi CF1 = “60 phút (3600 giây)”, CF2 = “7 ngày”, CF7 = “10 giây”. Chương 3 cũ còn nói CF1 được ghi đè thành 60 giây khi kiểm thử hết hạn token.
- **Mâu thuẫn:** Không rõ giá trị nào là cấu hình triển khai, giá trị thử nghiệm hoặc ghi đè theo từng bài kiểm thử. Chương 3 cũ cũng không thể được dùng làm kết quả mới.
- **Đề xuất:** Chốt riêng giá trị cấu hình mặc định, cấu hình kiểm thử và mọi override. Khi hoàn thiện Chương 3, chỉ ghi giá trị đọc/đo trong lần chạy mới.

## 4. Vai trò Caregiver: khác biệt về phạm vi “chỉ xem”

- **Vị trí/trích dẫn:** BR04: “Caregiver chỉ được truy cập hồ sơ được chia sẻ ở chế độ xem (read-only), không được ghi dữ liệu.” Bảng 2.42 cho phép Caregiver ghi dữ liệu y tế và nhập chỉ số trên hồ sơ của chính mình; Bảng 2.47 cũng ghi “Chỉ hồ sơ của mình”. UC06 lại tóm tắt “Caregiver chỉ xem”.
- **Mâu thuẫn/điểm mơ hồ:** Các bảng RBAC có thể nhất quán nếu “read-only” chỉ áp dụng cho hồ sơ được chia sẻ, còn “hồ sơ của mình” được phép ghi. UC06 không làm rõ ranh giới đó.
- **Đề xuất:** Ghi rõ “Caregiver chỉ đọc hồ sơ được chia sẻ; quyền đối với hồ sơ SELF của chính tài khoản được xét riêng” hoặc điều chỉnh ma trận theo quyết định của tác giả. Không mặc định diễn giải UC06 để mở rộng quyền.

## 5. Khoảng trống Bảng 2.15–2.22 và cách đánh số

- **Vị trí/trích dẫn:** Nội dung mô tả tám module và dẫn mục 2.3.2; mục lục liệt kê các bảng 2.1–2.14 rồi chuyển sang Bảng 2.23. Không tìm thấy Bảng 2.15–2.22 trong nội dung trích xuất.
- **Mâu thuẫn/điểm cần xác minh:** Có khoảng trống tám số bảng, trong khi bảng module tổng hợp trong thân bài không mang số hiệu. Chưa thấy bằng chứng đủ để kết luận đây là lỗi đánh số hay các bảng đã bị bỏ.
- **Đề xuất:** Xác nhận các bảng 2.15–2.22 có bị lược khỏi bản khóa hay không; nếu không tồn tại, sửa các dẫn chiếu đến chúng và đánh số lại theo quy định của Khoa.

## 6. Phiên bản Django trong đặc tả nội bộ không thống nhất

- **Vị trí/trích dẫn:** NFR09 ghi “Django 6.0.6”; Bảng 2.23 và Bảng 2.49 ghi Django 6.1. `backend/requirements.txt` cũng khóa `Django==6.1`; runtime Python hiện tại trả về Django 6.1.
- **Mâu thuẫn:** Ba nguồn trong cùng báo cáo/mã không thống nhất phiên bản mục tiêu.
- **Đề xuất:** Tác giả xác nhận phiên bản chính thức; đồng bộ NFR09 với Bảng 2.23/2.49 nếu 6.1 là chủ đích.

## 7. Gemini được nêu trong hình nhưng chưa được xác định trong phần văn bản/tài liệu tham khảo

- **Vị trí/trích dẫn:** Phần thân bài chủ yếu dùng thuật ngữ chung “AI Provider”; Sơ đồ 2.16 có nhãn “AI Provider (LLM / Gemini API)”. Danh mục tài liệu tham khảo không có mục riêng dẫn tài liệu Gemini/Google AI.
- **Mâu thuẫn/điểm thiếu:** Hình nêu cụ thể nhà cung cấp nhưng văn bản và tài liệu tham khảo chưa mô tả/cung cấp nguồn tương ứng.
- **Đề xuất:** Nếu Gemini là nhà cung cấp thực tế, nêu rõ trong mô tả triển khai và bổ sung tài liệu chính thức phù hợp; nếu chỉ là phương án minh họa, chú thích rõ. Không thay đổi nội dung Chương 1–2 trong đợt này.

## 8. AI Insight: yêu cầu Chương 2 tương đối nhất quán; cần giữ đúng ý khi triển khai

- **Vị trí/trích dẫn:** UC08 yêu cầu lưu AIInsight; Bảng 2.38 định nghĩa `period_start`, `period_end`, `risk_level`, `triggered_rules`, `content`, `generated_by`; Bảng 2.41 mô tả POST `/ai-insights/analyze`; Bảng 2.44 quy định khi thiếu consent chỉ trả kết quả RULE_ONLY và khi provider lỗi vẫn trả kết quả Rule-based.
- **Mâu thuẫn/điểm cần làm rõ:** Không thấy mâu thuẫn trực tiếp giữa các phần đặc tả này. Tuy nhiên, Bảng 2.41 liệt kê 403 mà không phân biệt rõ đó là lỗi quyền hay thiếu consent; cần bảo đảm không diễn giải 403 thành hành vi mong đợi khi consent tắt, trái UC08/Bảng 2.44.
- **Đề xuất:** Nếu cần, tác giả làm rõ trong tài liệu ngoài Chương 1–2 đã khóa; mã và kết quả phải tuân theo UC08/Bảng 2.44.

## 9. Redis chỉ là phương án thay thế, không phải lựa chọn triển khai

- **Vị trí/trích dẫn:** Bảng 2.48, hàng chống ghi trùng, cột “Giải pháp thay thế” nêu Redis Distributed Lock cho hệ thống quy mô lớn.
- **Kết luận:** Đây là nội dung được đánh dấu rõ là phương án thay thế, không phải mô tả kiến trúc được chọn. Không nên ghi Redis là thành phần triển khai hiện tại.
- **Đề xuất:** Giữ nguyên nếu ý định là nêu lựa chọn thay thế; khi viết Chương 3 chỉ mô tả PostgreSQL/Unique constraint đã kiểm tra.

## 10. Nội dung Chương 3 cũ có số liệu và kết luận chưa được dùng lại

- **Vị trí/trích dẫn:** Chương 3 cũ ghi 17 Pass, 5 Fail, 2 “lệch thiết kế”, 2 chưa chạy; ghi các lần đo batch, cấu hình CF và kết quả API.
- **Mâu thuẫn/giới hạn sử dụng:** Nội dung này tự nói kết quả thuộc “lần chạy đầu tiên, trước khi mã nguồn được đồng bộ” và cần thay thế. Không có dữ liệu chạy trong phiên rà soát này để xác minh các con số đó.
- **Đề xuất:** Không đưa những số liệu/kết quả cũ vào phần kết quả mới nếu chưa tái tạo bằng lệnh và bằng chứng được lưu.

## 11. Sơ đồ nhúng

- **Vị trí:** Các sơ đồ Use Case, ERD, kiến trúc, RBAC và trình tự trong Chương 2 (ví dụ Sơ đồ 2.8–2.16).
- **Kết quả đối chiếu:** Đã giải nén và xem được hình kiến trúc, ERD, luồng RBAC, xác thực, đồng bộ và AI Chat ở mức bố cục/luồng chính. Chữ nhỏ/độ tương phản thấp ở một số hình làm cho một số nhãn chi tiết không thể đọc chắc chắn; do đó chưa xác nhận mọi trường/nhánh trong toàn bộ 32 ảnh nhúng.
- **Đề xuất:** Nếu cần xác minh từng nhãn trong sơ đồ, cung cấp bản xuất độ phân giải cao hoặc bản nguồn chỉnh sửa được. Không suy diễn nội dung không đọc được.

