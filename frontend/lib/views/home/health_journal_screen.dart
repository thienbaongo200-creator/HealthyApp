import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
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
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);

  late DateTime _selectedDate;
  late String _selectedMember;
  String? _profileId;
  List<Map<String, dynamic>> _profiles = [];
  String _selectedType = 'ALL';
  bool _isLoading = true;
  String? _error;
  int _loadRequestId = 0;
  List<Map<String, dynamic>> _measurements = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedMember = widget.initialMember;
    _profileId = widget.initialProfileId;
    _loadMeasurements();
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
      final measuredAt = DateTime.tryParse(record['measured_at']?.toString() ?? '')
          ?.toLocal();
      if (measuredAt == null ||
          measuredAt.year != _selectedDate.year ||
          measuredAt.month != _selectedDate.month ||
          measuredAt.day != _selectedDate.day) {
        continue;
      }
      final type = record['measurement_type']?.toString();
      if (_selectedType != 'ALL' && type != _selectedType) continue;
      num? number(dynamic raw) => raw is num ? raw : num.tryParse(raw?.toString() ?? '');
      final value = number(record['value']);
      final heartRate = number(record['heart_rate'] ?? (type == 'HEART_RATE' ? value : null))?.toInt();
      final steps = number(record['steps'] ?? (type == 'STEPS' ? value : null))?.toInt();
      final calories = number(record['calories'] ?? (type == 'CALORIES' ? value : null))?.toDouble();
      final detail = switch (type) {
        'HEART_RATE' => 'Nhịp tim ${value?.toStringAsFixed(0) ?? '—'} bpm',
        'BLOOD_PRESSURE' => 'Huyết áp ${value?.toStringAsFixed(0) ?? '—'}/${number(record['value_secondary'])?.toStringAsFixed(0) ?? '—'} mmHg',
        'BLOOD_GLUCOSE' => 'Đường huyết ${value ?? '—'} ${record['unit'] ?? ''}',
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
      entries.add(_JournalEntry(
        measuredAt: measuredAt,
        heartRate: heartRate,
        steps: steps,
        calories: calories,
        device: record['device_id']?.toString() ?? 'Thiết bị sức khỏe',
        activityState: record['activity_state']?.toString(),
        detail: detail,
      ));
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
    if (_profiles.isEmpty) {
      try {
        _profiles = await ApiService.fetchProfiles();
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
                title: Text(
                  profile['profile_type'] == 'SELF'
                      ? 'Tôi'
                      : profile['full_name']?.toString() ?? 'Thành viên',
                ),
                trailing: profile['id']?.toString() == _profileId
                    ? const Icon(Icons.check, color: _teal)
                    : null,
                onTap: () => Navigator.pop(
                  sheetContext,
                  profile['id']?.toString(),
                ),
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
      setState(() {
        _profileId = profileId;
        _selectedMember = profile['profile_type'] == 'SELF'
            ? 'Tôi'
            : profile['full_name']?.toString() ?? 'Thành viên';
      });
      await _loadMeasurements();
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _openQuickAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(
          member: _selectedMember,
          profileId: _profileId,
        ),
      ),
    );
    if (saved == true && mounted) await _loadMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Nhật ký sức khỏe',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: _filterButton(
                        icon: Icons.person_outline,
                        label: _selectedMember,
                        onTap: _chooseMember,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Lọc theo loại chỉ số',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .82),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Tất cả chỉ số')),
                    DropdownMenuItem(value: 'HEART_RATE', child: Text('Nhịp tim')),
                    DropdownMenuItem(value: 'BLOOD_PRESSURE', child: Text('Huyết áp')),
                    DropdownMenuItem(value: 'BLOOD_GLUCOSE', child: Text('Đường huyết')),
                    DropdownMenuItem(value: 'SLEEP', child: Text('Giấc ngủ')),
                    DropdownMenuItem(value: 'WEIGHT', child: Text('Cân nặng')),
                    DropdownMenuItem(value: 'HEIGHT', child: Text('Chiều cao')),
                    DropdownMenuItem(value: 'TEMPERATURE', child: Text('Thân nhiệt')),
                    DropdownMenuItem(value: 'STEPS', child: Text('Bước đi')),
                    DropdownMenuItem(value: 'CALORIES', child: Text('Năng lượng')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(14),
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
                          style: const TextStyle(
                            color: Color(0xFF687875),
                            height: 1.4,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Các mốc đo trong ngày',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entries.length} mốc',
                      style: const TextStyle(
                        color: Color(0xFF82908D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: _teal),
                    ),
                  )
                else if (_error != null)
                  _stateCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Chưa tải được nhật ký',
                    message: _error!,
                    action: TextButton.icon(
                      onPressed: _loadMeasurements,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  )
                else if (entries.isEmpty)
                  _stateCard(
                    icon: Icons.event_note_outlined,
                    title: 'Chưa có bản ghi trong ngày này',
                    message: _selectedMember == 'Tôi'
                        ? 'Khi đồng hồ gửi dữ liệu, các mốc đo sẽ xuất hiện ở đây.'
                        : 'Chưa có dữ liệu riêng cho thành viên này.',
                  )
                else
                  for (var index = 0; index < entries.length; index++)
                    _timelineEntry(entries[index], isLast: index == entries.length - 1),
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
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          backgroundColor: Colors.white.withValues(alpha: .78),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: const BorderSide(color: Color(0xFFE0EBE8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _timelineEntry(_JournalEntry entry, {required bool isLast}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
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
                    margin: const EdgeInsets.only(top: 22),
                    decoration: BoxDecoration(
                      color: _teal,
                      border: Border.all(color: Colors.white, width: 2),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Color(0x33168B83), blurRadius: 5),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: const Color(0xFFB8DAD5),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _timeLabel(entry.measuredAt),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            entry.device,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Color(0xFF82908D),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (entry.heartRate != null)
                          _measureChip(
                            Icons.favorite_rounded,
                            'Nhịp tim',
                            '${entry.heartRate} bpm',
                            const Color(0xFFE16E77),
                          ),
                        if (entry.steps != null)
                          _measureChip(
                            Icons.directions_walk_rounded,
                            'Bước đi',
                            '${entry.steps} bước',
                            const Color(0xFF438ED8),
                          ),
                        if (entry.calories != null)
                          _measureChip(
                            Icons.local_fire_department_rounded,
                            'Năng lượng',
                            '${entry.calories!.toStringAsFixed(0)} kcal',
                            const Color(0xFFE39A47),
                          ),
                      ],
                    ),
                    if (entry.activityState != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.activityState == 'active'
                            ? 'Đang vận động'
                            : 'Trạng thái nghỉ',
                        style: const TextStyle(
                          color: Color(0xFF687875),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (entry.detail != null) ...[
                      const SizedBox(height: 9),
                      Text(entry.detail!, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              style: TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) =>
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF82908D)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF82908D),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
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
