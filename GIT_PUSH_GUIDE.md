# Git Checklist & Push Guide cho Healthy App

## 📋 Checklist Trước Khi Push

### 1. Kiểm tra Trạng Thái
```powershell
git status
```
✅ **Xác nhận:**
- [ ] Không có file `.env` (chứa passwords)
- [ ] Không có file `db.sqlite3`
- [ ] Không có `__pycache__/`, `.pyc`, `.dart_tool/`
- [ ] Không có thư mục `venv/` hoặc `node_modules/`
- [ ] Không có file temp (`.swp`, `.swo`, `~`)

### 2. Kiểm tra Code Quality
```powershell
# Backend - Django checks
cd backend
python manage.py check
python manage.py test accounts.tests

# Frontend - Dart analysis
cd ../frontend
dart analyze lib/
flutter format lib/
```
✅ **Xác nhận:**
- [ ] Django system check: `0 silenced`
- [ ] Tests: Tất cả passed
- [ ] Dart analyzer: `No issues found`

### 3. Kiểm tra Git Diff
```powershell
git diff --cached
```
✅ **Xác nhận:**
- [ ] Không có hardcoded password, API key, token
- [ ] Không có file log hoặc temp
- [ ] Code logic thay đổi đúng như dự định

### 4. Xem Lại Thay Đổi Toàn Cục
```powershell
git diff --stat
```
Nên thấy:
- Backend: `models.py`, `views.py`, `urls.py`, `settings.py`, `requirements.txt`, migration files
- Frontend: `api_service.dart`, `register_screen.dart`, `login_screen.dart`, `profile_setup_screen.dart`
- Root: `.gitignore`

---

## 🚀 Quy Trình Git An Toàn

### Bước 1: Reset & Dọn Sạch Cache
```powershell
# Nếu có thay đổi không mong muốn trong cache
git reset HEAD .

# Xóa các file vô tình được staged
git clean -fd
```

### Bước 2: Stage File Một Cách Có Chọn Lọc
```powershell
# Cách 1: Stage tất cả file (sau khi đã verify .gitignore)
git add .

# Cách 2: Stage file cụ thể (an toàn hơn)
git add backend/
git add frontend/
git add .gitignore
git add README.md
```

### Bước 3: Xem Lại Trước Commit
```powershell
git status
git diff --cached
```

### Bước 4: Commit Với Thông Điệp Rõ Ràng
```powershell
# Định dạng commit message:
# [Backend/Frontend] Tóm tắt ngắn gọn

git commit -m "[Backend] Add user registration and profile endpoints

- Implement RegisterView for /api/auth/register/
- Add ProfileView for /api/auth/profile/ with JWT auth
- Create UserProfile model to store gender, DOB, height, weight
- Add comprehensive test coverage for auth integration"

# Hoặc commit riêng biệt cho clarity:
git commit -m "[Backend] Add UserProfile model and auth endpoints"
git commit -m "[Frontend] Fix registration form and keyboard handling"
git commit -m "[Project] Update .gitignore for Flutter/Django artifacts"
```

### Bước 5: Kiểm Tra Branch Hiện Tại
```powershell
git branch -a
git branch --show-current
```

### Bước 6: Pull Trước Khi Push (Tránh Conflict)
```powershell
# Nếu là repository remote
git fetch origin
git pull origin main  # hoặc develop, tuỳ theo branch
```

### Bước 7: Push Lên Repository
```powershell
# Push lên branch hiện tại
git push origin $(git branch --show-current)

# Hoặc explicit
git push origin main
git push origin develop
```

### Bước 8: Xác Nhận Push Thành Công
```powershell
git log --oneline -5
git branch -v
```
✅ Thấy commit mới trong log = Push thành công!

---

## ⚠️ Những Lỗi Phổ Biến Cần Tránh

| Lỗi | Nguyên Nhân | Cách Khắc Phục |
|-----|-----------|----------------|
| **Push rejected** | Upstream có commit mới | Chạy `git pull origin <branch>` trước |
| **File lộ .env** | .env không trong .gitignore | Verify `.gitignore`, hoặc `git rm --cached .env` |
| **Commit chứa `__pycache__`** | .gitignore cập nhật muộn | Chạy `git rm --cached -r backend/**/__pycache__` |
| **Commit quá lớn** | Gom quá nhiều thay đổi | Split thành nhiều commit theo feature |
| **Conflict khi pull** | Branch bị diverge | Dùng `git rebase` hoặc `git merge`, resolve conflict |

---

## 📝 Template Commit Message Tốt

```
[Component] Brief summary (max 50 chars)

Detailed explanation of what changed and why:
- Point 1
- Point 2
- Point 3

Closes #123 (nếu có issue)
```

**Ví dụ:**
```
[Backend] Implement JWT authentication and user registration

- Add RegisterView supporting username, email, password validation
- Add ProfileView for authenticated profile updates (gender, DOB, height, weight)
- Create UserProfile OneToOne model to extend auth.User
- Hash passwords using Django's create_user() method
- All endpoints tested with full integration test suite

Closes #15
```

---

## ✅ Final Checklist Trước Khi `git push`

- [ ] `git status` → Chỉ thấy changes mong muốn
- [ ] `.env`, `db.sqlite3`, `__pycache__` KHÔNG có trong status
- [ ] Django check: OK
- [ ] Flutter analyze: No issues
- [ ] Tests: Passed
- [ ] Commit message rõ ràng
- [ ] Đã `git pull origin <branch>` thành công
- [ ] `git diff --cached` không chứa secrets
- [ ] Branch name xác định (main, develop, feature/...)

**Nếu đã OK hết → SAFE TO PUSH! 🚀**

