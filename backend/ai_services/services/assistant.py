from django.conf import settings
from datetime import timedelta

import numpy as np
from django.utils import timezone
from health_measurements.models import HealthMeasurement

from ai_services.providers.exceptions import ProviderError
from ai_services.providers.local import LocalRuleProvider


def build_health_context(profile):
    """Build a bounded 30-day summary; providers never query the database."""
    since = timezone.now() - timedelta(days=30)
    measurements = list(HealthMeasurement.objects.filter(
        profile=profile, measured_at__gte=since
    ).order_by("-measured_at")[:100])
    by_type = {}
    for row in measurements:
        by_type.setdefault(row.measurement_type, []).append(row)

    lines, notes = [], []
    for kind, records in by_type.items():
        latest = records[0]
        vals = [float(r.value) for r in records]
        if kind == "BLOOD_PRESSURE":
            pairs = [(float(r.value), float(r.value_secondary)) for r in records if r.value_secondary is not None]
            if pairs:
                delta = f"{pairs[0][0]-pairs[-1][0]:+.1f}/{pairs[0][1]-pairs[-1][1]:+.1f} mmHg" if len(pairs) > 1 else "chưa đủ dữ liệu xác định xu hướng"
                lines.append(f"Huyết áp: mới nhất {float(latest.value):.0f}/{float(latest.value_secondary):.0f} mmHg; trung bình 30 ngày {np.mean([p[0] for p in pairs]):.1f}/{np.mean([p[1] for p in pairs]):.1f} mmHg; {len(pairs)} lần đo; thay đổi gần nhất: {delta}.")
                avg_sys, avg_dia = np.mean([p[0] for p in pairs]), np.mean([p[1] for p in pairs])
                if avg_sys >= 140 or avg_dia >= 90:
                    notes.append(f"Huyết áp trung bình 30 ngày cao ({avg_sys:.1f}/{avg_dia:.1f} mmHg).")
            continue
        unit = "bpm" if kind == "HEART_RATE" else latest.unit
        delta = vals[0] - vals[-1] if len(vals) > 1 else None
        trend = f"thay đổi {delta:+.1f} {unit} so với lần đo cũ nhất" if delta is not None else "chưa đủ dữ liệu xác định xu hướng"
        lines.append(f"{kind}: mới nhất {float(latest.value):.1f} {unit}; trung bình 30 ngày {np.mean(vals):.1f} {unit}; {len(records)} lần đo; {trend}.")
        if kind == "HEART_RATE":
            avg = np.mean(vals)
            if avg > 100:
                notes.append(f"Nhịp tim trung bình 30 ngày cao ({avg:.1f} bpm).")
            elif avg < 60:
                notes.append(f"Nhịp tim trung bình 30 ngày thấp ({avg:.1f} bpm).")
    context = "\n".join(lines) if lines else "Chưa có dữ liệu đo trong 30 ngày gần đây."
    note = " ".join(notes) if notes else ("Chưa phát hiện cảnh báo theo các ngưỡng sàng lọc đơn giản." if measurements else "Chưa có dữ liệu đo trong 30 ngày gần đây.")
    return f"{context}\n\nNhận định sàng lọc: {note}"


def get_assistant_provider():
    if getattr(settings, "GEMINI_ENABLED", False):
        try:
            from ai_services.providers.gemini import GeminiProvider
            return GeminiProvider()
        except Exception:
            # Missing SDK/key or client setup failure: local provider remains available.
            pass
    return LocalRuleProvider()


def generate_reply(*, message: str, context: str):
    """Return (reply, provider); runtime Gemini failures fall back to deterministic rules."""
    provider = get_assistant_provider()
    try:
        return provider.generate_reply(message=message, context=context), provider
    except ProviderError:
        local = LocalRuleProvider()
        return local.generate_reply(message=message, context=context), local
