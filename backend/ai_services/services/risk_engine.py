from datetime import date

from django.utils import timezone

from health_measurements.models import HealthMeasurement


class RiskRuleEngine:
    """Deterministic screening rules. This class never calls an LLM."""

    HEART_RATE_LIMIT = 120
    HEART_RATE_SAMPLES = 50
    BLOOD_PRESSURE_SAMPLES = 50
    DAILY_SAMPLES = 50
    STEP_TARGET = 6_000
    CALORIE_TARGET = 300

    def assess(self, profile, *, today: date | None = None) -> dict:
        today = today or timezone.localdate()
        recent = HealthMeasurement.objects.filter(profile=profile)
        heart_rates = list(recent.filter(measurement_type="HEART_RATE").order_by("-measured_at")[:self.HEART_RATE_SAMPLES])
        blood_pressures = list(recent.filter(measurement_type="BLOOD_PRESSURE").order_by("-measured_at")[:self.BLOOD_PRESSURE_SAMPLES])
        steps = list(recent.filter(measurement_type="STEPS", measured_at__date=today).order_by("-measured_at")[:self.DAILY_SAMPLES])
        calories = list(recent.filter(measurement_type="CALORIES", measured_at__date=today).order_by("-measured_at")[:self.DAILY_SAMPLES])

        analyzed_count = sum(map(len, (heart_rates, blood_pressures, steps, calories)))
        applicable = len(heart_rates) >= 3 or bool(blood_pressures or steps or calories)
        if not applicable:
            return {
                "risk_level": "UNKNOWN", "analyzed_count": analyzed_count,
                "warnings": ["Chưa đủ dữ liệu hợp lệ để đánh giá các quy tắc nguy cơ."],
                "recommendation": "Cần ít nhất 3 bản ghi nhịp tim hoặc dữ liệu huyết áp, bước chân hay calo trong ngày để phân tích.",
            }

        level, warnings = "LOW", []
        # R01/R02: evaluate latest samples in chronological order.
        if len(heart_rates) >= 3:
            elevated = [float(row.value) > self.HEART_RATE_LIMIT for row in reversed(heart_rates)]
            if any(elevated):
                level = "MEDIUM"
                warnings.append("R01: Có lần đo nhịp tim vượt 120 bpm; cần theo dõi và đo lại.")
            if any(elevated[i - 2] and elevated[i - 1] and elevated[i] for i in range(2, len(elevated))):
                level = "HIGH"
                warnings.append("R02: Có ít nhất 3 lần đo nhịp tim liên tiếp vượt 120 bpm.")

        high_bp = [row for row in blood_pressures if float(row.value) >= 140 or (row.value_secondary is not None and float(row.value_secondary) >= 90)]
        if high_bp:
            row = high_bp[0]
            diastolic = f"/{float(row.value_secondary):.0f}" if row.value_secondary is not None else ""
            level = "HIGH"
            warnings.append(f"Cảnh báo huyết áp cao: {float(row.value):.0f}{diastolic} mmHg.")

        # Wearable values are cumulative snapshots; use newest value, not their sum.
        if steps and float(steps[0].value) < self.STEP_TARGET:
            warnings.append(f"R03: Tổng số bước trong ngày thấp hơn mục tiêu 6.000 ({float(steps[0].value):.0f} bước).")
        if calories and float(calories[0].value) < self.CALORIE_TARGET:
            warnings.append(f"R04: Calo trong ngày thấp hơn mức thử nghiệm 300 kcal ({float(calories[0].value):.0f} kcal).")

        recommendation = {
            "HIGH": "Có chỉ số cần được theo dõi. Hãy đo lại đúng hướng dẫn và liên hệ nhân viên y tế nếu chỉ số bất thường kéo dài hoặc có triệu chứng.",
            "MEDIUM": "Theo dõi nhịp tim và đo lại trong điều kiện phù hợp; liên hệ nhân viên y tế nếu bất thường lặp lại hoặc có triệu chứng.",
            "LOW": "Chưa phát hiện cảnh báo theo các quy tắc sàng lọc đang bật. Kết quả chỉ mang tính tham khảo, không thay thế chẩn đoán y tế.",
        }[level]
        return {"risk_level": level, "analyzed_count": analyzed_count, "warnings": warnings, "recommendation": recommendation}
