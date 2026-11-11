from datetime import date, datetime, timedelta

from django.utils import timezone

from health_measurements.models import HealthMeasurement


class RiskRuleEngine:
    """Deterministic R01-R07 screening rules; never calls an AI provider."""

    HEART_RATE_LIMIT = 120
    HEART_RATE_SAMPLES = 50
    STEP_TARGET = 6_000
    CALORIE_TARGET = 300
    HIGH_SYSTOLIC = 140
    HIGH_DIASTOLIC = 90
    SLEEP_MINIMUM_HOURS = 6.0
    HIGH_TEMPERATURE_C = 37.8

    @staticmethod
    def _preferred_latest(recent, measurement_type):
        matching = recent.filter(measurement_type=measurement_type)
        manual = matching.filter(source="MANUAL").order_by("-measured_at").first()
        if manual is not None:
            return manual
        return matching.filter(source="WEAR_OS").order_by("-measured_at").first()

    @classmethod
    def _latest_blood_pressure(cls, recent):
        return cls._preferred_latest(recent, "BLOOD_PRESSURE")

    @classmethod
    def _latest_sleep(cls, recent):
        return cls._preferred_latest(recent, "SLEEP")

    @classmethod
    def _latest_temperature(cls, recent):
        return cls._preferred_latest(recent, "TEMPERATURE")

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
        period_start = period_start or (period_end - timedelta(days=7))
        if timezone.is_naive(period_start):
            period_start = timezone.make_aware(period_start, timezone.get_current_timezone())
        if timezone.is_naive(period_end):
            period_end = timezone.make_aware(period_end, timezone.get_current_timezone())

        # Manual entries lead the screening. Wear OS supplements heart-rate
        # samples or acts as a fallback for daily totals.
        recent = HealthMeasurement.objects.filter(
            profile=profile,
            measured_at__gte=period_start,
            measured_at__lte=period_end,
            source__in=("MANUAL", "WEAR_OS"),
        )
        heart_rate_query = recent.filter(measurement_type="HEART_RATE")
        manual_heart_rates = list(
            heart_rate_query.filter(source="MANUAL")
            .order_by("-measured_at")[: self.HEART_RATE_SAMPLES]
        )
        wearable_limit = self.HEART_RATE_SAMPLES - len(manual_heart_rates)
        wearable_heart_rates = (
            list(
                heart_rate_query.filter(source="WEAR_OS")
                .order_by("-measured_at")[:wearable_limit]
            )
            if wearable_limit > 0
            else []
        )
        heart_rates = sorted(
            [*manual_heart_rates, *wearable_heart_rates],
            key=lambda measurement: measurement.measured_at,
            reverse=True,
        )

        # Use one daily cumulative snapshot (never sum days), preferring the
        # latest manual value and falling back to Wear OS when it is absent.
        def latest_daily_value(measurement_type):
            manual = recent.filter(
                measurement_type=measurement_type,
                source="MANUAL",
            ).order_by("-measured_at").first()
            if manual is not None:
                return manual
            return recent.filter(
                measurement_type=measurement_type,
                source="WEAR_OS",
            ).order_by("-measured_at").first()

        steps = latest_daily_value("STEPS")
        calories = latest_daily_value("CALORIES")
        blood_pressure = self._latest_blood_pressure(recent)
        sleep = self._latest_sleep(recent)
        temperature = self._latest_temperature(recent)

        applicable = bool(heart_rates or steps or calories or blood_pressure or sleep or temperature)
        analyzed_count = len(heart_rates) + int(steps is not None) + int(
            calories is not None
        ) + int(blood_pressure is not None) + int(sleep is not None) + int(temperature is not None)
        if not applicable:
            return {
                "risk_level": "UNKNOWN",
                "analyzed_count": analyzed_count,
                "triggered_rules": [],
                "warnings": ["Chưa đủ dữ liệu để đánh giá các chỉ số sức khỏe trong khoảng đã chọn."],
                "summary": "Chưa đủ dữ liệu để tạo nhận định nguy cơ.",
                "recommendation": "Nhập một chỉ số nhịp tim hoặc tổng bước chân/calo trong 7 ngày gần đây để bắt đầu sàng lọc.",
                "recommendations": [
                    "Có thể nhập thủ công một lần đo nhịp tim; không cần thiết bị đeo.",
                    "Có thể nhập tổng bước chân hoặc calo trong một ngày để sàng lọc.",
                ],
            }

        level = "LOW"
        triggered_rules = []
        warnings = []
        if heart_rates:
            values = [float(row.value) for row in reversed(heart_rates)]
            elevated = [value > self.HEART_RATE_LIMIT for value in values]
            if any(elevated):
                triggered_rules.append("R01")
                warnings.append("R01: Có nhịp tim vượt 120 bpm; cần theo dõi và đo lại.")
                level = "MEDIUM"
            if any(
                elevated[index - 2]
                and elevated[index - 1]
                and elevated[index]
                for index in range(2, len(elevated))
            ):
                triggered_rules.append("R02")
                warnings.append("R02: Có ít nhất 3 lần đo liên tiếp vượt 120 bpm.")
                level = "HIGH"

        if steps is not None and float(steps.value) < self.STEP_TARGET:
            triggered_rules.append("R03")
            warnings.append(
                f"R03: Tổng bước trong ngày thấp hơn 6.000 ({float(steps.value):.0f} bước)."
            )
        if calories is not None and float(calories.value) < self.CALORIE_TARGET:
            triggered_rules.append("R04")
            warnings.append(
                f"R04: Calo trong ngày thấp hơn 300 kcal ({float(calories.value):.0f} kcal)."
            )

        if blood_pressure is not None and (
            float(blood_pressure.value) >= self.HIGH_SYSTOLIC
            or (
                blood_pressure.value_secondary is not None
                and float(blood_pressure.value_secondary) >= self.HIGH_DIASTOLIC
            )
        ):
            triggered_rules.append("R05")
            diastolic = (
                f"{float(blood_pressure.value_secondary):.0f}"
                if blood_pressure.value_secondary is not None
                else "n/a"
            )
            warnings.append(
                f"R05: Blood pressure high ({float(blood_pressure.value):.0f}/"
                f"{diastolic} mmHg)."
            )
            level = "MEDIUM"

        if sleep is not None and float(sleep.value) < self.SLEEP_MINIMUM_HOURS:
            triggered_rules.append("R06")
            warnings.append(f"R06: Sleep duration below 6 hours ({float(sleep.value):.2f} hours).")

        if temperature is not None and float(temperature.value) >= self.HIGH_TEMPERATURE_C:
            triggered_rules.append("R07")
            warnings.append(f"R07: High temperature ({float(temperature.value):.1f} \u00b0C).")
            level = "MEDIUM"

        if not warnings:
            warnings.append("Không có cảnh báo nào được kích hoạt trong dữ liệu đã chọn.")
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
