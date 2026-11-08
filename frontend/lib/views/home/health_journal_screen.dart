import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/widgets/widgets.dart';
import 'main_navigation_wrapper.dart';
import 'quick_add_screen.dart';

class HealthJournalScreen extends StatefulWidget {
  const HealthJournalScreen({
    super.key,
    this.initialMember = 'Tôi',
    this.initialProfileId,
  });

  final String initialMember;
  final String? initialProfileId;

  @override
  State<HealthJournalScreen> createState() => _HealthJournalScreenState();
}

class _HealthJournalScreenState extends State<HealthJournalScreen> {
  static const _teal = AppColors.primary;
  static const _ink = AppColors.textPrimary;

  late DateTime _selectedDate;
  late String _selectedMember;
  String? _profileId;
  List<Map<String, dynamic>> _profiles = [];
  String _selectedType = 'ALL';
  bool _isLoading = true;
  String? _error;
  int _loadRequestId = 0;
  List<Map<String, dynamic>> _measurements = [];
  ProfileSelectionController? _profileSelection;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedMember = widget.initialMember;
    _profileId = widget.initialProfileId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeasurements());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = ProfileSelectionScope.of(context);
    if (identical(selection, _profileSelection)) return;
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    _profileSelection = selection;
    final selectedProfile = selection.selectedProfile;
    final selectedProfileId = selection.selectedProfileId;
    if (selectedProfileId != null) {
      _profileId = selectedProfileId;
      if (selectedProfile != null) {
        _selectedMember = profileDisplayName(selectedProfile);
      }
    }
    selection.addListener(_onProfileSelectionChanged);
  }

  void _onProfileSelectionChanged() {
    final selection = _profileSelection;
    final selectedProfileId = selection?.selectedProfileId;
    if (!mounted ||
        selectedProfileId == null ||
        selectedProfileId == _profileId) {
      return;
    }
    final profile = selection?.selectedProfile;
    setState(() {
      _profileId = selectedProfileId;
      if (profile != null) _selectedMember = profileDisplayName(profile);
      _measurements = [];
    });
    _loadMeasurements();
  }

  @override
  void dispose() {
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    super.dispose();
  }

  Future<void> _loadMeasurements() async {
    final requestId = ++_loadRequestId;
    if (_selectedMember != 'Tôi' && _profileId == null) {
      setState(() {
        _measurements = [];
        _error = null;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final measurements = await ApiService.fetchHealthMeasurements(
        profileId: _profileId,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _measurements = measurements;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _measurements = [];
        _error = error is ApiException
            ? error.message
            : 'Không thể tải dữ liệu. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  List<_JournalEntry> get _entries {
    final entries = <_JournalEntry>[];
    for (final record in _measurements) {
      final measuredAt = DateTime.tryParse(
        record['measured_at']?.toString() ?? '',
      )?.toLocal();
      if (measuredAt == null ||
          measuredAt.year != _selectedDate.year ||
          measuredAt.month != _selectedDate.month ||
          measuredAt.day != _selectedDate.day) {
        continue;
      }
      final type = record['measurement_type']?.toString();
      if (_selectedType != 'ALL' && type != _selectedType) continue;
      num? number(dynamic raw) =>
          raw is num ? raw : num.tryParse(raw?.toString() ?? '');
      final value = number(record['value']);
      final heartRate = number(
        record['heart_rate'] ?? (type == 'HEART_RATE' ? value : null),
      )?.toInt();
      final steps = number(
        record['steps'] ?? (type == 'STEPS' ? value : null),
      )?.toInt();
      final calories = number(
        record['calories'] ?? (type == 'CALORIES' ? value : null),
      )?.toDouble();
      final detail = switch (type) {
        'HEART_RATE' => 'Nhịp tim ${value?.toStringAsFixed(0) ?? '—'} bpm',
        'BLOOD_PRESSURE' =>
          'Huyết áp ${value?.toStringAsFixed(0) ?? '—'}/${number(record['value_secondary'])?.toStringAsFixed(0) ?? '—'} mmHg',
        'BLOOD_GLUCOSE' =>
          'Đường huyết ${value ?? '—'} ${record['unit'] ?? ''}',
        'WEIGHT' => 'Cân nặng ${value ?? '—'} ${record['unit'] ?? ''}',
        'HEIGHT' => 'Chiều cao ${value ?? '—'} ${record['unit'] ?? ''}',
        'TEMPERATURE' => 'Thân nhiệt ${value ?? '—'} ${record['unit'] ?? ''}',
        'SLEEP' => 'Giấc ngủ ${value?.toStringAsFixed(1) ?? '—'} giờ',
        'STEPS' => 'Hoạt động ${value?.toStringAsFixed(0) ?? '—'} bước',
        'CALORIES' => 'Năng lượng ${value?.toStringAsFixed(0) ?? '—'} kcal',
        _ => null,
      };
      if (heartRate == null &&
          steps == null &&
          calories == null &&
          detail == null) {
        continue;
      }
      entries.add(
        _JournalEntry(
          measuredAt: measuredAt,
          heartRate: heartRate,
          steps: steps,
          calories: calories,
          device: record['device_id']?.toString() ?? 'Thiết bị sức khỏe',
          activityState: record['activity_state']?.toString(),
          detail: detail,
        ),
      );
    }
    entries.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return entries;
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Chọn ngày xem nhật ký',
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _chooseMember() async {
    final selection = ProfileSelectionScope.of(context);
    if (_profiles.isEmpty) {
      try {
        _profiles = await ApiService.fetchProfiles();
        selection.setProfiles(_profiles);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể tải hồ sơ: $error')),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final profileId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn thành viên')),
            for (final profile in _profiles)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profileDisplayName(profile)),
                subtitle: Text(profileDemographicSubtitle(profile)),
                trailing: profile['id']?.toString() == _profileId
                    ? const Icon(Icons.check, color: _teal)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetContext, profile['id']?.toString()),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (profileId != null && mounted && profileId != _profileId) {
      final profile = _profiles
          .where((item) => item['id']?.toString() == profileId)
          .firstOrNull;
      if (profile == null) return;
      ProfileSelectionScope.of(context).selectProfileId(profileId);
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _openQuickAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            QuickAddScreen(member: _selectedMember, profileId: _profileId),
      ),
    );
    if (saved == true && mounted) await _loadMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Nhật ký sức khỏe',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _teal,
            onRefresh: _loadMeasurements,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x6,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _filterButton(
                        icon: Icons.calendar_month_outlined,
                        label: _dateLabel(_selectedDate),
                        onTap: _chooseDate,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: _filterButton(
                        icon: Icons.person_outline,
                        label: _selectedMember,
                        onTap: _chooseMember,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Lọc theo loại chỉ số',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('Tất cả chỉ số'),
                    ),
                    DropdownMenuItem(
                      value: 'HEART_RATE',
                      child: Text('Nhịp tim'),
                    ),
                    DropdownMenuItem(
                      value: 'BLOOD_PRESSURE',
                      child: Text('Huyết áp'),
                    ),
                    DropdownMenuItem(
                      value: 'BLOOD_GLUCOSE',
                      child: Text('Đường huyết'),
                    ),
                    DropdownMenuItem(value: 'SLEEP', child: Text('Giấc ngủ')),
                    DropdownMenuItem(value: 'WEIGHT', child: Text('Cân nặng')),
                    DropdownMenuItem(value: 'HEIGHT', child: Text('Chiều cao')),
                    DropdownMenuItem(
                      value: 'TEMPERATURE',
                      child: Text('Thân nhiệt'),
                    ),
                    DropdownMenuItem(value: 'STEPS', child: Text('Bước đi')),
                    DropdownMenuItem(
                      value: 'CALORIES',
                      child: Text('Năng lượng'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: _teal, size: 19),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _selectedMember == 'Tôi'
                              ? 'Nguồn hiện tại lưu nhịp tim và hoạt động từ đồng hồ. Huyết áp chưa có dữ liệu trong API.'
                              : 'Nhật ký hiện chỉ tải dữ liệu của tài khoản đang đăng nhập; dữ liệu thành viên gia đình chưa được liên kết riêng.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                SectionHeader(
                  title: 'Các mốc đo trong ngày',
                  subtitle: '${entries.length} mốc',
                ),
                const SizedBox(height: AppSpacing.x3),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.x8),
                    child: Center(
                      child: CircularProgressIndicator(color: _teal),
                    ),
                  )
                else if (_error != null)
                  ErrorState(
                    message: _error!,
                    title: 'Chưa tải được nhật ký',
                    onRetry: _loadMeasurements,
                  )
                else if (entries.isEmpty)
                  EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'Chưa có bản ghi trong ngày này',
                    message: _selectedMember == 'Tôi'
                        ? 'Khi đồng hồ gửi dữ liệu, các mốc đo sẽ xuất hiện ở đây.'
                        : 'Chưa có dữ liệu riêng cho thành viên này.',
                    action: PrimaryButton(
                      label: 'Thêm chỉ số',
                      icon: Icons.add,
                      onPressed: _openQuickAdd,
                    ),
                  )
                else
                  for (var index = 0; index < entries.length; index++)
                    _timelineEntry(
                      entries[index],
                      isLast: index == entries.length - 1,
                    ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MainNavigationWrapper(
        selectedIndex: 1,
        onSelected: (index) {
          if (index == 0) Navigator.pop(context);
        },
        onQuickAdd: _openQuickAdd,
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Flexible(
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: _ink,
      backgroundColor: AppColors.surface,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(AppSpacing.x3),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  Widget _timelineEntry(_JournalEntry entry, {required bool isLast}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.x3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: AppSpacing.x6),
                decoration: BoxDecoration(
                  color: _teal,
                  border: Border.all(color: AppColors.surface, width: 2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _timeLabel(entry.measuredAt),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        entry.device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (entry.heartRate != null)
                      _measureChip(
                        Icons.favorite_rounded,
                        'Nhịp tim',
                        '${entry.heartRate} bpm',
                        AppColors.danger,
                      ),
                    if (entry.steps != null)
                      _measureChip(
                        Icons.directions_walk_rounded,
                        'Bước đi',
                        '${entry.steps} bước',
                        AppColors.primary,
                      ),
                    if (entry.calories != null)
                      _measureChip(
                        Icons.local_fire_department_rounded,
                        'Năng lượng',
                        '${entry.calories!.toStringAsFixed(0)} kcal',
                        AppColors.warning,
                      ),
                  ],
                ),
                if (entry.activityState != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    entry.activityState == 'active'
                        ? 'Đang vận động'
                        : 'Trạng thái nghỉ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (entry.detail != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    entry.detail!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _measureChip(IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              '$label · $value',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      );
}

class _JournalEntry {
  const _JournalEntry({
    required this.measuredAt,
    required this.heartRate,
    required this.steps,
    required this.calories,
    required this.device,
    required this.activityState,
    this.detail,
  });

  final DateTime measuredAt;
  final int? heartRate;
  final int? steps;
  final double? calories;
  final String device;
  final String? activityState;
  final String? detail;
}
