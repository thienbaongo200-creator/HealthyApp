import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
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
    'OWNER': '[Chủ sở hữu]',
    'CAREGIVER': '[Người chăm sóc]',
    'MEMBER': '[Thành viên]',
  };
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _households = [];
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
      final invitations = await ApiService.fetchHouseholdInvitations();
      if (!mounted) return;
      ProfileSelectionScope.of(context).setProfiles(profiles);
      setState(() {
        _profiles = profiles;
        _households = households;
        _invitations = invitations;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
      if (mounted) _message(e.toString());
    }
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
      if (mounted) _message(error.toString());
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
      if (mounted) _message(error.toString());
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
      if (mounted) _message(e.toString());
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
      if (mounted) _message(error.toString());
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final canManageProfiles = _profiles.any(
      (profile) => _viewerRoleOf(profile) == 'OWNER',
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thành viên gia đình'),
        actions: [
          if (canManageProfiles)
            IconButton(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              tooltip: 'Thêm hồ sơ',
            ),
        ],
      ),
      body: _loading
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
                  if (_invitations.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    const SectionHeader(title: 'Lời mời đang chờ'),
                    for (final invitation in _invitations)
                      _invitationCard(invitation),
                  ],
                  if (_households.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    const SectionHeader(title: 'Hộ gia đình'),
                    for (final household in _households)
                      _householdCard(household),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  if (_profiles.isEmpty)
                    EmptyState(
                      title: 'Chưa có hồ sơ thành viên',
                      message: 'Thêm hồ sơ để quản lý sức khỏe gia đình.',
                      icon: Icons.groups_outlined,
                      action: PrimaryButton(
                        label: 'Thêm hồ sơ',
                        icon: Icons.add,
                        onPressed: () => _edit(),
                      ),
                    ),
                  for (final p in _profiles) _profileCard(p),
                ],
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
    child: Row(
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
        if (household['viewer_role'] == 'OWNER')
          TextButton.icon(
            onPressed: () => _inviteMember(household['id'].toString()),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Mời'),
          )
        else
          TextButton(
            onPressed: () => _leaveHousehold(household),
            child: const Text('Rời hộ'),
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
                  label:
                      _roleLabels[_roleOf(profile)] ?? _roleLabels['MEMBER']!,
                  tone: selected ? StatusTone.success : StatusTone.neutral,
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.success)
          else if (!canEdit)
            const Icon(Icons.shield_outlined, color: AppColors.textSecondary)
          else
            PopupMenuButton<String>(
              onSelected: (value) =>
                  value == 'edit' ? _edit(profile) : _delete(profile),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Lưu trữ')),
              ],
            ),
        ],
      ),
    );
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
