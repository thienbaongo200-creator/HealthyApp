from rest_framework import permissions
from profiles.models import PersonProfile
from households.models import HouseholdMember, ProfileShare

class PermissionService:
    """
    Dịch vụ trung tâm xử lý logic phân quyền object-level theo Sơ đồ 2.4.
    """
    
    @staticmethod
    def has_profile_access(user, profile_id, required_permission='view'):
        """
        Kiểm tra xem user có quyền truy cập vào một PersonProfile cụ thể hay không.
        - required_permission: 'view' (đọc) hoặc 'edit' (ghi/tạo log)
        """
        if not user or not user.is_authenticated:
            return False
            
        try:
            profile = PersonProfile.objects.select_related('account').get(pk=profile_id, is_archived=False)
        except PersonProfile.DoesNotExist:
            return False

        # 1. Trường hợp chính chủ (Owner của profile)
        if profile.account_id == user.id:
            return True

        # 2. Kiểm tra qua quan hệ Household (User thuộc household chứa profile này với trạng thái ACTIVE)
        user_profiles = PersonProfile.objects.filter(account=user, is_archived=False)
        
        target_households = HouseholdMember.objects.filter(
            profile=profile, status='ACTIVE'
        ).values_list('household_id', flat=True)

        is_household_member = HouseholdMember.objects.filter(
            household_id__in=target_households,
            profile__in=user_profiles,
            status='ACTIVE'
        ).exists()

        if is_household_member:
            member_record = HouseholdMember.objects.filter(
                household_id__in=target_households,
                profile__in=user_profiles,
                status='ACTIVE'
            ).first()
            
            if member_record and member_record.role == 'OWNER':
                return True

        # 3. Kiểm tra qua ProfileShare (Chia sẻ trực tiếp profile cho user)
        shares = ProfileShare.objects.filter(
            profile=profile,
            member__profile__in=user_profiles
        )
        
        for share in shares:
            level = getattr(share, 'share_level', '')
            if required_permission == 'view' and level in ['VIEW_ONLY', 'VIEW_AND_LOG', 'FULL']:
                return True
            if required_permission == 'edit' and level in ['VIEW_AND_LOG', 'FULL']:
                return True

        return False

class IsProfileOwnerOrShared(permissions.BasePermission):
    """
    Custom permission kiểm tra IDOR ở cấp độ Object cho các endpoint liên quan đến PersonProfile hoặc dữ liệu con của profile.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        profile_id = None
        if isinstance(obj, PersonProfile):
            profile_id = obj.id
        elif hasattr(obj, 'profile_id'):
            profile_id = obj.profile_id
        elif hasattr(obj, 'profile'):
            profile_id = obj.profile.id
            
        if not profile_id:
            return False

        req_type = 'edit' if request.method in ['POST', 'PUT', 'PATCH', 'DELETE'] else 'view'
        
        return PermissionService.has_profile_access(request.user, profile_id, required_permission=req_type)