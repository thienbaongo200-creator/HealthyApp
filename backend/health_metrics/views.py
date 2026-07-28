from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from .models import HealthData
from .serializers import HealthDataSerializer

class HealthDataListCreateView(APIView):
    # Lưu ý: Khi test dev chưa có Auth Token, có thể đổi tạm thành [AllowAny()]
    # Khi chạy chuẩn có login thì nên dùng [IsAuthenticated()]
    permission_classes = [AllowAny]

    def get(self, request):
        """GET /api/health/ - Lấy danh sách lịch sử đo sức khỏe"""
        # Nếu có user đăng nhập thì lọc theo user, nếu không lấy toàn bộ để test
        if request.user.is_authenticated:
            records = HealthData.objects.filter(user=request.user)
        else:
            records = HealthData.objects.all()[:50] # Lấy 50 bản ghi mới nhất

        serializer = HealthDataSerializer(records, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """POST /api/health/ - Lưu bản ghi sức khỏe mới từ Flutter gửi lên"""
        serializer = HealthDataSerializer(data=request.data)
        if serializer.is_valid():
            # Nếu user đã login thì gán user đó, nếu chưa thì gán tạm user đầu tiên trong DB (để test dev)
            user = request.user if request.user.is_authenticated else None
            
            serializer.save(user=user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

