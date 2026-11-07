from datetime import date, datetime, time, timedelta

from django.utils import timezone

from health_measurements.models import HealthMeasurement


class RiskRuleEngine:
    """Deterministic R01-R04 screening rules; never calls an AI provider."""

    HEART_RATE_LIMIT = 120
    HEART_RATE_SAMPLES = 50
    DAILY_SAMPLES = 50
    STEP_TARGET = 6_000
    CALORIE_TARGET = 300

    def assess(
        self,
        profile,
        *,
        period_start: datetime | None = None,
        period_end: datetime | None = None,
        today: date | None = None,
    ) -> dict:
        today = today or timezone.localdate()
        period_end = period_end or timezone.now()
        period_start = period_start or (period_end - timedelta(days=30))
        if timezone.is_naive(period_start):
            period_start = timezone.make_aware(period_start, timezone.get_current_timezone())
        if timezone.is_naive(period_end):
            period_end = timezone.make_aware(period_end, timezone.get_current_timezone())

        recent = HealthMeasurement.objects.filter(
            profile=profile,
            measured_at__gte=period_start,
            measured_at__lte=period_end,
        )
        heart_rates = list(
            recent.filter(measurement_type="HEART_RATE")
            .order_by("-measured_at")[: self.HEART_RATE_SAMPLES]
        )
        # R03/R04 are daily cumulative rules: use the latest snapshot for the
        # selected end date, never sum cumulative snapshots.
        selected_day = timezone.localtime(period_end).date()
        daily = recent.filter(measured_at__date=selected_day)
        steps = list(
            daily.filter(measurement_type="STEPS")
            .order_by("-measured_at")[: self.DAILY_SAMPLES]
        )
        calories = list(
            daily.filter(measurement_type="CALORIES")
            .order_by("-measured_at")[: self.DAILY_SAMPLES]
        )

        applicable = len(heart_rates) >= 3 or bool(steps or calories)
        analyzed_count = len(heart_rates) + len(steps) + len(calories)
        if not applicable:
            return {
                "risk_level": "UNKNOWN",
                "analyzed_count": analyzed_count,
                "triggered_rules": [],
                "warnings": ["Chưa đủ dữ liệu để đánh giá R01–R04 trong khoảng đã chọn."],
                "summary": "Chưa đủ dữ liệu để tạo nhận định nguy cơ.",
                "recommendation": "Bổ sung ít nhất 3 mẫu nhịp tim hoặc dữ liệu bước chân/calo trong ngày cuối kỳ phân tích.",
                "recommendations": [
                    "R01/R02 cần tối thiểu 3 bản ghi nhịp tim.",
                    "R03/R04 cần dữ liệu bước chân hoặc calo trong ngày cuối kỳ.",
                ],
            }

        level = "LOW"
        triggered_rules = []
        warnings = []
        if len(heart_rates) >= 3:
            values = [float(row.value) for row in reversed(heart_rates)]
            elevated = [value > self.HEART_RATE_LIMIT for value in values]
            if any(elevated):
                triggered_rules.append("R01")
                warnings.append("R01: Có nhịp tim vượt 120 bpm; cần theo dõi và đo lại.")
                level = "MEDIUM"
            if any(elevated[i - 2] and elevated[i - 1] and elevated[i] for i in range(2, len(elevated))):
                triggered_rules.append("R02")
                warnings.append("R02: Có ít nhất 3 lần đo liên tiếp vượt 120 bpm.")
                level = "HIGH"

        if steps and float(steps[0].value) < self.STEP_TARGET:
            triggered_rules.append("R03")
            warnings.append(
                f"R03: Tổng bước trong ngày thấp hơn 6.000 ({float(steps[0].value):.0f} bước)."
            )
        if calories and float(calories[0].value) < self.CALORIE_TARGET:
            triggered_rules.append("R04")
            warnings.append(
                f"R04: Calo trong ngày thấp hơn 300 kcal ({float(calories[0].value):.0f} kcal)."
            )

        if not warnings:
            warnings.append("Không có R01–R04 nào được kích hoạt trong dữ liệu đã chọn.")
        recommendation = {
            "HIGH": "Có chỉ số cần được theo dõi. Hãy đo lại đúng hướng dẫn và liên hệ nhân viên y tế nếu bất thường kéo dài hoặc có triệu chứng.",
            "MEDIUM": "Theo dõi nhịp tim và đo lại trong điều kiện phù hợp; liên hệ nhân viên y tế nếu bất thường lặp lại hoặc có triệu chứng.",
            "LOW": "Chưa phát hiện cảnh báo theo các quy tắc thử nghiệm đang bật. Kết quả chỉ mang tính tham khảo, không thay thế chẩn đoán y tế.",
        }[level]
        return {
            "risk_level": level,
            "analyzed_count": analyzed_count,
            "triggered_rules": triggered_rules,
            "warnings": warnings,
            "summary": " ".join(warnings),
            "recommendation": recommendation,
            "recommendations": [recommendation],
        }
