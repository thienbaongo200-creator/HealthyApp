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
            # Giới hạn ký tự mỗi file để tập trung vào logic cốt lõi và tiết kiệm token
            source_summary += (
                f"\n--- FILE: {file_path} ---\n{content[:1500]}\n"
            )

  return source_summary


def read_checklist():
  """Đọc file CHECKLIST.md hiện tại trong dự án"""
  if os.path.exists("CHECKLIST.md"):
    return read_file_safe("CHECKLIST.md")
  return "# CHECKLIST ĐỒ ÁN HEALTHYAPP\n- [ ] Chưa khởi tạo checklist"


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

  print("🤖 Đang gọi Gemini AI để phân tích code và cập nhật CHECKLIST.md...")

  # 3. Khởi tạo client Gemini (Tự động nhận API key từ biến môi trường GEMINI_API_KEY)
  client = genai.Client()

  # 4. Xây dựng Prompt phân tích và cập nhật checklist
  prompt = f"""
    Bạn là trợ lý kỹ thuật AI chuyên quản lý đồ án CNTT cho dự án HealthyApp.
    
    === TÓM TẮT ĐẶC TẢ KỸ THUẬT (CHƯƠNG 2) ===
    - 8 Module Backend: Authentication, Profile, Household, Medical Record, Health Measurement, Wear Sync, AI Insight, AI Chat.
    - Các quy tắc cốt lõi bắt buộc: 
      + BR01: Xác thực JWT (Access/Refresh token, Redis Blacklist).
      + BR05: Phân quyền RBAC (OWNER, MEMBER, CAREGIVER) và chống IDOR qua Permission class.
      + BR07 & BR08: Chống ghi trùng bằng `idempotency_key` (Redis + UNIQUE constraint PostgreSQL).
      + BR10 & BR12: AI Consent hợp lệ và cơ chế Fallback về Rule-based Engine khi AI lỗi.

    === TOÀN BỘ MÃ NGUỒN HIỆN TẠI TRONG DỰ ÁN ===
    {code_context}

    === FILE CHECKLIST.md HIỆN TẠI ===
    {current_checklist}

    === NHIỆM VỤ ===
    1. So sánh mã nguồn thực tế với các yêu cầu kỹ thuật tại Chương 2.
    2. Cập nhật file `CHECKLIST.md`: Chuyển đổi trạng thái từ `[ ]` sang `[x]` đối với các task/chức năng mà mã nguồn thực tế **đã triển khai hoàn chỉnh**. Giữ nguyên `[ ]` hoặc thêm ghi chú ngắn nếu chưa làm.
    3. ĐẦU RA YÊU CẦU: Chỉ trả về **đúng toàn bộ nội dung Markdown hoàn chỉnh của file CHECKLIST.md mới**. Tuyệt đối không bao quanh bằng các thẻ giải thích ngoài văn bản markdown để script có thể ghi file trực tiếp.
    """

  # Cơ chế Retry tự động nếu gặp lỗi 503 (quá tải tạm thời)
  max_retries = 3
  success = False

  for attempt in range(1, max_retries + 1):
    try:
      # Thử gọi model chuẩn, nếu 503 script sẽ tự thử lại
      response = client.models.generate_content(
          model="gemini-3.8-flash",
          contents=prompt,
      )

      updated_checklist = response.text.strip()

      # Làm sạch định dạng nếu AI lỡ bọc block markdown
      if updated_checklist.startswith("```markdown"):
        updated_checklist = updated_checklist[11:]
      if updated_checklist.startswith("```"):
        updated_checklist = updated_checklist[3:]
      if updated_checklist.endswith("```"):
        updated_checklist = updated_checklist[:-3]
      updated_checklist = updated_checklist.strip()

      # 5. Ghi kết quả vào file CHECKLIST.md
      update_checklist_file(updated_checklist)

      print("\n================ THÀNH CÔNG! ================")
      print(
          "✅ Đã quét toàn bộ dự án và tự động cập nhật tiến độ vào file"
          " `CHECKLIST.md`."
      )
      print("=============================================")
      success = True
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