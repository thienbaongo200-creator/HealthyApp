import os
import time
from google import genai
from google.genai.errors import ServerError


def read_file_safe(file_path):
  """Đọc nội dung file an toàn với mã hóa utf-8"""
  try:
    with open(file_path, "r", encoding="utf-8") as f:
      return f.read()
  except Exception:
    return ""


def scan_project_source():
  """Quét toàn bộ mã nguồn trong các thư mục backend và frontend của dự án"""
  source_summary = ""
  target_dirs = ["backend", "frontend"]

  print("🔍 Đang quét mã nguồn dự án...")
  for target_dir in target_dirs:
    if not os.path.exists(target_dir):
      continue
    for root, dirs, files in os.walk(target_dir):
      # Bỏ qua các thư mục rác / build / dependencies không cần thiết
      if any(
          ignore in root
          for ignore in [
              "node_modules",
              ".git",
              "venv",
              "__pycache__",
              "bin",
              "obj",
              ".dart_tool",
              "migrations",
          ]
      ):
        continue

      for file in files:
        # Chỉ quét các file mã nguồn chính liên quan đến đồ án
        if file.endswith((".py", ".dart", ".ts", ".js", ".cs")):
          file_path = os.path.join(root, file)
          content = read_file_safe(file_path)
          if content:
            # Lấy nội dung sâu hơn để AI có đủ ngữ cảnh kiểm tra logic
            source_summary += (
                f"\n--- FILE: {file_path} ---\n{content[:2500]}\n"
            )

  return source_summary


def read_checklist():
  """Đọc file CHECKLIST.md hiện tại trong dự án"""
  if os.path.exists("CHECKLIST.md"):
    return read_file_safe("CHECKLIST.md")
  return (
      "# CHECKLIST ĐỒ ÁN HEALTHYAPP\n- [ ] Chưa khởi tạo checklist\n- [~] Đã có"
      " một phần, cần sửa/bổ sung/kiểm thử\n- [x] Đạt DoD và có test/bằng chứng"
  )


def update_checklist_file(new_checklist_content):
  """Ghi đè nội dung checklist mới vào file CHECKLIST.md"""
  with open("CHECKLIST.md", "w", encoding="utf-8") as f:
    f.write(new_checklist_content)


def main():
  # 1. Quét source code
  code_context = scan_project_source()
  if not code_context:
    print(
        "⚠️ Không tìm thấy mã nguồn nào trong thư mục backend hoặc frontend."
    )
    return

  # 2. Đọc checklist hiện tại
  current_checklist = read_checklist()

  print(
      "🤖 Đang gọi Gemini AI để phân tích thực tế và cập nhật CHECKLIST.md theo"
      " thang đo 3 mức..."
  )

  # 3. Khởi tạo client Gemini
  client = genai.Client()

  # 4. Xây dựng Prompt siết chặt quy tắc đánh giá dựa trên thang đo của bạn
  prompt = f"""
    Bạn là trợ lý kỹ thuật AI kiểm tra đồ án khắt khe cho dự án HealthyApp.
    
    === TÓM TẮT ĐẶC TẢ KỸ THUẬT (CHƯƠNG 2) ===
    - 8 Module: Authentication, Profile, Household, Medical Record, Health Measurement, Wear Sync, AI Insight, AI Chat.
    - Các quy tắc cốt lõi bắt buộc kiểm chứng:
      + BR01: Cấu hình JWT (Access/Refresh token, Redis Blacklist).
      + BR05: Custom Permission class check RBAC và chống IDOR.
      + BR07 & BR08: Xử lý `idempotency_key` (Redis + UNIQUE constraint PostgreSQL).
      + BR10 & BR12: Kiểm tra `ai_consent` và cơ chế Fallback về Rule-based Engine.

    === THANG ĐO TRẠNG THÁI CHECKLIST BẮT BUỘC SỬ DỤNG ===
    - `[ ]`: Chưa thực hiện (Không tìm thấy code triển khai).
    - `[~]`: Đã có một phần, cần sửa/bổ sung/kiểm thử (Mã nguồn mới viết khung, thiếu logic bảo mật hoặc chưa hoàn thiện theo Chương 2).
    - `[x]`: Đạt DoD và có test/bằng chứng (Đã triển khai hoàn chỉnh logic, đúng chuẩn thiết kế kỹ thuật).

    === TOÀN BỘ MÃ NGUỒN THỰC TẾ TRONG DỰ ÁN ===
    {code_context}

    === FILE CHECKLIST.md HIỆN TẠI ===
    {current_checklist}

    === NHIỆM VỤ ĐÁNH GIÁ ===
    1. So sánh mã nguồn thực tế với yêu cầu kỹ thuật Chương 2 một cách khách quan.
    2. Cập nhật trạng thái các mục trong file `CHECKLIST.md` sử dụng đúng 3 ký hiệu `[ ]`, `[~]`, `[x]` dựa trên mức độ hoàn thiện thực tế của code.
    3. ĐẦU RA YÊU CẦU: Chỉ trả về **đúng toàn bộ nội dung Markdown hoàn chỉnh của file CHECKLIST.md mới**. Tuyệt đối không bao quanh bằng các thẻ giải thích ngoài văn bản markdown để script tự động ghi file trực tiếp.
    """

  # Cơ chế Retry tự động nếu gặp lỗi 503
  max_retries = 3

  for attempt in range(1, max_retries + 1):
    try:
      response = client.models.generate_content(
          model="gemini-3.8-flash",
          contents=prompt,
      )

      updated_checklist = response.text.strip()

      # Làm sạch định dạng Markdown nếu bị bọc block
      if updated_checklist.startswith("```markdown"):
        updated_checklist = updated_checklist[11:]
      if updated_checklist.startswith("```"):
        updated_checklist = updated_checklist[3:]
      if updated_checklist.endswith("```"):
        updated_checklist = updated_checklist[:-3]
      updated_checklist = updated_checklist.strip()

      # Ghi kết quả vào file CHECKLIST.md
      update_checklist_file(updated_checklist)

      print("\n================ THÀNH CÔNG! ================")
      print(
          "✅ Đã cập nhật tiến độ vào file `CHECKLIST.md` theo thang đo"
          " [ ] / [~] / [x]."
      )
      print("=============================================")
      break

    except ServerError as e:
      if "503" in str(e) and attempt < max_retries:
        print(
            f"⚠️ Máy chủ Google đang quá tải (Lỗi 503). Đang thử lại lần"
            f" {attempt + 1}/{max_retries} sau 3 giây..."
        )
        time.sleep(3)
      else:
        print(f"\n❌ Lỗi Server từ API sau {attempt} lần thử: {str(e)}")
        break
    except Exception as e:
      print(f"\n❌ Lỗi không xác định: {str(e)}")
      break


if __name__ == "__main__":
  main()