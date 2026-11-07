from django.db.models import Avg, Count, Max, Min
from django.db.models.functions import TruncDay, TruncWeek
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import PermissionService
from health_measurements.models import HealthMeasurement


class MeasurementStatisticsQuerySerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    measurement_type = serializers.ChoiceField(choices=HealthMeasurement.TYPE_CHOICES)
    from_date = serializers.DateTimeField(required=False)
    to_date = serializers.DateTimeField(required=False)
    group_by = serializers.ChoiceField(choices=("day", "week"), default="day")

    def validate(self, attrs):
        start = attrs.get("from_date")
        end = attrs.get("to_date")
        if start and end and start > end:
            raise serializers.ValidationError({"to": "Must be later than or equal to from."})
        return attrs


class MeasurementStatisticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query_data = request.query_params.copy()
        if "from" in query_data and "from_date" not in query_data:
            query_data["from_date"] = query_data["from"]
        if "to" in query_data and "to_date" not in query_data:
            query_data["to_date"] = query_data["to"]
        query = MeasurementStatisticsQuerySerializer(data=query_data)
        query.is_valid(raise_exception=True)
        params = query.validated_data
        profile_id = params["profile_id"]
        if not PermissionService.has_profile_access(request.user, profile_id, "view"):
            raise PermissionDenied("You do not have access to this profile.")

        measurements = HealthMeasurement.objects.filter(
            profile_id=profile_id,
            measurement_type=params["measurement_type"],
        )
        if "from_date" in params:
            measurements = measurements.filter(measured_at__gte=params["from_date"])
        if "to_date" in params:
            measurements = measurements.filter(measured_at__lte=params["to_date"])

        bucket = TruncWeek("measured_at") if params["group_by"] == "week" else TruncDay("measured_at")
        rows = measurements.annotate(period=bucket).values("period").annotate(
            average=Avg("value"),
            average_secondary=Avg("value_secondary"),
            minimum=Min("value"),
            maximum=Max("value"),
            count=Count("id"),
        ).order_by("period")
        return Response({
            "profile_id": str(profile_id),
            "measurement_type": params["measurement_type"],
            "group_by": params["group_by"],
            "results": [
                {
                    "period": row["period"].isoformat(),
                    "average": row["average"],
                    "average_secondary": row["average_secondary"],
                    "minimum": row["minimum"],
                    "maximum": row["maximum"],
                    "count": row["count"],
                }
                for row in rows
            ],
        })
