import 'package:flutter/material.dart';
import 'package:frontend/widgets/widgets.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _canvas = Color(0xFFF5F9F8);

  final List<_FamilyMember> _members = [
    _FamilyMember(name: 'Tôi', relation: 'Chủ hồ sơ', birthYear: ''),
    _FamilyMember(name: 'Bố', relation: 'Bố', birthYear: ''),
    _FamilyMember(name: 'Mẹ', relation: 'Mẹ', birthYear: ''),
  ];

  Future<void> _editMember([int? index]) async {
    final existing = index == null ? null : _members[index];
    final result = await showDialog<_FamilyMember>(
      context: context,
      builder: (context) => _MemberEditor(member: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _members.add(result);
      } else {
        _members[index] = result;
      }
    });
  }

  Future<void> _deleteMember(int index) async {
    final member = _members[index];
    if (member.relation == 'Chủ hồ sơ') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa hồ sơ chính.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text('Bạn có chắc muốn xóa hồ sơ ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC74747)),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _members.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Quản lý thành viên gia đình',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () => _editMember(),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Thêm'),
              style: TextButton.styleFrom(
                foregroundColor: _teal,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: _members.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F5F2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.family_restroom, color: _teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_members.length} hồ sơ thành viên',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.verified_user_outlined, color: _teal),
                    ],
                  ),
                );
              }
              final memberIndex = index - 1;
              final member = _members[memberIndex];
              final isPrimary = member.relation == 'Chủ hồ sơ';
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFE7F5F2),
                          child: Text(
                            member.name.isEmpty ? '?' : member.name.characters.first,
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                member.relation,
                                style: const TextStyle(
                                  color: Color(0xFF7D8B88),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPrimary)
                          const Icon(Icons.shield_outlined, color: _teal, size: 20),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, color: Color(0xFFE8EFED)),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            size: 17, color: Color(0xFF82908D)),
                        const SizedBox(width: 8),
                        Text(
                          member.birthYear.isEmpty
                              ? 'Năm sinh chưa cập nhật'
                              : 'Năm sinh ${member.birthYear}',
                          style: const TextStyle(
                            color: Color(0xFF687875),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editMember(memberIndex),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Sửa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _teal,
                            side: const BorderSide(color: Color(0xFFB8DAD5)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                        const SizedBox(width: 7),
                        OutlinedButton.icon(
                          onPressed: () => _deleteMember(memberIndex),
                          icon: const Icon(Icons.delete_outline, size: 15),
                          label: const Text('Xóa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC74747),
                            side: const BorderSide(color: Color(0xFFE9C6C6)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FamilyMember {
  const _FamilyMember({
    required this.name,
    required this.relation,
    required this.birthYear,
  });

  final String name;
  final String relation;
  final String birthYear;
}

class _MemberEditor extends StatefulWidget {
  const _MemberEditor({this.member});
  final _FamilyMember? member;

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _birthYearController;
  late String _relation;
  final _formKey = GlobalKey<FormState>();
  static const _relations = ['Bố', 'Mẹ', 'Vợ/Chồng', 'Con', 'Anh/Chị/Em', 'Khác'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _birthYearController =
        TextEditingController(text: widget.member?.birthYear ?? '');
    final savedRelation = widget.member?.relation;
    _relation = savedRelation == 'Chủ hồ sơ' || _relations.contains(savedRelation)
        ? savedRelation!
        : _relations.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _FamilyMember(
        name: _nameController.text.trim(),
        relation: _relation,
        birthYear: _birthYearController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member == null ? 'Thêm thành viên' : 'Sửa hồ sơ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tên thành viên'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Hãy nhập tên thành viên'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _relation,
                decoration: const InputDecoration(labelText: 'Mối quan hệ'),
                items: [
                  if (widget.member?.relation == 'Chủ hồ sơ')
                    const DropdownMenuItem(
                      value: 'Chủ hồ sơ',
                      child: Text('Chủ hồ sơ'),
                    ),
                  for (final relation in _relations)
                    DropdownMenuItem(value: relation, child: Text(relation)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _relation = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Năm sinh (không bắt buộc)',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                    return 'Nhập năm gồm 4 chữ số';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
