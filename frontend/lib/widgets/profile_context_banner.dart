import 'package:flutter/material.dart';
import 'package:frontend/state/profile_selection.dart';

class ProfileContextBanner extends StatelessWidget {
  const ProfileContextBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileSelectionScope.of(context).selectedProfile;
    if (profile == null) return const SizedBox.shrink();
    final name = profile['full_name']?.toString() ?? 'Hồ sơ';
    final relation = profileRelationshipLabel(profile);
    final roleLabel = profileRoleLabel(profile) ?? 'Chủ sở hữu';
    final role = switch (roleLabel) {
      'Chủ hộ' || 'Chủ sở hữu' => 'OWNER',
      'Người chăm sóc' => 'CAREGIVER',
      _ => 'MEMBER',
    };
    final shareLevel = profile['share_level']?.toString();
    final permissions = switch (role) {
      'OWNER' => 'Toàn quyền quản lý hồ sơ và dữ liệu',
      'CAREGIVER' => 'Xem chỉ số & Kết quả sàng lọc',
      'MEMBER' =>
        shareLevel == 'VIEW_AND_LOG'
            ? 'Xem và ghi nhật ký theo quyền Owner cấp'
            : 'Chỉ xem dữ liệu được Owner chia sẻ',
      _ => 'Chỉ xem dữ liệu được Owner chia sẻ',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB8DAD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang xem hồ sơ của: $name · Quan hệ: $relation',
            style: const TextStyle(
              color: Color(0xFF18343A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đang xem với vai trò: $roleLabel · Quyền hạn: $permissions',
            style: const TextStyle(
              color: Color(0xFF18343A),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
