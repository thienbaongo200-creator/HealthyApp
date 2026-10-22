import 'package:flutter/material.dart';
import 'package:frontend/state/profile_selection.dart';

class ProfileContextBanner extends StatelessWidget {
  const ProfileContextBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileSelectionScope.of(context).selectedProfile;
    if (profile == null) return const SizedBox.shrink();
    final name = profile['full_name']?.toString() ?? 'Hồ sơ';
    final relationType = profile['relation_type']?.toString();
    final relation = profile['profile_type'] == 'SELF'
        ? 'Chủ hồ sơ'
        : const {
                'FATHER': 'Bố',
                'MOTHER': 'Mẹ',
                'SPOUSE': 'Vợ/Chồng',
                'CHILD': 'Con',
                'SIBLING': 'Anh/Chị/Em',
                'OTHER': 'Khác',
              }[relationType] ??
              'Chưa xác định';
    final role =
        profile['household_role']?.toString() ??
        (profile['profile_type'] == 'SELF' ? 'OWNER' : 'MEMBER');
    final roleLabel =
        const {
          'OWNER': 'Chủ sở hữu',
          'CAREGIVER': 'Người chăm sóc',
          'MEMBER': 'Thành viên',
        }[role] ??
        'Thành viên';
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
