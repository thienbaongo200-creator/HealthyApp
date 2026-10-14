from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from profiles.models import PersonProfile
from health_measurements.models import HealthMeasurement
from django.shortcuts import get_object_or_404
import numpy as np

class HealthRiskAssessmentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, profile_id):
        # 1. Xác thực profile tồn tại
        profile = get_object_or_404(PersonProfile, id=profile_id)
        
        # 2. Truy vấn tối đa 50 bản ghi đo lường gần nhất theo thời gian
        measurements = HealthMeasurement.objects.filter(profile=profile).order_by('-measured_at')[:50]
        
        if not measurements.exists():
            return Response(
                {
                    "profile_id": str(profile.id),
                    "risk_level": "UNKNOWN",
                    "analyzed_count": 0,
                    "warnings": ["Không có dữ liệu đo lường để phân tích."],
                    "recommendation": "Vui lòng cập nhật các chỉ số sức khỏe thường xuyên hơn."
                },
                status=status.HTTP_200_OK
            )

        # 3. Phân tích chuỗi thời gian & đánh giá ngưỡng sinh trắc học
        heart_rates = []
        systolic_bps = []
        diastolic_bps = []
        
        for m in measurements:
            val = float(m.value)
            if m.measurement_type == "HEART_RATE":
                heart_rates.append(val)
            elif m.measurement_type == "BLOOD_PRESSURE_SYSTOLIC":
                systolic_bps.append(val)
            elif m.measurement_type == "BLOOD_PRESSURE_DIASTOLIC":
                diastolic_bps.append(val)

        risk_level = "LOW"
        warnings = []
        
        # Kiểm tra ngưỡng nhịp tim (ví dụ: nhịp tim nghỉ ngơi cao > 100 hoặc thấp < 60)
        if heart_rates:
            avg_hr = np.mean(heart_rates)
            if avg_hr > 100:
                risk_level = "MEDIUM"
                warnings.append(f"Trung bình nhịp tim cao ({avg_hr:.1f} bpm).")
            elif avg_hr < 60:
                warnings.append(f"Trung bình nhịp tim thấp ({avg_hr:.1f} bpm).")

        # Kiểm tra ngưỡng huyết áp tâm thu / tâm trương
        if systolic_bps and diastolic_bps:
            avg_sys = np.mean(systolic_bps)
            avg_dia = np.mean(diastolic_bps)
            if avg_sys >= 140 or avg_dia >= 90:
                risk_level = "HIGH"
                warnings.append(f"Cảnh báo huyết áp cao (Trung bình: {avg_sys:.1f}/{avg_dia:.1f} mmHg).")
            elif avg_sys >= 130 or avg_dia >= 80:
                if risk_level != "HIGH":
                    risk_level = "MEDIUM"
                warnings.append(f"Huyết áp ở ngưỡng tiền cao huyết áp ({avg_sys:.1f}/{avg_dia:.1f} mmHg).")

        # Đề xuất hướng dẫn dựa trên mức độ rủi ro
        if risk_level == "HIGH":
            recommendation = "Nguy cơ cao. Khuyến nghị đặt lịch hẹn khám bác sĩ chuyên khoa sớm."
        elif risk_level == "MEDIUM":
            recommendation = "Cần theo dõi sát sao, duy trì lối sống lành mạnh và đo lại sau vài ngày."
        else:
            recommendation = "Các chỉ số ổn định. Hãy tiếp tục duy trì chế độ sinh hoạt hiện tại."

        return Response({
            "profile_id": str(profile.id),
            "risk_level": risk_level,
            "analyzed_count": measurements.count(),
            "warnings": warnings,
            "recommendation": recommendation
        }, status=status.HTTP_200_OK)