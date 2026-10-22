"""Local, read-only static audit for HealthyApp.

The audit reports source-level evidence only. It does not run tests, contact
external services, or modify CHECKLIST.md. Run from any directory with:
    python check_task.py
The report is written beside this script as audit_report.md.
"""

from __future__ import annotations

import ast
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPORT_PATH = ROOT / "audit_report.md"
EXCLUDED_DIRS = {"venv", ".venv", ".git", "build", ".dart_tool"}


@dataclass
class Finding:
    group: str
    status: str
    title: str
    detail: str
    evidence: str = ""


def read_text(path: Path) -> str:
    """Read text safely while preserving a useful audit result on decode errors."""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return ""


def source_evidence(path: Path, pattern: str) -> tuple[bool, str]:
    """Return whether a regex occurs in a file and a compact evidence location."""
    content = read_text(path)
    match = re.search(pattern, content, flags=re.MULTILINE)
    if not match:
        return False, ""
    line = content.count("\n", 0, match.start()) + 1
    return True, f"{path.relative_to(ROOT).as_posix()}:{line}"


def add_file_check(
    findings: list[Finding], group: str, title: str, relative_path: str,
    pattern: str | None = None, description: str = "",
) -> None:
    path = ROOT / relative_path
    if not path.is_file():
        findings.append(Finding(group, "MISSING", title, f"Không tìm thấy `{relative_path}`."))
        return
    if pattern is None:
        findings.append(Finding(group, "PASS / FOUND", title, description or "Tìm thấy file.", relative_path))
        return
    found, location = source_evidence(path, pattern)
    status = "PASS / FOUND" if found else "MISSING"
    detail = description if found else f"Có file nhưng không tìm thấy cấu trúc cần kiểm tra ({description})."
    findings.append(Finding(group, status, title, detail, location or relative_path))


def count_test_cases(path: Path) -> int:
    """Count Python test functions/methods without importing project code."""
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, SyntaxError):
        return 0
    return sum(
        isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and node.name.startswith("test_")
        for node in ast.walk(tree)
    )


def discover_test_files(base_dir: Path) -> list[Path]:
    """Find project-owned test modules without descending into generated trees."""
    if not base_dir.is_dir():
        return []

    found: list[Path] = []
    for current, directories, filenames in os.walk(base_dir):
        # Pruning dirs in-place prevents os.walk from ever entering these trees.
        directories[:] = sorted(
            name for name in directories if name.casefold() not in EXCLUDED_DIRS
        )
        for filename in filenames:
            if filename == "tests.py" or (filename.startswith("test_") and filename.endswith(".py")):
                found.append(Path(current) / filename)
    return sorted(found)


def audit() -> list[Finding]:
    findings: list[Finding] = []
    core = "Backend - Profiles & Household"
    add_file_check(
        findings, core, "PersonProfile có relation_type", "backend/profiles/models.py",
        r"(?m)^\s*relation_type\s*=\s*models\.", "Khai báo field `relation_type` trong model.",
    )
    add_file_check(
        findings, core, "Serializer profile xử lý relation_type", "backend/profiles/serializers.py",
        r"relation_type", "Trường được đưa vào serializer/validation.",
    )
    add_file_check(
        findings, core, "Backend permissions", "backend/core/permissions.py",
        r"class\s+PermissionService|class\s+IsProfileOwnerOrShared", "Có cấu trúc permission dùng chung.",
    )

    ai = "Backend - AI Services & Risk Engine"
    add_file_check(findings, ai, "Risk rule engine", "backend/ai_services/services/risk_engine.py",
                   r"class\s+RiskRuleEngine\b", "Có class `RiskRuleEngine`.")
    for filename in ("base.py", "local.py", "gemini.py"):
        add_file_check(findings, ai, f"AI provider: {filename}", f"backend/ai_services/providers/{filename}")

    security = "Backend - Consent & Security"
    add_file_check(
        findings, security, "AI views gọi permission service", "backend/ai_services/views.py",
        r"PermissionService\.has_profile_access", "AI view có kiểm tra quyền profile.",
    )
    add_file_check(
        findings, security, "AI views kiểm tra consent", "backend/ai_services/views.py",
        r"ai_consent", "AI view có nhắc đến consent; cần xác minh chủ thể và mọi đường gọi provider.",
    )
    add_file_check(
        findings, security, "Account consent API", "backend/accounts/views.py",
        r"class\s+AiConsentView\b", "Có endpoint quản lý consent tài khoản.",
    )

    front = "Frontend - Global State & Wearable"
    add_file_check(findings, front, "Global profile selection state", "frontend/lib/state/profile_selection.dart",
                   r"class\s+ProfileSelectionController\b", "Có controller chọn profile toàn cục.")
    add_file_check(
        findings, front, "Dashboard dùng profile selection", "frontend/lib/views/home/dashboard_screen.dart",
        r"ProfileSelectionScope\.of\(context\)|selectedProfileId", "Dashboard lấy profile đang chọn.",
    )
    add_file_check(
        findings, front, "Wear batch gắn profile_id", "frontend/lib/views/home/dashboard_screen.dart",
        r"profileId\s*:\s*batchProfileId", "Batch flush truyền profile đích; kiểm tra runtime vẫn cần thiết.",
    )
    findings.append(Finding(
        front, "WARNING / MANUAL CHECK", "Wear OS và offline queue",
        "Kiểm thử thiết bị thật, mất mạng/khởi động lại, độ bền hàng đợi và trạng thái UI không thể xác nhận bằng kiểm tra tĩnh.",
        "Chương 2: NFR05–NFR06, BR08, TC05",
    ))
    findings.append(Finding(
        front, "WARNING / MANUAL CHECK", "Global profile switching trên toàn UI",
        "Cần chạy UI để xác nhận các màn hình đổi profile đồng bộ, xóa dữ liệu cũ và không hiển thị nhầm hồ sơ.",
        "Chương 2: SCR và TC09",
    ))

    tests_group = "Test Suite"
    test_files = discover_test_files(ROOT / "backend")
    if not test_files:
        findings.append(Finding(tests_group, "MISSING", "Python test files", "Không tìm thấy tests.py hoặc test_*.py dưới backend/."))
    else:
        total = 0
        for path in test_files:
            count = count_test_cases(path)
            total += count
            rel = path.relative_to(ROOT).as_posix()
            findings.append(Finding(
                tests_group,
                "PASS / FOUND" if count else "WARNING / MANUAL CHECK",
                f"Test definitions: {rel}",
                f"Đếm tĩnh được {count} hàm `test_*` (không khẳng định test chạy/pass).",
                rel,
            ))
        findings.append(Finding(
            tests_group, "WARNING / MANUAL CHECK", "Tổng số test definitions",
            f"Tìm thấy {total} hàm test trong {len(test_files)} file. Cần chạy suite và lưu kết quả để xác nhận DoD.",
        ))

    # Confirm the reference documents exist; the script does not infer completion
    # from checklist marks because those marks may be stale or manually maintained.
    for relative in ("docs/Chuong2.docx", "CHECKLIST.md"):
        path = ROOT / relative
        findings.append(Finding(
            "References", "PASS / FOUND" if path.is_file() else "MISSING",
            f"Tài liệu tham chiếu: {relative}",
            "Có thể đối chiếu thủ công; script không tự đánh dấu checklist hoàn thành." if path.is_file() else "Không tìm thấy tài liệu.",
            relative if path.is_file() else "",
        ))
    return findings


def render_report(findings: list[Finding]) -> str:
    lines = [
        "# HealthyApp Static Audit Report", "",
        f"- Thời điểm tạo: {datetime.now().astimezone().isoformat(timespec='seconds')}",
        "- Chế độ: chỉ đọc; không chạy test và không sửa `CHECKLIST.md`.",
        "- Ý nghĩa: PASS / FOUND chỉ xác nhận dấu hiệu cấu trúc trong mã, không chứng minh tính đúng đắn khi chạy.", "",
    ]
    groups = list(dict.fromkeys(item.group for item in findings))
    for group in groups:
        lines.extend([f"## {group}", "", "| Trạng thái | Hạng mục | Kết quả / giới hạn | Bằng chứng |",
                      "|---|---|---|---|"])
        for item in (entry for entry in findings if entry.group == group):
            detail = item.detail.replace("|", "\\|").replace("\n", " ")
            evidence = f"`{item.evidence}`" if item.evidence else "—"
            lines.append(f"| **{item.status}** | {item.title} | {detail} | {evidence} |")
        lines.append("")
    lines.extend([
        "## Giới hạn kiểm toán", "",
        "Đây là kiểm tra tĩnh dựa trên file và dấu hiệu văn bản/AST. Báo cáo không chứng minh permission chống IDOR, consent đúng chủ thể, race condition, fallback AI, API contract hoặc UI hoạt động đúng. Hãy chạy test tự động và các kịch bản Chương 2 tương ứng trước khi kết luận nghiệm thu.",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    report = render_report(audit())
    # The only write performed by this script is the dedicated report file.
    REPORT_PATH.write_text(report, encoding="utf-8")
    encoding = sys.stdout.encoding or "utf-8"
    safe_report = report.encode(encoding, errors="replace").decode(encoding)
    safe_path = str(REPORT_PATH).encode(encoding, errors="replace").decode(encoding)
    print(safe_report)
    print(f"\nAudit report written: {safe_path}")


if __name__ == "__main__":
    main()
