"""Dynamic and static audit utility for HealthyApp.

Run with ``python check_task.py`` from any working directory. The script runs
the backend and Flutter checks, inspects Django's mounted URL resolver, and
overwrites only ``audit_report.md``. It never edits ``CHECKLIST.md``.
"""

from __future__ import annotations

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
BACKEND_DIR = ROOT / "backend"
FRONTEND_DIR = ROOT / "frontend"
REPORT_PATH = ROOT / "audit_report.md"
DOCX_NAME = "DACN_Ngo_Quoc_Thien_Bao.docx"
EXCLUDED_DIRS = {"venv", ".venv", ".git", "build", ".dart_tool", "__pycache__"}
COMMAND_TIMEOUT_SECONDS = 900


@dataclass
class Finding:
    group: str
    status: str
    title: str
    detail: str
    evidence: str = ""


@dataclass
class CommandResult:
    label: str
    command: str
    status: str
    returncode: int | None
    elapsed_seconds: float
    output: str
    passed: int | None = None
    failed: int | None = None
    skipped: int = 0
    timed_out: bool = False
    errors: list[str] = field(default_factory=list)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return ""


def source_evidence(path: Path, pattern: str) -> tuple[bool, str]:
    content = read_text(path)
    match = re.search(pattern, content, flags=re.MULTILINE)
    if not match:
        return False, ""
    line = content.count("\n", 0, match.start()) + 1
    return True, f"{path.relative_to(ROOT).as_posix()}:{line}"


def add_file_check(
    findings: list[Finding],
    group: str,
    title: str,
    relative_path: str,
    pattern: str | None = None,
    description: str = "",
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
    detail = description if found else f"Có file nhưng chưa thấy cấu trúc cần kiểm tra ({description})."
    findings.append(Finding(group, status, title, detail, location or relative_path))


def count_test_cases(path: Path) -> int:
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
    if not base_dir.is_dir():
        return []
    found: list[Path] = []
    for current, directories, filenames in os.walk(base_dir):
        directories[:] = sorted(
            name for name in directories if name.casefold() not in EXCLUDED_DIRS
        )
        for filename in filenames:
            if filename == "tests.py" or (
                filename.startswith("test_") and filename.endswith(".py")
            ):
                found.append(Path(current) / filename)
    return sorted(found)


def run_command(
    label: str,
    command: list[str],
    cwd: Path,
    *,
    timeout: int = COMMAND_TIMEOUT_SECONDS,
    windows_batch: bool = False,
) -> CommandResult:
    started = time.monotonic()
    command_display = subprocess.list2cmdline(command)
    environment = os.environ.copy()
    environment.setdefault("PYTHONUTF8", "1")
    try:
        if windows_batch:
            # Flutter is distributed as flutter.bat on Windows. Run the known
            # executable through cmd.exe; the command and arguments are fixed.
            batch_command = subprocess.list2cmdline(command)
            completed = subprocess.run(
                [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/s", "/c", batch_command],
                cwd=cwd,
                env=environment,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
            )
        else:
            completed = subprocess.run(
                command,
                cwd=cwd,
                env=environment,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
            )
        output = "\n".join(part for part in (completed.stdout, completed.stderr) if part)
        return CommandResult(
            label=label,
            command=command_display,
            status="PASS" if completed.returncode == 0 else "FAIL",
            returncode=completed.returncode,
            elapsed_seconds=time.monotonic() - started,
            output=output,
        )
    except subprocess.TimeoutExpired as error:
        parts = []
        for part in (error.stdout, error.stderr):
            if isinstance(part, bytes):
                part = part.decode("utf-8", errors="replace")
            if part:
                parts.append(part)
        return CommandResult(
            label=label,
            command=command_display,
            status="TIMEOUT",
            returncode=None,
            elapsed_seconds=time.monotonic() - started,
            output="\n".join(parts),
            timed_out=True,
            errors=[f"Quá thời gian giới hạn {timeout} giây."],
        )
    except (OSError, ValueError) as error:
        return CommandResult(
            label=label,
            command=command_display,
            status="NOT RUN",
            returncode=None,
            elapsed_seconds=time.monotonic() - started,
            output="",
            errors=[f"Không thể chạy lệnh: {error}"],
        )


def parse_backend_result(result: CommandResult) -> None:
    ran_match = re.search(r"Ran\s+(\d+)\s+tests?\s+in\s+([\d.]+)s", result.output)
    if ran_match:
        total = int(ran_match.group(1))
        result.elapsed_seconds = max(result.elapsed_seconds, float(ran_match.group(2)))
        failure_match = re.search(r"FAILED\s*\(([^)]*)\)", result.output)
        if failure_match:
            values = dict(re.findall(r"(failures|errors|skipped)=(\d+)", failure_match.group(1)))
            failed = int(values.get("failures", 0)) + int(values.get("errors", 0))
            result.skipped = int(values.get("skipped", 0))
            result.failed = failed
            result.passed = max(0, total - failed - result.skipped)
        elif re.search(r"\bOK\b", result.output):
            result.skipped = int(re.search(r"\((\d+)\s+skipped\)", result.output).group(1)) if re.search(
                r"\((\d+)\s+skipped\)", result.output
            ) else 0
            result.failed = 0
            result.passed = max(0, total - result.skipped)

    test_line = re.compile(
        r"^\s*(test\w*)\s+\(([\w.]+)\)\s+\.\.\.\s+"
        r"(ok|FAIL|ERROR|skipped\b.*?)(?:\s+\([\d.]+s\))?\s*$",
        re.MULTILINE,
    )
    for _, test_id, outcome in test_line.findall(result.output):
        module = test_id.split(".", 1)[0]
        record = next((item for item in result.errors if item.startswith(module + "|")), None)
        if record is None:
            result.errors.append(f"{module}|pass=0|fail=0|skip=0")
            record = result.errors[-1]
        parts = dict(piece.split("=", 1) for piece in record.split("|")[1:])
        if outcome == "ok":
            parts["pass"] = str(int(parts["pass"]) + 1)
        elif outcome.startswith("skipped"):
            parts["skip"] = str(int(parts["skip"]) + 1)
        else:
            parts["fail"] = str(int(parts["fail"]) + 1)
            result.errors.append(f"FAILED_TEST|{test_id}|{outcome}")
        result.errors[result.errors.index(record)] = (
            f"{module}|pass={parts['pass']}|fail={parts['fail']}|skip={parts['skip']}"
        )

    # Django's final failure summary remains authoritative even if a custom
    # runner adds timing text that does not match the per-test output format.
    for test_id in re.findall(
        r"^(?:FAIL|ERROR):\s+[^\r\n]*?\(([\w.]+)\)",
        result.output,
        flags=re.MULTILINE,
    ):
        result.errors.append(f"MODULE_FAILURE|{test_id}")


def backend_module_rows(result: CommandResult) -> list[dict[str, Any]]:
    labels = {
        "accounts": "Authentication & Consent",
        "profiles": "Profile",
        "households": "Household / RBAC",
        "medical_records": "Medical Record",
        "health_measurements": "Health Measurement",
        "devices": "Wear Sync / Device",
        "ai_services": "AI Insight & AI Chat",
        "core": "Core / Integration",
    }
    parsed: dict[str, dict[str, int]] = {}
    failed_test_ids: set[str] = set()
    for item in result.errors:
        match = re.fullmatch(r"([^|]+)\|pass=(\d+)\|fail=(\d+)\|skip=(\d+)", item)
        if match:
            parsed[match.group(1)] = {
                "pass": int(match.group(2)),
                "fail": int(match.group(3)),
                "skip": int(match.group(4)),
            }
        elif item.startswith("MODULE_FAILURE|"):
            failed_test_ids.add(item.split("|", 1)[1])

    # Include discovered test modules even when the runner failed before it
    # produced individual verbose test lines.
    discovered: dict[str, int] = {}
    for path in discover_test_files(BACKEND_DIR):
        rel = path.relative_to(BACKEND_DIR)
        module = rel.parts[0] if len(rel.parts) > 1 else "backend"
        discovered[module] = discovered.get(module, 0) + count_test_cases(path)

    can_infer_from_discovery = (
        result.passed is not None
        and result.failed is not None
        and sum(discovered.values()) == result.passed + result.failed + result.skipped
    )
    rows = []
    for module in sorted(set(discovered) | set(parsed)):
        numbers = parsed.get(module, {"pass": 0, "fail": 0, "skip": 0})
        executed = sum(numbers.values())
        if can_infer_from_discovery:
            failed_in_module = sum(
                test_id.split(".", 1)[0] == module for test_id in failed_test_ids
            )
            skipped_in_module = numbers["skip"]
            test_count = discovered.get(module, executed)
            failed_count = min(test_count, failed_in_module)
            passed_count = max(0, test_count - failed_count - skipped_in_module)
            status = "PASS" if failed_count == 0 else "FAIL"
        elif executed:
            test_count = executed
            passed_count = numbers["pass"]
            failed_count = numbers["fail"]
            skipped_in_module = numbers["skip"]
            status = "PASS" if numbers["fail"] == 0 else "FAIL"
        elif result.status in {"NOT RUN", "TIMEOUT"}:
            status = result.status
            test_count = discovered.get(module, 0)
            passed_count = failed_count = skipped_in_module = 0
        elif result.passed is None:
            status = "UNKNOWN"
            test_count = discovered.get(module, 0)
            passed_count = failed_count = skipped_in_module = 0
        else:
            status = "UNKNOWN"
            test_count = discovered.get(module, 0)
            passed_count = failed_count = skipped_in_module = 0
        rows.append({
            "module": labels.get(module, module),
            "tests": test_count,
            "passed": passed_count,
            "failed": failed_count,
            "skipped": skipped_in_module,
            "status": status,
        })
    return rows


def parse_flutter_test_result(result: CommandResult) -> None:
    count_match = re.findall(r"\+(\d+):\s+All tests passed!", result.output)
    if count_match:
        result.passed = int(count_match[-1])
        result.failed = 0
        return
    summary = re.findall(r"\+(\d+)\s+-\s+(\d+):", result.output)
    if summary:
        result.passed = int(summary[-1][0])
        result.failed = int(summary[-1][1])


def parse_flutter_analyze_result(result: CommandResult) -> None:
    match = re.search(r"(\d+) issues? found", result.output, flags=re.IGNORECASE)
    if match:
        result.failed = int(match.group(1))
        result.passed = 0 if result.failed else 1
    elif "No issues found" in result.output:
        result.failed = 0
        result.passed = 1


def flutter_command(name: str) -> tuple[list[str] | None, bool]:
    executable = shutil.which("flutter")
    if not executable:
        return None, False
    if os.name == "nt" and executable.lower().endswith((".bat", ".cmd")):
        return [executable, name], True
    return [executable, name], False


def discover_mounted_api_routes() -> tuple[list[dict[str, str]], str | None]:
    django_code = r'''import json
import os
import re
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
import django
django.setup()
from django.urls import URLPattern, URLResolver, get_resolver
from rest_framework.settings import api_settings

prefixes = (
    "api/auth/", "api/profiles/", "api/households/", "api/medical/",
    "api/medical-records/", "api/health-measurements/", "api/ai/",
)
rows = []
def walk(patterns, prefix=""):
    for item in patterns:
        route = prefix + str(item.pattern)
        if isinstance(item, URLResolver):
            walk(item.url_patterns, route)
            continue
        # DRF's DefaultRouter uses regex URL patterns and also adds optional
        # format-suffix aliases. Render the core route once in a readable form.
        if "(?P<format>" in route:
            continue
        route = route.replace("^", "").replace("$", "").replace(r"\.", ".")
        route = re.sub(r"\(\?P<([a-zA-Z_][a-zA-Z0-9_]*)>[^)]*\)", r"<\1>", route)
        if not any(route.startswith(value) for value in prefixes):
            continue
        callback = item.callback
        view_class = getattr(callback, "cls", None)
        actions = getattr(callback, "actions", None)
        if actions:
            methods = sorted(method.upper() for method in actions)
            handler = view_class.__name__ if view_class else getattr(callback, "__name__", "view")
        elif view_class:
            methods = sorted(
                method.upper() for method in view_class.http_method_names
                if method not in ("options", "head") and hasattr(view_class, method)
            )
            handler = view_class.__name__
        else:
            methods = ["ROUTE"]
            handler = getattr(callback, "__name__", "view")
        if view_class:
            declared_permissions = getattr(view_class, "permission_classes", None)
            permissions = list(
                api_settings.DEFAULT_PERMISSION_CLASSES
                if declared_permissions is None
                else declared_permissions
            )
            permission_label = ", ".join(cls.__name__ for cls in permissions) or "None (view-defined)"
        else:
            permission_label = "Unknown"
        rows.append({"method": ", ".join(methods), "path": "/" + route,
                     "handler": handler, "name": item.name or "",
                     "permission": permission_label})
rows = []
walk(get_resolver().url_patterns)
rows = list({(row["method"], row["path"], row["handler"], row["name"]): row for row in rows}.values())
print(json.dumps(rows, ensure_ascii=False))
'''
    result = run_command(
        "Django route resolver",
        [sys.executable, "-c", django_code],
        BACKEND_DIR,
        timeout=60,
    )
    if result.returncode != 0:
        return [], result.output[-3000:] or "; ".join(result.errors)
    try:
        rows = json.loads(result.output.strip().splitlines()[-1])
    except (json.JSONDecodeError, IndexError) as error:
        return [], f"Không đọc được danh sách route: {error}"
    return rows, None


def find_report_docx() -> Path | None:
    for candidate in (ROOT / DOCX_NAME, ROOT / "docs" / DOCX_NAME):
        if candidate.is_file():
            return candidate
    return None


def audit_static() -> list[Finding]:
    findings: list[Finding] = []
    core = "Backend - Profile & Household"
    add_file_check(
        findings, core, "PersonProfile relation_type", "backend/profiles/models.py",
        r"(?m)^\s*relation_type\s*=\s*models\.", "Model khai báo field relation_type.",
    )
    add_file_check(
        findings, core, "Profile serializer", "backend/profiles/serializers.py",
        r"relation_type", "Serializer có xử lý relation_type.",
    )
    add_file_check(
        findings, core, "Backend permission service", "backend/core/permissions.py",
        r"class\s+PermissionService|class\s+IsProfileOwnerOrShared", "Có cấu trúc permission dùng chung.",
    )

    medical = "Backend - Medical Records"
    for relative, pattern, title, detail in (
        ("backend/medical_records/views.py", r"class\s+ProfileScopedMedicalRecordViewSet", "Profile scoped CRUD", "ViewSet hồ sơ y tế lọc theo profile."),
        ("backend/medical_records/serializers.py", r"class\s+MedicalHistorySerializer", "Medical serializers", "Có serializer cho các loại hồ sơ y tế."),
        ("backend/medical_records/urls.py", r"router\.register", "Medical routes", "Các route hồ sơ được đăng ký qua DRF router."),
    ):
        add_file_check(findings, medical, title, relative, pattern, detail)

    ai = "Backend - AI Services"
    for relative, pattern, title, detail in (
        ("backend/ai_services/views.py", r"class\s+AiChatSessionView", "AI Chat endpoint", "Có endpoint nhận câu hỏi và xử lý hội thoại."),
        ("backend/ai_services/views.py", r"class\s+AiConversationListView", "Conversation history", "Có endpoint liệt kê lịch sử hội thoại."),
        ("backend/ai_services/views.py", r"class\s+AiConversationMessagesView", "Conversation messages", "Có endpoint đọc tin nhắn hội thoại."),
        ("backend/ai_services/views.py", r"PermissionService\.has_profile_ai_consent", "AI consent check", "Backend kiểm tra consent của hồ sơ."),
        ("backend/ai_services/serializers.py", r"class\s+ConversationSerializer", "AI history serializers", "Có serializer cho hội thoại và tin nhắn."),
    ):
        add_file_check(findings, ai, title, relative, pattern, detail)

    front = "Frontend - Flutter"
    add_file_check(
        findings, front, "AI API service", "frontend/lib/services/ai_service.dart",
        r"class\s+AiApiService", "Service tích hợp API đánh giá nguy cơ và Chat.",
    )
    add_file_check(
        findings, front, "AI assistant screen", "frontend/lib/views/home/ai_assistant_screen.dart",
        r"class\s+AiAssistantScreen", "Màn hình AI Assistant có trong ứng dụng.",
    )
    ai_service = read_text(ROOT / "frontend/lib/services/ai_service.dart")
    has_hardcoded_auth = "'Authorization': '******'" in ai_service
    findings.append(Finding(
        front,
        "FAIL" if has_hardcoded_auth else "PASS",
        "Bearer token cho API lịch sử AI Chat",
        "Vẫn tìm thấy Authorization hardcode." if has_hardcoded_auth else "Không còn header Authorization hardcode dạng ******.",
        "frontend/lib/services/ai_service.dart",
    ))

    device_routes = read_text(ROOT / "backend/core/urls.py")
    findings.append(Finding(
        "API Mounting",
        "WARNING" if "#path('api/devices/'" in device_routes or "# path('api/devices/'" in device_routes else "REVIEW",
        "Device API mount",
        "Route devices đang bị comment trong core URL config; module Wear Sync chưa có Device API mount.",
        "backend/core/urls.py",
    ))

    reference = find_report_docx()
    findings.append(Finding(
        "References",
        "PASS / FOUND" if reference else "MISSING",
        f"Báo cáo đồ án: {DOCX_NAME}",
        "Tìm thấy báo cáo tại vị trí được hỗ trợ." if reference else "Không tìm thấy file ở thư mục gốc hoặc docs/.",
        reference.relative_to(ROOT).as_posix() if reference else "",
    ))
    findings.append(Finding(
        "References",
        "PASS / FOUND" if (ROOT / "CHECKLIST.md").is_file() else "MISSING",
        "CHECKLIST.md",
        "Được tham chiếu chỉ đọc; script không ghi hoặc cập nhật file này." if (ROOT / "CHECKLIST.md").is_file() else "Không tìm thấy file.",
        "CHECKLIST.md" if (ROOT / "CHECKLIST.md").is_file() else "",
    ))
    return findings


def run_runtime_audits() -> tuple[CommandResult, CommandResult, CommandResult]:
    backend = run_command(
        "Backend tests",
        [sys.executable, "manage.py", "test", "--keepdb", "--verbosity", "2"],
        BACKEND_DIR,
    )
    parse_backend_result(backend)

    flutter_test_command, batch = flutter_command("test")
    if flutter_test_command is None:
        flutter_test = CommandResult(
            "Flutter tests", "flutter test", "NOT RUN", None, 0, "",
            errors=["Không tìm thấy lệnh flutter trong PATH."],
        )
    else:
        flutter_test = run_command(
            "Flutter tests", flutter_test_command, FRONTEND_DIR, windows_batch=batch
        )
        parse_flutter_test_result(flutter_test)

    flutter_analyze_command, batch = flutter_command("analyze")
    if flutter_analyze_command is None:
        flutter_analyze = CommandResult(
            "Flutter analyze", "flutter analyze", "NOT RUN", None, 0, "",
            errors=["Không tìm thấy lệnh flutter trong PATH."],
        )
    else:
        flutter_analyze = run_command(
            "Flutter analyze", flutter_analyze_command, FRONTEND_DIR, windows_batch=batch
        )
        parse_flutter_analyze_result(flutter_analyze)
    return backend, flutter_test, flutter_analyze


def escape_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def render_report(
    findings: list[Finding],
    backend: CommandResult,
    flutter_test: CommandResult,
    flutter_analyze: CommandResult,
    api_routes: list[dict[str, str]],
    route_error: str | None,
) -> str:
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    lines = [
        "# HealthyApp Dynamic & Static Audit Report",
        "",
        f"- Thời điểm tạo: {timestamp}",
        "- Chế độ: static audit + runtime test; chỉ ghi đè `audit_report.md`, không sửa `CHECKLIST.md`.",
        "- Backend test sử dụng `--keepdb` để giữ nguyên database test đã có.",
        "",
        "## Static Audit Findings",
        "",
        "| Trạng thái | Hạng mục | Kết quả / giới hạn | Bằng chứng |",
        "|---|---|---|---|",
    ]
    for item in findings:
        lines.append(
            f"| **{escape_cell(item.status)}** | {escape_cell(item.title)} | "
            f"{escape_cell(item.detail)} | {f'`{escape_cell(item.evidence)}`' if item.evidence else '—'} |"
        )

    lines.extend([
        "",
        "## Chương 3 - Kết quả Thực nghiệm & Kiểm thử Hệ thống",
        "",
        "### Bảng 3.x. Kết quả kiểm thử Backend",
        "",
        f"Lệnh: `{escape_cell(backend.command)}`  ",
        f"Kết quả tổng: **{backend.status}**; thời gian: **{backend.elapsed_seconds:.2f} giây**; "
        f"tổng pass: **{backend.passed if backend.passed is not None else 'N/A'}**; "
        f"tổng fail/error: **{backend.failed if backend.failed is not None else 'N/A'}**; "
        f"skip: **{backend.skipped}**.",
        "",
        "| Module | Số test chạy | Pass | Fail/Error | Skip | Trạng thái |",
        "|---|---:|---:|---:|---:|---|",
    ])
    for row in backend_module_rows(backend):
        lines.append(
            f"| {row['module']} | {row['tests']} | {row['passed']} | {row['failed']} | "
            f"{row['skipped']} | **{row['status']}** |"
        )
    if backend.status != "PASS" and backend.output:
        failures = [item.split("|", 2)[1:] for item in backend.errors if item.startswith("FAILED_TEST|")]
        if failures:
            lines.extend(["", "Các test lỗi (tối đa 20):", ""])
            for test_id, outcome in failures[:20]:
                lines.append(f"- `{escape_cell(test_id)}` — {escape_cell(outcome)}")
        elif backend.passed is None:
            lines.extend(["", "Thông tin lỗi runner:", "", "```text", backend.output[-3000:], "```"])

    lines.extend([
        "",
        "### Bảng 3.y. Kiểm thử Frontend và phân tích tĩnh",
        "",
        "| Công cụ | Số test / lỗi | Trạng thái | Thời gian | Ghi chú |",
        "|---|---:|---|---:|---|",
        f"| `flutter test` | {flutter_test.passed if flutter_test.passed is not None else 'N/A'} pass / {flutter_test.failed if flutter_test.failed is not None else 'N/A'} fail | **{flutter_test.status}** | {flutter_test.elapsed_seconds:.2f}s | {escape_cell(flutter_test.errors[0] if flutter_test.errors else 'Widget/unit test')} |",
        f"| `flutter analyze` | {flutter_analyze.failed if flutter_analyze.failed is not None else 'N/A'} issue | **{flutter_analyze.status}** | {flutter_analyze.elapsed_seconds:.2f}s | {escape_cell(flutter_analyze.errors[0] if flutter_analyze.errors else 'Static analyzer')} |",
        "",
        "### Bảng 3.z. Các API endpoint cốt lõi đã mount",
        "",
        "Danh sách được lấy trực tiếp từ Django URL resolver sau khi nạp cấu hình ứng dụng; method lấy từ action map hoặc handler class.",
        "",
        "| Method | Endpoint | Handler | URL name | Permission class |",
        "|---|---|---|---|---|",
    ])
    if api_routes:
        for route in api_routes:
            lines.append(
                f"| {escape_cell(route['method'])} | `{escape_cell(route['path'])}` | "
                f"{escape_cell(route['handler'])} | {escape_cell(route['name']) or '—'} | "
                f"{escape_cell(route.get('permission', '—'))} |"
            )
    else:
        lines.append(f"| — | — | Route resolver chưa xác thực được | {escape_cell(route_error or 'Không tìm thấy route API.')} | — |")

    lines.extend([
        "",
        "## Giới hạn và diễn giải",
        "",
        "- Số lượng test/module lấy từ output verbose lúc chạy. Nếu runner dừng trước summary, trạng thái được ghi UNKNOWN hoặc NOT RUN, không suy diễn thành pass.",
        "- Route table xác nhận URL đã mount trong Django; không thay thế kiểm thử quyền, response contract hay tích hợp thiết bị thực.",
        "- Kết quả Flutter phụ thuộc Flutter SDK và dependencies đã được cài trong môi trường chạy.",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    findings = audit_static()
    backend, flutter_test, flutter_analyze = run_runtime_audits()
    api_routes, route_error = discover_mounted_api_routes()
    report = render_report(
        findings,
        backend,
        flutter_test,
        flutter_analyze,
        api_routes,
        route_error,
    )

    # The only filesystem write is the requested report overwrite.
    REPORT_PATH.write_text(report, encoding="utf-8")
    # Windows consoles may use legacy code pages that cannot encode Vietnamese;
    # replace unsupported glyphs for console display while preserving UTF-8 in the file.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass
    print(report)
    print(f"\nAudit report written: {REPORT_PATH}")


if __name__ == "__main__":
    main()
