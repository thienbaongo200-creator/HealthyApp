import 'package:flutter/material.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';

class ProfileContextBanner extends StatelessWidget {
  const ProfileContextBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileSelectionScope.of(context).selectedProfile;
    if (profile == null) return const SizedBox.shrink();
    final name = profileDisplayName(profile);
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang xem: $name · $relation',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profileDemographicSubtitle(profile),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$roleLabel · $permissions',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
