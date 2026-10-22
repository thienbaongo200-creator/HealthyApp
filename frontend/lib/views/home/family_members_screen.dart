import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/widgets/profile_context_banner.dart';

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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await ApiService.fetchProfiles();
      final households = await ApiService.fetchHouseholds();
      if (!mounted) return;
      ProfileSelectionScope.of(context).setProfiles(profiles);
      setState(() {
        _profiles = profiles;
        _households = households;
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
        );
      } else {
        await ApiService.updateProfileDetails(
          profileId: profile['id'].toString(),
          fullName: result.name,
          relationType: result.relation,
          householdRole: result.role,
          dateOfBirth: result.dateOfBirth,
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const ProfileContextBanner(),
                  Text(
                    '${_profiles.length} hồ sơ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_households.any(
                    (household) => household['viewer_role'] != 'OWNER',
                  )) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Hộ gia đình được tham gia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final household in _households)
                      if (household['viewer_role'] != 'OWNER')
                        Card(
                          child: ListTile(
                            title: Text(
                              household['name']?.toString() ?? 'Hộ gia đình',
                            ),
                            subtitle: Text(
                              _roleLabels[household['viewer_role']] ??
                                  _roleLabels['MEMBER']!,
                            ),
                            trailing: TextButton(
                              onPressed: () => _leaveHousehold(household),
                              child: const Text('Rời hộ'),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 12),
                  for (final p in _profiles)
                    Card(
                      color:
                          ProfileSelectionScope.of(context).selectedProfileId ==
                              p['id']?.toString()
                          ? const Color(0xFFF2FAF8)
                          : null,
                      child: ListTile(
                        onTap: () => ProfileSelectionScope.of(
                          context,
                        ).selectProfileId(p['id'].toString()),
                        leading: CircleAvatar(
                          child: Text(
                            (p['full_name']
                                    ?.toString()
                                    .characters
                                    .firstOrNull ??
                                '?'),
                          ),
                        ),
                        title: Text(p['full_name']?.toString() ?? 'Hồ sơ'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['profile_type'] == 'SELF'
                                  ? 'Hồ sơ chính'
                                  : (_relations[p['relation_type']] ?? 'Khác'),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F5F2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _roleLabels[_roleOf(p)] ??
                                    _roleLabels['MEMBER']!,
                                style: const TextStyle(
                                  color: Color(0xFF246B65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            p['profile_type'] == 'SELF' ||
                                _viewerRoleOf(p) != 'OWNER'
                            ? const Icon(Icons.shield_outlined)
                            : PopupMenuButton<String>(
                                onSelected: (v) =>
                                    v == 'edit' ? _edit(p) : _delete(p),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Sửa'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Lưu trữ'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _roleOf(Map<String, dynamic> profile) =>
      profile['household_role']?.toString() ??
      (profile['profile_type'] == 'SELF' ? 'OWNER' : 'MEMBER');

  String _viewerRoleOf(Map<String, dynamic> profile) =>
      profile['viewer_role']?.toString() ?? _roleOf(profile);
}

class _ProfileDraft {
  const _ProfileDraft(this.name, this.relation, this.role, this.dateOfBirth);
  final String name, relation, role;
  final String? dateOfBirth;
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
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
