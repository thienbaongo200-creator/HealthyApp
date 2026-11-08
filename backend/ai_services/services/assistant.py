from collections import defaultdict
from calendar import monthrange
from datetime import datetime, time, timedelta
from statistics import mean

from django.utils import timezone
from health_measurements.models import HealthMeasurement

from ai_services.providers.exceptions import ProviderError
from ai_services.providers.local import LocalRuleProvider


CONVERSATION_CONTEXT_LIMIT = 8
MEASUREMENT_LOOKBACK_DAYS = 90
STALE_MEASUREMENT_DAYS = 14


def build_conversation_context(messages):
    """Format a bounded, already-authorized conversation tail for the provider."""
    entries = []
    for item in messages:
        role = getattr(item, "role", "")
        content = " ".join(getattr(item, "content", "").split())
        if role in {"USER", "ASSISTANT"} and content:
            entries.append(f"{role}: {content[:1000]}")
    if not entries:
        return ""
    return "LỊCH SỬ HỘI THOẠI GẦN ĐÂY (cũ đến mới):\n" + "\n".join(entries)


def _in_window(rows, start, end):
    return [row for row in rows if start <= row.measured_at <= end]


def _average(values):
    return mean(values) if values else None


def _number(value, decimals=1):
    if value is None:
        return "chưa có dữ liệu"
    return f"{value:.{decimals}f}"


def _window_trend(current, previous, unit):
    if current is None or previous is None:
        return "chưa đủ dữ liệu để so sánh với tuần trước"
    difference = current - previous
    if abs(difference) < 0.05:
        return f"gần như ổn định so với tuần trước ({_number(difference)} {unit})"
    direction = "tăng" if difference > 0 else "giảm"
    return f"{direction} {_number(abs(difference))} {unit} so với tuần trước"


def _month_windows(now):
    local_now = timezone.localtime(now)
    current_start = local_now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    previous_month_end = current_start.date() - timedelta(days=1)
    previous_start = current_start.replace(
        year=previous_month_end.year,
        month=previous_month_end.month,
        day=1,
    )
    previous_day = min(local_now.day, monthrange(previous_start.year, previous_start.month)[1])
    previous_end = previous_start.replace(
        day=previous_day,
        hour=23,
        minute=59,
        second=59,
        microsecond=999999,
    )
    return current_start, local_now, previous_start, previous_end


def _daily_latest_totals(rows, start_date, end_date):
    # Keep one cumulative Wear snapshot per day instead of double-counting updates.
    latest_by_day = {}
    for row in rows:
        day = timezone.localtime(row.measured_at).date()
        if start_date <= day <= end_date and (
            day not in latest_by_day or row.measured_at > latest_by_day[day].measured_at
        ):
            latest_by_day[day] = row
    return latest_by_day


def _comparison(current, previous, unit, period):
    if current is None or previous is None:
        return f"chưa đủ dữ liệu để so sánh {period}"
    difference = current - previous
    if abs(difference) < 0.05:
        return f"gần như ổn định {period} ({_number(difference)} {unit})"
    direction = "tăng" if difference > 0 else "giảm"
    return f"{direction} {_number(abs(difference))} {unit} {period}"


def _trend_alert(name, current, previous, *, threshold, upward=True):
    if current is None or previous is None or previous == 0:
        return None
    change = (current - previous) / abs(previous)
    if (upward and change >= threshold) or (not upward and change <= -threshold):
        direction = "tăng" if change > 0 else "giảm"
        return f"{name} {direction} khoảng {abs(change) * 100:.0f}% so với tuần trước."
    return None


def build_health_context(profile, conversation_messages=None, *, now=None):
    """Build bounded, data-derived summaries and optional recent conversation context."""
    now = now or timezone.now()
    start = now - timedelta(days=MEASUREMENT_LOOKBACK_DAYS)
    measurements = list(
        HealthMeasurement.objects.filter(profile=profile, measured_at__gte=start, measured_at__lte=now)
        .order_by("-measured_at")[:500]
    )
    by_type = defaultdict(list)
    for row in measurements:
        by_type[row.measurement_type].append(row)

    week_start = now - timedelta(days=7)
    previous_week_start = now - timedelta(days=14)
    month_start, month_end, previous_month_start, previous_month_end = _month_windows(now)
    current_week = {
        kind: _in_window(rows, week_start, now)
        for kind, rows in by_type.items()
    }
    previous_week = {
        kind: _in_window(rows, previous_week_start, week_start)
        for kind, rows in by_type.items()
    }
    current_month = {
        kind: _in_window(rows, month_start, month_end)
        for kind, rows in by_type.items()
    }
    previous_month = {
        kind: _in_window(rows, previous_month_start, previous_month_end)
        for kind, rows in by_type.items()
    }
    lines = []
    alerts = []
    positives = []
    trends = []
    recommendations = []

    heart = by_type.get("HEART_RATE", [])
    heart_week = current_week.get("HEART_RATE", [])
    heart_previous = previous_week.get("HEART_RATE", [])
    heart_month = current_month.get("HEART_RATE", [])
    heart_previous_month = previous_month.get("HEART_RATE", [])
    if heart:
        current_average = _average([float(row.value) for row in heart_week])
        previous_average = _average([float(row.value) for row in heart_previous])
        month_average = _average([float(row.value) for row in heart_month])
        previous_month_average = _average([float(row.value) for row in heart_previous_month])
        latest = heart[0]
        lines.append(
            "HEART_RATE: "
            f"gần nhất {_number(float(latest.value))} bpm; "
            f"trung bình 7 ngày {_number(current_average)} bpm ({len(heart_week)} lần đo); "
            f"trung bình 7 ngày trước {_number(previous_average)} bpm ({len(heart_previous)} lần đo); "
            f"trung bình tháng này {_number(month_average)} bpm ({len(heart_month)} lần đo); "
            f"tháng trước đến cùng ngày {_number(previous_month_average)} bpm "
            f"({len(heart_previous_month)} lần đo); "
            f"{len(heart)} lần đo trong 90 ngày."
        )
        trends.extend((
            f"Nhịp tim: {_window_trend(current_average, previous_average, 'bpm')}.",
            "Nhịp tim: " + _comparison(
                month_average,
                previous_month_average,
                "bpm",
                "so với tháng trước đến cùng ngày",
            ) + ".",
        ))
        if current_average is not None and current_average > 100:
            alerts.append(f"Nhịp tim trung bình 7 ngày cao hơn 100 bpm ({current_average:.1f} bpm).")
            recommendations.append("Đo lại khi nghỉ ngơi; nếu bất thường kéo dài hoặc kèm triệu chứng, liên hệ nhân viên y tế.")
        elif current_average is not None and current_average < 60:
            alerts.append(f"Nhịp tim trung bình 7 ngày thấp hơn 60 bpm ({current_average:.1f} bpm).")
            recommendations.append("Đối chiếu với tình trạng và thuốc đang dùng; hỏi nhân viên y tế nếu có triệu chứng.")
        elif current_average is not None:
            positives.append("Nhịp tim trung bình 7 ngày chưa chạm ngưỡng cảnh báo thử nghiệm của ứng dụng.")
        trend_alert = _trend_alert(
            "Nhịp tim trung bình",
            current_average,
            previous_average,
            threshold=0.15,
        ) if len(heart_week) >= 2 and len(heart_previous) >= 2 else None
        if trend_alert:
            alerts.append(trend_alert)

    pressures = [row for row in by_type.get("BLOOD_PRESSURE", []) if row.value_secondary is not None]
    pressure_week = [row for row in current_week.get("BLOOD_PRESSURE", []) if row.value_secondary is not None]
    pressure_previous = [row for row in previous_week.get("BLOOD_PRESSURE", []) if row.value_secondary is not None]
    pressure_month = [row for row in current_month.get("BLOOD_PRESSURE", []) if row.value_secondary is not None]
    pressure_previous_month = [row for row in previous_month.get("BLOOD_PRESSURE", []) if row.value_secondary is not None]
    if pressures:
        systolic = _average([float(row.value) for row in pressure_week])
        diastolic = _average([float(row.value_secondary) for row in pressure_week])
        prior_systolic = _average([float(row.value) for row in pressure_previous])
        month_systolic = _average([float(row.value) for row in pressure_month])
        month_diastolic = _average([float(row.value_secondary) for row in pressure_month])
        previous_month_systolic = _average([float(row.value) for row in pressure_previous_month])
        previous_month_diastolic = _average([float(row.value_secondary) for row in pressure_previous_month])
        latest = pressures[0]
        lines.append(
            "BLOOD_PRESSURE: "
            f"gần nhất {float(latest.value):.0f}/{float(latest.value_secondary):.0f} mmHg; "
            f"trung bình 7 ngày {_number(systolic)}/{_number(diastolic)} mmHg "
            f"({len(pressure_week)} lần đo); "
            f"tuần trước {_number(prior_systolic)} mmHg tâm thu ({len(pressure_previous)} lần đo); "
            f"trung bình tháng này {_number(month_systolic)}/{_number(month_diastolic)} mmHg; "
            f"tháng trước đến cùng ngày {_number(previous_month_systolic)}/"
            f"{_number(previous_month_diastolic)} mmHg; "
            f"{len(pressures)} lần đo trong 90 ngày."
        )
        trends.extend((
            "Huyết áp tâm thu: " + _comparison(
                systolic, prior_systolic, "mmHg", "so với tuần trước"
            ) + ".",
            "Huyết áp tâm thu: " + _comparison(
                month_systolic,
                previous_month_systolic,
                "mmHg",
                "so với tháng trước đến cùng ngày",
            ) + ".",
        ))
        if systolic is not None and diastolic is not None and (systolic >= 140 or diastolic >= 90):
            alerts.append(f"Trung bình huyết áp 7 ngày cao ({systolic:.1f}/{diastolic:.1f} mmHg), theo ngưỡng sàng lọc của ứng dụng.")
            recommendations.append("Đo lại đúng hướng dẫn ở nhiều thời điểm; trao đổi với nhân viên y tế, nhất là khi chỉ số cao lặp lại.")
        elif systolic is not None and diastolic is not None:
            positives.append("Trung bình huyết áp 7 ngày chưa chạm ngưỡng cảnh báo thử nghiệm của ứng dụng.")
        if len(pressure_week) >= 2 and len(pressure_previous) >= 2:
            trend_alert = _trend_alert("Huyết áp tâm thu trung bình", systolic, prior_systolic, threshold=0.10)
            if trend_alert:
                alerts.append(trend_alert)

    for kind, intent, unit in (("STEPS", "STEPS", "bước"), ("CALORIES", "CALORIES", "kcal")):
        rows = by_type.get(kind, [])
        if not rows:
            continue
        today = timezone.localtime(now).date()
        current_daily = _daily_latest_totals(rows, (today - timedelta(days=6)), today)
        previous_daily = _daily_latest_totals(rows, (today - timedelta(days=13)), today - timedelta(days=7))
        current_total = sum(float(row.value) for row in current_daily.values())
        previous_total = sum(float(row.value) for row in previous_daily.values())
        month_daily = _daily_latest_totals(
            rows, month_start.date(), month_end.date()
        )
        previous_month_daily = _daily_latest_totals(
            rows, previous_month_start.date(), previous_month_end.date()
        )
        current_month_average = (
            _average([float(row.value) for row in month_daily.values()])
            if month_daily else None
        )
        previous_month_average = (
            _average([float(row.value) for row in previous_month_daily.values()])
            if previous_month_daily else None
        )
        lines.append(
            f"{intent}: tổng 7 ngày gần nhất {_number(current_total, 0)} {unit} "
            f"({len(current_daily)} ngày có dữ liệu); "
            f"7 ngày trước {_number(previous_total, 0)} {unit} "
            f"({len(previous_daily)} ngày có dữ liệu); "
            f"trung bình/ngày tháng này {_number(current_month_average, 0)} {unit}; "
            f"tháng trước đến cùng ngày {_number(previous_month_average, 0)} {unit}; "
            f"{len(rows)} bản ghi trong 90 ngày."
        )
        trends.extend((
            f"{intent}: {_comparison(current_total, previous_total, unit, 'so với 7 ngày trước')}.",
            f"{intent}: {_comparison(current_month_average, previous_month_average, unit, 'so với tháng trước đến cùng ngày')}.",
        ))
        if kind == "STEPS" and len(current_daily) >= 3 and len(previous_daily) >= 3:
            trend_alert = _trend_alert("Số bước", current_total, previous_total, threshold=0.30, upward=False)
            if trend_alert:
                alerts.append(trend_alert)
                recommendations.append("Kiểm tra xem dữ liệu đồng bộ có bị thiếu không; duy trì vận động phù hợp với thể trạng.")
            elif current_total >= previous_total:
                positives.append("Tổng số bước 7 ngày không giảm so với tuần trước.")

    sleep = by_type.get("SLEEP", [])
    if sleep:
        sleep_week = current_week.get("SLEEP", [])
        sleep_previous = previous_week.get("SLEEP", [])
        sleep_month = current_month.get("SLEEP", [])
        sleep_previous_month = previous_month.get("SLEEP", [])
        current_average = _average([float(row.value) for row in sleep_week])
        previous_average = _average([float(row.value) for row in sleep_previous])
        month_average = _average([float(row.value) for row in sleep_month])
        previous_month_average = _average([float(row.value) for row in sleep_previous_month])
        lines.append(
            "SLEEP: "
            f"gần nhất {_number(float(sleep[0].value))} giờ; "
            f"trung bình 7 ngày {_number(current_average)} giờ ({len(sleep_week)} lần ghi); "
            f"tuần trước {_number(previous_average)} giờ ({len(sleep_previous)} lần ghi); "
            f"trung bình tháng này {_number(month_average)} giờ; "
            f"tháng trước đến cùng ngày {_number(previous_month_average)} giờ."
        )
        trends.extend((
            f"Giấc ngủ: {_window_trend(current_average, previous_average, 'giờ')}.",
            "Giấc ngủ: " + _comparison(
                month_average,
                previous_month_average,
                "giờ",
                "so với tháng trước đến cùng ngày",
            ) + ".",
        ))
        if current_average is not None and current_average < 6:
            alerts.append(f"Thời lượng ngủ trung bình 7 ngày thấp ({current_average:.1f} giờ/đêm theo dữ liệu ghi nhận).")
            recommendations.append("Theo dõi lịch ngủ; nếu khó ngủ kéo dài hoặc ảnh hưởng sinh hoạt, trao đổi với nhân viên y tế.")

    bmi_records = by_type.get("BMI", [])
    bmi_value = float(bmi_records[0].value) if bmi_records else None
    bmi_source = "bản ghi" if bmi_records else ""
    latest_weight = by_type.get("WEIGHT", [])
    latest_height = by_type.get("HEIGHT", [])
    weight_kg = float(latest_weight[0].value) if latest_weight else (
        float(profile.weight_kg) if profile.weight_kg else None
    )
    height_cm = float(latest_height[0].value) if latest_height else (
        float(profile.height_cm) if profile.height_cm else None
    )
    if bmi_value is None and height_cm and weight_kg:
        height_m = height_cm / 100
        if height_m > 0:
            bmi_value = weight_kg / (height_m * height_m)
            bmi_source = "tính từ số đo gần nhất hoặc chiều cao/cân nặng hồ sơ"
    if bmi_value is not None:
        lines.append(f"BMI: {_number(bmi_value, 1)} ({bmi_source}); không thay thế đánh giá y tế.")

    for kind, label, unit in (
        ("BLOOD_GLUCOSE", "BLOOD_GLUCOSE", "đơn vị theo bản ghi"),
        ("WEIGHT", "WEIGHT", "kg"),
        ("TEMPERATURE", "TEMPERATURE", "°C"),
    ):
        rows = by_type.get(kind, [])
        if rows:
            lines.append(
                f"{label}: gần nhất {_number(float(rows[0].value))} {unit}; "
                f"{len(rows)} lần đo trong 90 ngày."
            )

    latest_measurement = HealthMeasurement.objects.filter(profile=profile).order_by("-measured_at").first()
    if latest_measurement is None:
        alerts.append("Hồ sơ chưa có dữ liệu đo sức khỏe.")
        recommendations.append("Ghi nhận một số đo phù hợp trước khi yêu cầu nhận xét xu hướng.")
    elif latest_measurement.measured_at < now - timedelta(days=STALE_MEASUREMENT_DAYS):
        age_days = (now - latest_measurement.measured_at).days
        alerts.append(f"Chưa có dữ liệu đo mới trong khoảng {age_days} ngày.")
        recommendations.append("Cập nhật số đo nếu người dùng vẫn đang theo dõi sức khỏe.")

    if not lines:
        lines.append("Chưa có dữ liệu đo trong 90 ngày gần đây.")
    if not alerts:
        alerts.append("Chưa phát hiện bất thường theo các kiểm tra xu hướng đơn giản; điều này không xác nhận sức khỏe bình thường.")
    if not positives:
        positives.append("Chưa đủ dữ liệu để nêu chỉ số tích cực theo các tiêu chí sàng lọc hiện có.")
    if not recommendations:
        recommendations.append("Tiếp tục ghi nhận chỉ số đều đặn và trao đổi với nhân viên y tế khi có triệu chứng hoặc lo ngại.")
    if not trends:
        trends.append("Chưa đủ dữ liệu để so sánh xu hướng tuần hoặc tháng.")

    context_lines = [
        f"PROFILE_TYPE: {profile.profile_type}",
        "DỮ LIỆU SỨC KHỎE THỰC TẾ (thống kê từ hồ sơ đang được phép truy cập):",
        *lines,
        "TÍN HIỆU TÍCH CỰC:",
        *[f"- {positive}" for positive in positives],
        "ĐIỂM CẦN THEO DÕI:",
        *[f"- {alert}" for alert in alerts],
        "XU HƯỚNG:",
        *[f"- {trend}" for trend in trends],
        "KHUYẾN NGHỊ:",
        *[f"- {recommendation}" for recommendation in recommendations],
    ]
    history = build_conversation_context(conversation_messages or [])
    if history:
        context_lines.extend(("", history))
    return "\n".join(context_lines)


def get_assistant_provider():
    return LocalRuleProvider()


def generate_reply(*, message: str, context: str):
    """Return (reply, provider, is_fallback) without hiding provider failures."""
    try:
        provider = get_assistant_provider()
    except ProviderError:
        local = LocalRuleProvider()
        return local.generate_reply(message=message, context=context), local, True

    try:
        reply = provider.generate_reply(message=message, context=context)
        if not isinstance(reply, str) or not reply.strip():
            raise ProviderError("Assistant provider returned invalid output.")
        return reply, provider, False
    except ProviderError:
        if isinstance(provider, LocalRuleProvider):
            raise
        local = LocalRuleProvider()
        return local.generate_reply(message=message, context=context), local, True
