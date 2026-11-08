import re
import unicodedata


_INTENT_TERMS = {
    "EMERGENCY": (
        "cap cuu", "dau nguc", "kho tho", "ngat", "dot quy",
        "khong tho duoc", "mat y thuc", "chest pain", "stroke",
    ),
    "MEDICATION": (
        "thuoc", "don thuoc", "lieu dung", "uong thuoc", "medication", "medicine",
    ),
    "BLOOD_PRESSURE": ("huyet ap", "blood pressure", "tam thu", "tam truong"),
    "HEART_RATE": ("nhip tim", "tim dap", "mach", "heart rate"),
    "SLEEP": ("giac ngu", "ngu", "mat ngu", "sleep"),
    "STEP_COUNT": ("buoc chan", "so buoc", "di bo", "steps", "step count"),
    "CALORIES": ("calo", "kcal", "calories", "nang luong tieu thu"),
    "BMI": ("bmi", "chi so co the"),
    "TREND": (
        "tot hon", "cai thien", "tuan nay so voi", "tuan truoc",
        "thang nay", "thang truoc", "xu huong", "tang hay giam",
        "so sanh thang", "so voi thang",
    ),
    "GENERAL_HEALTH": (
        "suc khoe", "tinh trang", "dang lo", "tong quan", "cai thien",
        "tuan nay", "tuan truoc", "co tot hon", "chi so nao", "health",
        "co nguy co", "dang chu y", "bat thuong", "concerning",
    ),
}

_METRIC_KEYS = {
    "HEART_RATE": ("HEART_RATE:",),
    "BLOOD_PRESSURE": ("BLOOD_PRESSURE:", "Huyết áp:"),
    "SLEEP": ("SLEEP:",),
    "STEP_COUNT": ("STEPS:",),
    "CALORIES": ("CALORIES:",),
    "BMI": ("BMI:",),
}

_DISCLAIMER = (
    "Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán hoặc tư vấn "
    "của nhân viên y tế."
)
_OUT_OF_SCOPE = "Tôi chỉ hỗ trợ phân tích dữ liệu sức khỏe trong hệ thống HealthyApp."


def _normalize(text):
    normalized = unicodedata.normalize("NFD", text.casefold())
    return "".join(char for char in normalized if unicodedata.category(char) != "Mn").replace("đ", "d")


def _contains_term(text, term):
    return re.search(rf"(?<!\w){re.escape(term)}(?!\w)", text) is not None


def detect_intent(message):
    """Return one of the local health-chat intent labels."""
    text = _normalize(message)
    for intent, terms in _INTENT_TERMS.items():
        if any(_contains_term(text, term) for term in terms):
            return intent
    return "UNKNOWN"


def _conversation_lines(context):
    marker = "LỊCH SỬ HỘI THOẠI GẦN ĐÂY (cũ đến mới):"
    if marker not in context:
        return []
    return [
        line for line in context.split(marker, 1)[1].splitlines()
        if line.startswith(("USER: ", "ASSISTANT: "))
    ]


def _context_lines(context):
    marker = "LỊCH SỬ HỘI THOẠI GẦN ĐÂY (cũ đến mới):"
    return context.split(marker, 1)[0].splitlines()


def _metric_line(lines, intent):
    prefixes = _METRIC_KEYS.get(intent, ())
    return next(
        (line for line in lines if line.startswith(prefixes)),
        None,
    ) if prefixes else None


def _metric_details(lines, intent):
    aliases = {
        "HEART_RATE": ("heart_rate", "nhip tim"),
        "BLOOD_PRESSURE": ("blood_pressure", "huyet ap"),
        "SLEEP": ("sleep", "giac ngu"),
        "STEP_COUNT": ("steps", "buoc"),
        "CALORIES": ("calories", "calo", "kcal"),
        "BMI": ("bmi",),
    }.get(intent, ())
    if not aliases:
        return []
    detail_sections = (
        ("XU HƯỚNG", "xu huong"),
        ("ĐIỂM CẦN THEO DÕI", "diem can theo doi"),
    )
    details = []
    for heading, _ in detail_sections:
        for line in LocalRuleProvider._section(lines, heading).splitlines():
            normalized = _normalize(line)
            if any(_contains_term(normalized, alias) for alias in aliases):
                details.append(line)
    return details


def _follow_up_intent(message, history):
    text = _normalize(message)
    follow_up_kind = None
    if any(_contains_term(text, term) for term in ("neu tiep tuc", "se the nao", "tuong lai", "co tien trien")):
        follow_up_kind = "PROJECTION"
    elif any(_contains_term(text, term) for term in ("nguy hiem", "co sao khong", "co dang lo")):
        follow_up_kind = "DANGER"
    elif any(_contains_term(text, term) for term in ("nen lam gi", "lam gi tiep", "toi nen lam", "nen di kham")):
        follow_up_kind = "ACTION"
    elif any(_contains_term(text, term) for term in ("tai sao", "vi sao", "nguyen nhan")):
        follow_up_kind = "WHY"
    elif any(_contains_term(text, term) for term in (
        "y ban", "noi ro", "giai thich", "con no", "chi so do",
        "ket qua do", "vay thi sao", "what do you mean", "explain",
    )):
        follow_up_kind = "CLARIFY"
    if follow_up_kind is None:
        return None

    prior_intent = None
    for line in reversed(history):
        if not line.startswith("USER: "):
            continue
        prior_message = line[6:]
        intent = detect_intent(prior_message)
        if intent != "UNKNOWN":
            prior_intent = intent
            break
        if _follow_up_intent_kind(prior_message) is not None:
            continue
    if prior_intent is None:
        current_intent = detect_intent(message)
        if current_intent in {
            "HEART_RATE", "BLOOD_PRESSURE", "SLEEP", "STEP_COUNT",
            "CALORIES", "BMI", "GENERAL_HEALTH", "TREND",
        }:
            prior_intent = current_intent
    return (follow_up_kind, prior_intent) if prior_intent else None


def _follow_up_intent_kind(message):
    text = _normalize(message)
    if any(_contains_term(text, term) for term in ("nguy hiem", "co sao khong", "co dang lo")):
        return "DANGER"
    if any(_contains_term(text, term) for term in ("nen lam gi", "lam gi tiep", "toi nen lam", "nen di kham")):
        return "ACTION"
    if any(_contains_term(text, term) for term in ("tai sao", "vi sao", "nguyen nhan")):
        return "WHY"
    if any(_contains_term(text, term) for term in ("neu tiep tuc", "se the nao", "tuong lai", "co tien trien")):
        return "PROJECTION"
    if any(_contains_term(text, term) for term in (
        "y ban", "noi ro", "giai thich", "con no", "chi so do",
        "ket qua do", "vay thi sao", "what do you mean", "explain",
    )):
        return "CLARIFY"
    return None


class LocalRuleProvider:
    name = "local"
    model_version = "rules-v2"

    def generate_reply(self, *, message: str, context: str) -> str:
        normalized_message = _normalize(message)
        if any(_contains_term(normalized_message, term) for term in (
            "tu tao du lieu", "bia du lieu", "tao so do gia", "fake health data",
        )):
            return (
                "Tôi không thể tự tạo hoặc bịa dữ liệu sức khỏe. "
                "Chỉ số cần được ghi nhận từ phép đo thực tế."
            )

        intent = detect_intent(message)
        history = _conversation_lines(context)
        lines = _context_lines(context)
        if intent == "EMERGENCY":
            answer = (
                "Nếu bạn hoặc người bên cạnh đang đau ngực dữ dội, khó thở, ngất "
                "hoặc có dấu hiệu đột quỵ, hãy gọi cấp cứu địa phương hoặc đến cơ sở "
                "cấp cứu ngay; đừng chờ ứng dụng đánh giá."
            )
            return f"{answer}\n\n{_DISCLAIMER}"

        dependent_reference = any(_contains_term(normalized_message, term) for term in (
            "con toi", "cua con", "ho so con", "me toi", "bo toi",
            "nguoi than", "vo toi", "chong toi",
        ))
        profile_type = next(
            (line.partition(":")[2].strip() for line in lines if line.startswith("PROFILE_TYPE:")),
            None,
        )
        if dependent_reference and profile_type == "SELF":
            return (
                "Phân tích hiện chỉ dùng hồ sơ SELF đang được chọn. "
                "Hãy chọn đúng hồ sơ người thân trước khi hỏi để tránh nhầm dữ liệu.\n\n"
                f"{_DISCLAIMER}"
            )

        if any(_contains_term(normalized_message, term) for term in (
            "co nen di kham", "co can di kham", "nen gap bac si",
            "should i see a doctor", "should i see a clinician",
        )):
            alerts = self._section(lines, "ĐIỂM CẦN THEO DÕI")
            recommendations = self._section(lines, "KHUYẾN NGHỊ")
            answer = (
                "Tôi không thể quyết định thay nhân viên y tế. "
                f"Điểm cần theo dõi trong dữ liệu: {alerts or 'chưa đủ dữ liệu để nhận xét'} "
                f"Khuyến nghị hiện có: {recommendations or 'ghi nhận thêm dữ liệu và trao đổi với nhân viên y tế nếu bạn lo ngại.'}"
            )
            return f"{answer}\n\n{_DISCLAIMER}"

        follow_up = _follow_up_intent(message, history)
        if follow_up:
            follow_up_kind, previous_intent = follow_up
            metric = _metric_line(lines, previous_intent)
            alerts = self._section(lines, "ĐIỂM CẦN THEO DÕI")
            recommendations = self._section(lines, "KHUYẾN NGHỊ")
            trends = self._section(lines, "XU HƯỚNG")
            previous = next(
                (line[11:] for line in reversed(history) if line.startswith("ASSISTANT: ")),
                None,
            )
            if follow_up_kind == "PROJECTION":
                answer = (
                    "Tôi không thể dự đoán tương lai. Dữ liệu hiện có cho thấy:\n"
                    f"{trends or 'Chưa đủ dữ liệu để đánh giá xu hướng.'}"
                )
            elif follow_up_kind == "DANGER":
                has_alert = alerts and not alerts.startswith("Chưa phát hiện bất thường")
                answer = (
                    f"Dữ liệu cần theo dõi: {metric or alerts}. "
                    "Đây là cảnh báo sàng lọc, không đủ cơ sở kết luận mức độ nguy hiểm "
                    "hay chẩn đoán. Nếu có triệu chứng nghiêm trọng, hãy liên hệ cấp cứu."
                    if has_alert else
                    "Chưa thấy cảnh báo theo các quy tắc hiện có, nhưng điều đó không "
                    "chứng minh là an toàn hoặc không có bệnh. Hãy chú ý triệu chứng."
                )
            elif follow_up_kind == "ACTION":
                answer = f"Khuyến nghị dựa trên hồ sơ:\n{recommendations or 'Chưa có đủ dữ liệu để đưa khuyến nghị cá thể hóa.'}"
            elif follow_up_kind == "WHY":
                answer = (
                    f"Dữ liệu liên quan: {metric or 'chưa có chỉ số tương ứng'}\n"
                    f"Điểm cần theo dõi: {alerts or 'chưa có cảnh báo'}"
                )
            else:
                answer = (
                    f"Ý mình ở câu trước là: {previous or 'các chỉ số trong hồ sơ đang chọn.'}"
                    + (f"\nDữ liệu liên quan hiện tại: {metric}" if metric else "")
                )
            return f"{answer}\n\n{_DISCLAIMER}"

        if intent == "UNKNOWN":
            return _OUT_OF_SCOPE

        if intent == "MEDICATION":
            answer = (
                "Tôi chưa có dữ liệu đơn thuốc đã xác minh trong phần phân tích này. "
                "Không tự ý bắt đầu, ngừng hoặc đổi liều thuốc; hãy hỏi bác sĩ hoặc dược sĩ "
                "đang theo dõi bạn."
            )
            return f"{answer}\n\n{_DISCLAIMER}"

        if intent == "GENERAL_HEALTH":
            summary = self._section(lines, "DỮ LIỆU SỨC KHỎE THỰC TẾ")
            positives = self._section(lines, "TÍN HIỆU TÍCH CỰC")
            alerts = self._section(lines, "ĐIỂM CẦN THEO DÕI")
            trends = self._section(lines, "XU HƯỚNG")
            recommendations = self._section(lines, "KHUYẾN NGHỊ")
            answer = "\n".join(
                part for part in (
                    "Tổng quan:",
                    summary,
                    "Điểm tích cực:",
                    positives,
                    "Điểm cần theo dõi:",
                    alerts,
                    "Xu hướng:",
                    trends,
                    "Khuyến nghị:",
                    recommendations,
                ) if part
            )
            return f"{answer}\n\n{_DISCLAIMER}"

        if intent == "TREND":
            trends = self._section(lines, "XU HƯỚNG")
            answer = trends or "Chưa đủ dữ liệu để so sánh xu hướng."
            return f"Xu hướng theo dữ liệu hiện có:\n{answer}\n\n{_DISCLAIMER}"

        if intent == "BMI":
            result = _metric_line(lines, intent)
            answer = result or "Chưa có BMI hoặc đủ chiều cao/cân nặng trong dữ liệu hồ sơ để tính."
        else:
            result = _metric_line(lines, intent)
            if result:
                answer = result
            else:
                label = {
                    "HEART_RATE": "nhịp tim",
                    "BLOOD_PRESSURE": "huyết áp",
                    "SLEEP": "giấc ngủ",
                    "STEP_COUNT": "số bước",
                    "CALORIES": "calo",
                }.get(intent, "chỉ số")
                answer = f"Chưa có dữ liệu {label} trong khoảng phân tích của hồ sơ đang chọn."
        details = _metric_details(lines, intent) if result else []
        if details:
            answer = f"{answer}\n" + "\n".join(details)
        return f"{answer}\n\n{_DISCLAIMER}"

    @staticmethod
    def _section(lines, heading):
        heading_index = next(
            (index for index, line in enumerate(lines) if line.startswith(heading)),
            None,
        )
        if heading_index is None:
            return ""
        result = []
        for line in lines[heading_index + 1:]:
            if line.endswith(":") and line[:-1].isupper():
                break
            if line.strip():
                result.append(line.removeprefix("- ").strip())
        return "\n".join(result)
