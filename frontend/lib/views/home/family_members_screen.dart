import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/error_mapper.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/widgets/profile_context_banner.dart';
import 'package:frontend/widgets/widgets.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});
  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  static const _relations = <String, String>{
    'FATHER': 'Bố',
    'MOTHER': 'Mẹ',
    'SPOUSE': 'Vợ/Chồng',
    'CHILD': 'Con',
    'SIBLING': 'Anh/Chị/Em',
    'OTHER': 'Khác',
  };
  static const _roleLabels = <String, String>{
    'OWNER': 'Chủ hộ',
    'CAREGIVER': 'Người chăm sóc',
    'MEMBER': 'Thành viên',
  };
  static const _shareLabels = <String, String>{
    'VIEW_ONLY': 'Chỉ xem',
    'VIEW_AND_LOG': 'Xem và ghi chỉ số',
  };
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _households = [];
  List<Map<String, dynamic>> _accountMembers = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = normalizeProfiles(await ApiService.fetchProfiles());
      if (!mounted) return;
      final households = await ApiService.fetchHouseholds();
      if (!mounted) return;
      final accountMembers = <Map<String, dynamic>>[];
      for (final household in households) {
        if (household['viewer_role']?.toString() != 'OWNER') continue;
        final householdId = household['id']?.toString();
        if (householdId == null) continue;
        accountMembers.addAll(await ApiService.fetchHouseholdMembers(householdId));
      }
      if (!mounted) return;
      final invitations = await ApiService.fetchHouseholdInvitations();
      if (!mounted) return;
      ProfileSelectionScope.of(context).setProfiles(profiles);
      setState(() {
        _profiles = profiles;
        _households = households;
        _accountMembers = accountMembers;
        _invitations = invitations;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMapper.toUserMessage(e.toString());
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? profile]) async {
    final result = await showDialog<_ProfileDraft>(
      context: context,
      builder: (_) => _ProfileEditor(
        profile: profile,
        relations: _relations,
        roles: _roleLabels,
      ),
    );
    if (result == null) return;
    try {
      if (profile == null) {
        await ApiService.createDependentProfile(
          fullName: result.name,
          relationType: result.relation,
          householdRole: result.role,
          dateOfBirth: result.dateOfBirth,
          gender: result.gender,
        );
      } else {
        await ApiService.updateProfileDetails(
          profileId: profile['id'].toString(),
          fullName: result.name,
          relationType: result.relation,
          householdRole: result.role,
          dateOfBirth: result.dateOfBirth,
          gender: result.gender,
        );
      }
      await _load();
      if (mounted) {
        _message(profile == null ? 'Đã thêm hồ sơ.' : 'Đã cập nhật hồ sơ.');
      }
    } catch (e) {
      if (mounted) _message(ErrorMapper.toUserMessage(e.toString()));
    }
  }

  bool get _hasOwnedHousehold => _households.any(
    (household) => household['viewer_role']?.toString() == 'OWNER',
  );

  Future<bool> _createHousehold() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _HouseholdNameEditor(),
    );
    if (!mounted || name == null || name.trim().isEmpty) return false;

    try {
      await ApiService.createHousehold(name: name.trim());
      if (!mounted) return false;
      await _load();
      if (mounted) _message('Đã tạo hộ gia đình.');
      return true;
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
      return false;
    }
  }

  Future<void> _startDependentProfileCreation() async {
    if (!_hasOwnedHousehold) {
      final householdCreated = await _createHousehold();
      if (!householdCreated) return;
    }
    if (!mounted) return;
    await _edit();
  }

  Future<void> _inviteMember(String householdId) async {
    final draft = await showDialog<_InvitationDraft>(
      context: context,
      builder: (_) => const _InvitationEditor(),
    );
    if (!mounted || draft == null) return;

    try {
      await ApiService.inviteHouseholdMember(
        householdId: householdId,
        email: draft.email,
        role: draft.role,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _message('Đã gửi lời mời.');
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  Future<void> _respondToInvitation(
    Map<String, dynamic> invitation,
    String action,
  ) async {
    try {
      await ApiService.respondToHouseholdInvitation(
        memberId: invitation['id'].toString(),
        action: action,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        _message(
          action == 'accept' ? 'Đã chấp nhận lời mời.' : 'Đã từ chối lời mời.',
        );
      }
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  Future<void> _delete(Map<String, dynamic> profile) async {
    if (profile['profile_type'] == 'SELF') {
      _message('Không thể xóa hồ sơ chính.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu trữ hồ sơ?'),
        content: Text('Hồ sơ ${profile['full_name']} sẽ được lưu trữ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ApiService.archiveProfile(profile['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) _message(ErrorMapper.toUserMessage(e.toString()));
    }
  }

  Future<void> _leaveHousehold(Map<String, dynamic> household) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời hộ gia đình?'),
        content: Text(
          'Bạn sẽ mất quyền truy cập các hồ sơ được chia sẻ trong '
          '${household['name']}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời hộ'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ApiService.leaveHousehold(household['id'].toString());
      await _load();
      if (mounted) _message('Đã rời hộ gia đình.');
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  Future<void> _dissolveHousehold(Map<String, dynamic> household) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giải tán hộ gia đình?'),
        content: Text(
          'Hộ gia đình ${household['name']} sẽ bị xóa cùng các lời mời, '
          'thành viên và quyền chia sẻ. Các hồ sơ sức khỏe vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ApiService.dissolveHousehold(household['id'].toString());
      await _load();
      if (mounted) _message('Đã giải tán hộ gia đình.');
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý thành viên gia đình',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_hasOwnedHousehold)
            IconButton(
              onPressed: _loading ? null : _createHousehold,
              icon: const Icon(Icons.home_work_outlined),
              tooltip: 'Tạo hộ gia đình',
            ),
          IconButton(
            onPressed: _loading ? null : _startDependentProfileCreation,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Thêm hồ sơ phụ thuộc',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  children: [
                    const ProfileContextBanner(),
                    SectionHeader(title: '${_profiles.length} hồ sơ'),
                    const SizedBox(height: AppSpacing.x4),
                    const SectionHeader(title: 'Lời mời đang chờ'),
                    if (_invitations.isEmpty)
                      const PendingInvitationsEmptyState()
                    else ...[
                      for (final invitation in _invitations)
                        _invitationCard(invitation),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    const SectionHeader(title: 'Hộ gia đình'),
                    if (_households.isEmpty)
                      HouseholdEmptyState(
                        onCreateHousehold: _createHousehold,
                        onCreateDependent: _startDependentProfileCreation,
                      )
                    else ...[
                      for (final household in _households)
                        _householdCard(household),
                    ],
                    if (_accountMembers.any(_isAccountMember)) ...[
                      const SizedBox(height: AppSpacing.x4),
                      const SectionHeader(title: 'Tài khoản được mời'),
                      for (final member in _accountMembers.where(_isAccountMember))
                        _accountMemberCard(member),
                    ],
                    const SizedBox(height: AppSpacing.x3),
                    if (_profiles.isEmpty)
                      EmptyState(
                        title: 'Chưa có hồ sơ thành viên',
                        message: 'Thêm hồ sơ để quản lý sức khỏe gia đình.',
                        icon: Icons.groups_outlined,
                        action: PrimaryButton(
                          label: 'Thêm hồ sơ phụ thuộc',
                          icon: Icons.person_add_alt_1,
                          onPressed: _startDependentProfileCreation,
                        ),
                      ),
                    for (final p in _profiles) _profileCard(p),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _invitationCard(Map<String, dynamic> invitation) => AppCard(
    margin: const EdgeInsets.only(top: AppSpacing.x2),
    padding: const EdgeInsets.all(AppSpacing.x3),
    child: Row(
      children: [
        const Icon(Icons.mail_outline, color: AppColors.primary),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation['household_name']?.toString() ?? 'Hộ gia đình',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                'Vai trò: ${_roleLabels[invitation['role']] ?? _roleLabels['MEMBER']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Từ chối lời mời',
          onPressed: () => _respondToInvitation(invitation, 'decline'),
          icon: const Icon(Icons.close),
        ),
        IconButton(
          tooltip: 'Chấp nhận lời mời',
          onPressed: () => _respondToInvitation(invitation, 'accept'),
          icon: const Icon(Icons.check, color: AppColors.primary),
        ),
      ],
    ),
  );

  Widget _householdCard(Map<String, dynamic> household) => AppCard(
    margin: const EdgeInsets.only(top: AppSpacing.x2),
    padding: const EdgeInsets.all(AppSpacing.x3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    household['name']?.toString() ?? 'Hộ gia đình',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  StatusBadge(
                    label:
                        _roleLabels[household['viewer_role']] ??
                        _roleLabels['MEMBER']!,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.x1,
          runSpacing: AppSpacing.x1,
          children: [
            if (household['viewer_role'] == 'OWNER')
              TextButton.icon(
                onPressed: () => _inviteMember(household['id'].toString()),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Mời'),
              ),
            if (household['viewer_role'] == 'OWNER')
              TextButton.icon(
                onPressed: () => _dissolveHousehold(household),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Giải tán hộ gia đình'),
              ),
            if (household['viewer_role'] != 'OWNER')
              TextButton(
                onPressed: () => _leaveHousehold(household),
                child: const Text('Rời hộ gia đình'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _profileCard(Map<String, dynamic> profile) {
    final selected =
        ProfileSelectionScope.of(context).selectedProfileId ==
        profile['id']?.toString();
    final canEdit =
        profile['profile_type'] != 'SELF' && _viewerRoleOf(profile) == 'OWNER';
    final demographicSummary = profileDemographicSubtitle(profile);
    final height = _profileNumber(profile['height_cm']);
    final weight = _profileNumber(profile['weight_kg']);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.all(AppSpacing.x3),
      onTap: () => ProfileSelectionScope.of(
        context,
      ).selectProfileId(profile['id'].toString()),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primary,
            child: Text(
              (profile['full_name']?.toString().characters.firstOrNull ?? '?'),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['full_name']?.toString() ?? 'Hồ sơ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  _relationshipLabel(profile),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  demographicSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (height != null || weight != null) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    [
                      if (height != null) '${_formatProfileNumber(height)} cm',
                      if (weight != null) '${_formatProfileNumber(weight)} kg',
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.x1),
                StatusBadge(
                  label: profile['profile_type'] == 'DEPENDENT'
                      ? 'Hồ sơ phụ thuộc'
                      : profile['is_current_user'] == true
                      ? 'Hồ sơ chính'
                      : _roleLabels[_roleOf(profile)] ?? 'Thành viên',
                  tone: selected ? StatusTone.success : StatusTone.neutral,
                ),
              ],
            ),
          ),
          if (profile['profile_type'] == 'DEPENDENT' && canEdit)
            PopupMenuButton<String>(
              tooltip: 'Thao tác hồ sơ phụ thuộc',
              onSelected: (value) =>
                  value == 'edit' ? _edit(profile) : _delete(profile),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa hồ sơ')),
                PopupMenuItem(value: 'delete', child: Text('Lưu trữ hồ sơ')),
              ],
            )
          else if (selected)
            const Icon(Icons.check_circle, color: AppColors.success)
          else
            const Icon(Icons.shield_outlined, color: AppColors.textSecondary)
        ],
      ),
    );
  }

  bool _isAccountMember(Map<String, dynamic> member) =>
      member['profile_type'] == 'SELF' &&
      member['role'] != 'OWNER' &&
      (member['user_email']?.toString().isNotEmpty ?? false);

  Widget _accountMemberCard(Map<String, dynamic> member) {
    final householdId = member['household']?.toString();
    final householdName = member['household_name']?.toString() ?? 'Hộ gia đình';
    final role = member['role']?.toString() ?? 'MEMBER';
    final status = member['status']?.toString();
    final shares = member['shares'] is List
        ? (member['shares'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final share = shares.isEmpty ? null : shares.first;
    final shareLevel = share?['share_level']?.toString();
    final canManage = _households.any(
      (h) => h['id']?.toString() == householdId && h['viewer_role'] == 'OWNER',
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['profile_name']?.toString() ?? 'Thành viên',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if ((member['user_email']?.toString() ?? '').isNotEmpty)
                  Text(
                    member['user_email'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.x1),
                Wrap(
                  spacing: AppSpacing.x1,
                  runSpacing: AppSpacing.x1,
                  children: [
                    StatusBadge(
                      label: _roleLabels[role] ?? 'Thành viên',
                      tone: StatusTone.neutral,
                    ),
                    if (shareLevel != null)
                      StatusBadge(
                        label: _shareLabels[shareLevel] ?? shareLevel,
                        tone: StatusTone.success,
                      ),
                    if (status == 'PENDING')
                      const StatusBadge(label: 'Chờ xác nhận'),
                  ],
                ),
                Text(
                  householdName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (canManage && status == 'ACTIVE')
            IconButton(
              tooltip: 'Quản lý vai trò và quyền chia sẻ',
              onPressed: () => _manageAccountMember(member, share),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          if (canManage)
            IconButton(
              tooltip: 'Gỡ khỏi hộ gia đình',
              onPressed: () => _removeAccountMember(member),
              icon: const Icon(Icons.person_remove_outlined),
            ),
        ],
      ),
    );
  }

  Future<void> _manageAccountMember(
    Map<String, dynamic> member,
    Map<String, dynamic>? share,
  ) async {
    final result = await showDialog<_MemberDraft>(
      context: context,
      builder: (_) => _HouseholdMemberEditor(member: member, share: share),
    );
    if (result == null) return;
    try {
      await ApiService.updateHouseholdMember(
        householdId: member['household'].toString(),
        memberId: member['id'].toString(),
        role: result.role,
        shareLevel: result.shareLevel,
        shareProfileId: share?['profile_id']?.toString(),
      );
      await _load();
      if (mounted) _message('Đã cập nhật quyền thành viên.');
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  Future<void> _removeAccountMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ khỏi hộ gia đình?'),
        content: Text(
          'Tài khoản ${member['user_email'] ?? member['profile_name'] ?? ''} '
          'sẽ mất quyền truy cập được chia sẻ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ thành viên'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.removeHouseholdMember(
        householdId: member['household'].toString(),
        memberId: member['id'].toString(),
      );
      await _load();
    } catch (error) {
      if (mounted) _message(ErrorMapper.toUserMessage(error.toString()));
    }
  }

  String _relationshipLabel(Map<String, dynamic> profile) {
    if (profile['profile_type'] == 'SELF') return 'Hồ sơ chính';
    if (profile['relation_type'] == 'CHILD') {
      return switch (profileGenderLabel(profile['gender'])) {
        'Nam' => 'Con trai',
        'Nữ' => 'Con gái',
        _ => 'Con',
      };
    }
    return _relations[profile['relation_type']] ?? 'Khác';
  }

  double? _profileNumber(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  String _formatProfileNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _roleOf(Map<String, dynamic> profile) {
    final viewerRole = profile['viewer_role']?.toString();
    if (viewerRole != null && viewerRole != 'OWNER') return viewerRole;
    return profile['household_role']?.toString() ??
        (profile['profile_type'] == 'SELF' ? 'OWNER' : 'MEMBER');
  }

  String _viewerRoleOf(Map<String, dynamic> profile) =>
      profile['viewer_role']?.toString() ?? _roleOf(profile);
}

class _ProfileDraft {
  const _ProfileDraft(this.name, this.relation, this.role, this.dateOfBirth, this.gender);
  final String name, relation, role;
  final String? dateOfBirth;
  final String gender;
}

class _MemberDraft {
  const _MemberDraft(this.role, this.shareLevel);
  final String role;
  final String shareLevel;
}

class _HouseholdMemberEditor extends StatefulWidget {
  const _HouseholdMemberEditor({required this.member, required this.share});
  final Map<String, dynamic> member;
  final Map<String, dynamic>? share;

  @override
  State<_HouseholdMemberEditor> createState() => _HouseholdMemberEditorState();
}

class _HouseholdMemberEditorState extends State<_HouseholdMemberEditor> {
  late String _role = widget.member['role']?.toString() ?? 'MEMBER';
  late String _shareLevel =
      widget.share?['share_level']?.toString() ?? 'VIEW_ONLY';

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.all(AppSpacing.x6),
    title: const Text('Quản lý thành viên'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Vai trò'),
          items: const [
            DropdownMenuItem(value: 'MEMBER', child: Text('Thành viên')),
            DropdownMenuItem(value: 'CAREGIVER', child: Text('Người chăm sóc')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _role = value);
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _shareLevel,
          decoration: const InputDecoration(labelText: 'Mức chia sẻ'),
          items: const [
            DropdownMenuItem(value: 'VIEW_ONLY', child: Text('Chỉ xem')),
            DropdownMenuItem(
              value: 'VIEW_AND_LOG',
              child: Text('Xem và ghi chỉ số'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _shareLevel = value);
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _MemberDraft(_role, _shareLevel),
        ),
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _InvitationDraft {
  const _InvitationDraft(this.email, this.role);
  final String email;
  final String role;
}

class _InvitationEditor extends StatefulWidget {
  const _InvitationEditor();

  @override
  State<_InvitationEditor> createState() => _InvitationEditorState();
}

class _InvitationEditorState extends State<_InvitationEditor> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _role = 'MEMBER';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.all(AppSpacing.x6),
    title: const Text('Mời thành viên'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email tài khoản'),
            validator: (value) {
              final email = value?.trim() ?? '';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                  ? null
                  : 'Nhập email hợp lệ';
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: const [
              DropdownMenuItem(value: 'MEMBER', child: Text('Thành viên')),
              DropdownMenuItem(
                value: 'CAREGIVER',
                child: Text('Người chăm sóc'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _InvitationDraft(_emailController.text.trim(), _role),
          );
        },
        child: const Text('Gửi lời mời'),
      ),
    ],
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.relations,
    required this.roles,
    this.profile,
  });
  final Map<String, dynamic>? profile;
  final Map<String, String> relations;
  final Map<String, String> roles;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(
    text: widget.profile?['full_name']?.toString(),
  );
  late final _year = TextEditingController(
    text:
        (widget.profile?['date_of_birth']?.toString().split('-').firstOrNull) ??
        '',
  );
  late String _relation =
      widget.relations.containsKey(widget.profile?['relation_type'])
      ? widget.profile!['relation_type'] as String
      : widget.relations.keys.first;
  late String _role = widget.profile?['household_role'] == 'CAREGIVER'
      ? 'CAREGIVER'
      : 'MEMBER';
  late String _gender = switch (profileGenderLabel(widget.profile?['gender'])) {
    'Nam' => 'Nam',
    'Nữ' => 'Nữ',
    'Khác' => 'Khác',
    _ => 'Khác',
  };
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.all(AppSpacing.x6),
    title: Text(widget.profile == null ? 'Thêm thành viên' : 'Sửa hồ sơ'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _relation,
            decoration: const InputDecoration(labelText: 'Quan hệ'),
            items: [
              for (final e in widget.relations.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _relation = v);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Giới tính'),
            items: const [
              DropdownMenuItem(value: 'Nam', child: Text('Nam')),
              DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
              DropdownMenuItem(value: 'Khác', child: Text('Khác')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _gender = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Vai trò gia đình'),
            items: [
              for (final role in const ['MEMBER', 'CAREGIVER'])
                DropdownMenuItem(value: role, child: Text(widget.roles[role]!)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'Năm sinh (không bắt buộc)',
            ),
            validator: (v) =>
                v != null && v.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(v)
                ? 'Nhập năm gồm 4 chữ số'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final year = _year.text.trim();
          Navigator.pop(
            context,
            _ProfileDraft(
              _name.text.trim(),
              _relation,
              _role,
              year.isEmpty ? null : '$year-01-01',
              _gender,
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class PendingInvitationsEmptyState extends StatelessWidget {
  const PendingInvitationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
    child: Row(
      children: [
        const Icon(Icons.mark_email_unread_outlined, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.x2),
        const Expanded(
          child: Text('Hiện không có lời mời nào đang chờ.'),
        ),
      ],
    ),
  );
}

class HouseholdEmptyState extends StatelessWidget {
  const HouseholdEmptyState({
    super.key,
    required this.onCreateHousehold,
    required this.onCreateDependent,
  });

  final Future<bool> Function() onCreateHousehold;
  final Future<void> Function() onCreateDependent;

  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(top: AppSpacing.x2),
    padding: const EdgeInsets.all(AppSpacing.x3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chưa có hộ gia đình',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Tạo hộ gia đình để thêm hồ sơ phụ thuộc và mời thành viên.',
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x1,
          children: [
            FilledButton.icon(
              onPressed: onCreateHousehold,
              icon: const Icon(Icons.home_work_outlined),
              label: const Text('Tạo hộ gia đình'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateDependent,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Thêm hồ sơ phụ thuộc'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HouseholdNameEditor extends StatefulWidget {
  const _HouseholdNameEditor();

  @override
  State<_HouseholdNameEditor> createState() => _HouseholdNameEditorState();
}

class _HouseholdNameEditorState extends State<_HouseholdNameEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo hộ gia đình'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Tên hộ gia đình'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Nhập tên hộ gia đình'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _nameController.text.trim());
        },
        child: const Text('Tạo'),
      ),
    ],
  );
}
