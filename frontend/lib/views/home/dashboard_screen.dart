import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mock_health_data_service.dart';
import 'package:frontend/services/watch_service.dart';
import 'package:frontend/widgets/widgets.dart';

import 'devices_screen.dart';
import 'family_members_screen.dart';
import 'health_journal_screen.dart';
import 'ai_assistant_screen.dart';
import 'quick_add_screen.dart';
import 'health_trends_screen.dart';
import 'main_navigation_wrapper.dart';
import 'medical_records_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _ink = Color(0xFF18343A);
  static const _teal = Color(0xFF168B83);
  static const _canvas = Color(0xFFF5F9F8);

  int _heartRate = 0;
  int _steps = 0;
  double _calories = 0;
  String _bloodPressure = '—';
  double? _glucose;
  double? _weight;
  double? _height;
  double? _sleepHours;
  bool _isRefreshing = false;
  bool _wearConnected = false;
  int _selectedTab = 0;
  String _member = 'Tôi';
  String? _profileId;
  List<Map<String, dynamic>> _profiles = [];
  final List<int> _heartRateHistory = [];
  final List<Map<String, dynamic>> _pendingMeasurements = [];
  late final StreamSubscription<Map<String, dynamic>> _wearSubscription;
  Timer? _batchFlushTimer;
  bool _isFlushingBatch = false;

  @override
  void initState() {
    super.initState();
    _batchFlushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_flushMeasurements()),
    );
    _wearSubscription = WatchService().wearDataStream.listen(
      (data) {
        if (!mounted) return;
        final heartRate =
            (data['heart_rate'] as num?)?.toInt() ??
            (data['heartRate'] as num?)?.toInt();
        final steps = (data['steps'] as num?)?.toInt();
        final calories = (data['calories'] as num?)?.toDouble();
        if (heartRate == null || steps == null || calories == null) {
          debugPrint('[Phone] Message Wear không đủ dữ liệu: $data');
          return;
        }

        setState(() {
          _wearConnected = true;
          _heartRate = heartRate;
          _steps = steps;
          _calories = calories;
          _heartRateHistory.add(heartRate);
          if (_heartRateHistory.length > 12) _heartRateHistory.removeAt(0);
        });

        final measuredAt =
            DateTime.tryParse(
              (data['measured_at'] ?? data['timestamp'])?.toString() ?? '',
            ) ??
            DateTime.now().toUtc();
        final measuredAtIso = measuredAt.toUtc().toIso8601String();
        final intervalSeconds =
            (data['interval_seconds'] as num?)?.toInt() ??
            (data['activity_state'] == 'active' ? 5 : 60);
        final endTime = measuredAt.toUtc();
        final startTime = endTime.subtract(
          Duration(seconds: intervalSeconds.clamp(1, 3600).toInt()),
        );
        final startTimeIso = startTime.toIso8601String();
        final sampleKey =
            data['idempotency_key']?.toString() ?? createIdempotencyKey();
        _pendingMeasurements.addAll([
          {
            'measurement_type': 'HEART_RATE',
            'value': heartRate,
            'unit': 'bpm',
            'source': 'WEAR_OS',
            'measured_at': measuredAtIso,
            'idempotency_key': '${sampleKey}_heart_rate',
          },
          {
            'measurement_type': 'STEPS',
            'value': steps,
            'unit': 'steps',
            'start_time': startTimeIso,
            'end_time': measuredAtIso,
            'source': 'WEAR_OS',
            'measured_at': measuredAtIso,
            'idempotency_key': '${sampleKey}_steps',
          },
          {
            'measurement_type': 'CALORIES',
            'value': calories,
            'unit': 'kcal',
            'start_time': startTimeIso,
            'end_time': measuredAtIso,
            'source': 'WEAR_OS',
            'measured_at': measuredAtIso,
            'idempotency_key': '${sampleKey}_calories',
          },
        ]);
        if (_pendingMeasurements.length >= 10) unawaited(_flushMeasurements());
      },
      onError: (Object error) {
        debugPrint('[Phone] Lỗi khi nhận dữ liệu từ Wear: $error');
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWatchListener();
      _loadProfilesAndRefresh();
    });
  }

  Future<void> _loadProfilesAndRefresh() async {
    try {
      final profiles = await ApiService.fetchProfiles();
      final selfProfile = profiles
          .where((profile) => profile['profile_type'] == 'SELF')
          .firstOrNull;
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _profileId = selfProfile?['id']?.toString();
        });
      }
    } catch (error) {
      if (mounted) _showMessage('Không thể tải hồ sơ thành viên: $error');
    }
    await _refreshData();
  }

  Future<void> _initWatchListener() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await WatchService().initPhoneListener(port: 8080);
    } catch (error, stackTrace) {
      debugPrint(
        '[Phone] Không thể khởi tạo Watch listener: $error\n$stackTrace',
      );
    }
  }

  Future<void> _flushMeasurements() async {
    if (_isFlushingBatch || _pendingMeasurements.isEmpty) return;
    _isFlushingBatch = true;
    try {
      while (_pendingMeasurements.isNotEmpty) {
        final batch = _pendingMeasurements.take(100).toList(growable: false);
        final result = await ApiService.sendHealthMeasurements(
          batch,
          profileId: _profileId,
        );
        if (result == null) return;

        final terminalKeys = {
          ...result.acknowledgedKeys,
          ...result.rejectedKeys,
        };
        if (terminalKeys.isNotEmpty) {
          _pendingMeasurements.removeWhere(
            (measurement) => terminalKeys.contains(
              measurement['idempotency_key']?.toString(),
            ),
          );
        }

        // Retryable records stay queued until the next connectivity/timer event.
        if (result.retryKeys.isNotEmpty || terminalKeys.isEmpty) return;
      }
    } finally {
      _isFlushingBatch = false;
    }
  }

  @override
  void dispose() {
    _batchFlushTimer?.cancel();
    _wearSubscription.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final records = await ApiService.fetchHealthMeasurements(
        profileId: _profileId,
      );
      if (!mounted) return;
      Map<String, dynamic>? latest(String type) {
        final record = records
            .where((r) => r['measurement_type'] == type)
            .firstOrNull;
        return record;
      }

      num? numeric(dynamic value) =>
          value is num ? value : num.tryParse(value?.toString() ?? '');
      final heartRate = numeric(latest('HEART_RATE')?['value'])?.toInt();
      final bloodPressure = latest('BLOOD_PRESSURE');
      final glucose = numeric(latest('BLOOD_GLUCOSE')?['value'])?.toDouble();
      final weight = numeric(latest('WEIGHT')?['value'])?.toDouble();
      final height = numeric(latest('HEIGHT')?['value'])?.toDouble();
      final sleep = latest('SLEEP');
      final steps = numeric(latest('STEPS')?['value'])?.toInt();
      final calories = numeric(latest('CALORIES')?['value'])?.toDouble();
      setState(() {
        if (heartRate != null) _heartRate = heartRate;
        if (steps != null) _steps = steps;
        if (calories != null) _calories = calories;
        if (bloodPressure != null) {
          final systolic = numeric(bloodPressure['value']);
          final diastolic = numeric(bloodPressure['value_secondary']);
          if (systolic != null && diastolic != null) {
            _bloodPressure =
                '${systolic.toStringAsFixed(0)}/${diastolic.toStringAsFixed(0)}';
          }
        }
        if (glucose != null) _glucose = glucose;
        if (weight != null) _weight = weight;
        if (height != null) _height = height;
        if (sleep != null) _sleepHours = numeric(sleep['value'])?.toDouble();
        if (heartRate != null &&
            (_heartRateHistory.isEmpty ||
                _heartRateHistory.last != heartRate)) {
          _heartRateHistory.add(heartRate);
          if (_heartRateHistory.length > 12) _heartRateHistory.removeAt(0);
        }
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException
              ? error.message
              : 'Không thể tải dữ liệu sức khỏe.',
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _openQuickAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(member: _member, profileId: _profileId),
      ),
    );
    if (saved == true && mounted) {
      await _refreshData();
      if (mounted) _showMessage('Đã lưu và cập nhật chỉ số sức khỏe.');
    }
  }

  Future<void> _openTrends() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            HealthTrendsScreen(member: _member, profileId: _profileId),
      ),
    );
  }

  Future<void> _selectMember() async {
    if (_profiles.isEmpty) {
      try {
        _profiles = await ApiService.fetchProfiles();
      } catch (error) {
        if (mounted) _showMessage('Không thể tải hồ sơ thành viên: $error');
        return;
      }
    }
    if (!mounted) return;
    final member = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn hồ sơ đang xem')),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4F1),
                child: Icon(Icons.groups_outlined, color: _teal),
              ),
              title: const Text('Quản lý thành viên gia đình'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, '__manage_members__'),
            ),
            const Divider(height: 1),
            for (final profile in _profiles)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE6F4F1),
                  child: Icon(
                    profile['profile_type'] == 'SELF'
                        ? Icons.person
                        : Icons.family_restroom,
                    color: _teal,
                  ),
                ),
                title: Text(
                  profile['profile_type'] == 'SELF'
                      ? 'Tôi'
                      : profile['full_name']?.toString() ?? 'Thành viên',
                ),
                trailing: profile['id']?.toString() == _profileId
                    ? const Icon(Icons.check, color: _teal)
                    : null,
                onTap: () => Navigator.pop(context, profile['id']?.toString()),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (member == '__manage_members__' && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const FamilyMembersScreen()),
      );
      return;
    }
    if (member != null && mounted) {
      final profile = _profiles
          .where((item) => item['id']?.toString() == member)
          .firstOrNull;
      if (profile == null) return;
      setState(() {
        _profileId = member;
        _member = profile['profile_type'] == 'SELF'
            ? 'Tôi'
            : profile['full_name']?.toString() ?? 'Thành viên';
      });
      await _refreshData();
    }
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return GlassCard(
      padding: padding,
      borderRadius: 20,
      blur: 10,
      backgroundColor: Colors.white.withValues(alpha: .46),
      borderColor: Colors.white.withValues(alpha: .62),
      borderWidth: .5,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SkyBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: _teal,
            onRefresh: _refreshData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào mừng bạn!',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cùng chăm sóc sức khỏe mỗi ngày',
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _ink,
                        side: const BorderSide(color: Color(0xFFE7EFED)),
                      ),
                      tooltip: 'Cài đặt',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _selectMember,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE7EFED)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: _teal,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Đang xem: $_member',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: _ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    _connectionPill(),
                  ],
                ),
                const SizedBox(height: 23),
                _sectionTitle('Trạng thái sức khỏe', 'Cập nhật gần đây'),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFE66B71),
                              label: 'Nhịp tim',
                              value: _heartRate > 0 ? '$_heartRate' : '—',
                              unit: 'bpm',
                            ),
                          ),
                          _metricDivider(),
                          Expanded(
                            child: _metric(
                              icon: Icons.bedtime_rounded,
                              color: const Color(0xFF8B83D7),
                              label: 'Giấc ngủ',
                              value: _sleepHours == null
                                  ? '—'
                                  : _sleepHours!.toStringAsFixed(1),
                              unit: 'giờ',
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Divider(height: 1, color: Color(0xFFEDF1F0)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.monitor_heart_rounded,
                              color: const Color(0xFF28A99A),
                              label: 'Huyết áp',
                              value: _bloodPressure,
                              unit: _bloodPressure == '—' ? 'mmHg' : 'mmHg',
                            ),
                          ),
                          _metricDivider(),
                          Expanded(
                            child: _metric(
                              icon: Icons.water_drop_rounded,
                              color: const Color(0xFF52A8D5),
                              label: 'Đường huyết',
                              value: _glucose == null
                                  ? '—'
                                  : _glucose!.toStringAsFixed(1),
                              unit: 'mg/dL',
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Divider(height: 1, color: Color(0xFFEDF1F0)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.monitor_weight_outlined,
                              color: const Color(0xFF438ED8),
                              label: 'Cân nặng',
                              value: _weight == null
                                  ? '—'
                                  : _weight!.toStringAsFixed(1),
                              unit: 'kg',
                            ),
                          ),
                          _metricDivider(),
                          Expanded(
                            child: _metric(
                              icon: Icons.height_rounded,
                              color: const Color(0xFF7D9B68),
                              label: 'Chiều cao',
                              value: _height == null
                                  ? '—'
                                  : _height!.toStringAsFixed(1),
                              unit: 'cm',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                _sectionTitle('Hoạt động hôm nay', 'Từ các bản ghi gần nhất'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _activityCard(
                        Icons.directions_walk_rounded,
                        'Bước đi',
                        _steps > 0 ? _steps.toString() : '—',
                        'bước',
                        const Color(0xFF438ED8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _activityCard(
                        Icons.local_fire_department_rounded,
                        'Calo',
                        _calories > 0 ? _calories.toStringAsFixed(0) : '—',
                        'kcal',
                        const Color(0xFFE39A47),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const MedicalRecordsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Hồ sơ y tế & đơn thuốc'),
                ),
                const SizedBox(height: 23),
                _sectionTitle('Xu hướng sức khỏe', 'Trong ngày'),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _heartRate > 0 ? '$_heartRate' : '—',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 5, bottom: 5),
                            child: Text(
                              'bpm hiện tại',
                              style: TextStyle(
                                color: Color(0xFF83918F),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _heartRateHistory.length >= 2
                                ? 'Dữ liệu từ đồng hồ'
                                : 'Chưa có đủ dữ liệu',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF83918F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 116,
                        width: double.infinity,
                        child: _heartRateHistory.length < 2
                            ? _emptyChart()
                            : _HeartRateChart(
                                values: List.of(_heartRateHistory),
                              ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openTrends,
                    icon: const Icon(Icons.insights_outlined, size: 17),
                    label: const Text('Chi tiết thống kê'),
                    style: TextButton.styleFrom(foregroundColor: _teal),
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6F3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: _teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Một chút nhắc nhở',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Đeo đồng hồ để cập nhật chỉ số hoạt động.',
                              style: TextStyle(
                                color: Color(0xFF83918F),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MainNavigationWrapper(
        selectedIndex: _selectedTab,
        onSelected: _selectNavigationTab,
        onQuickAdd: _openQuickAdd,
      ),
    );
  }

  Widget _connectionPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: _wearConnected ? const Color(0xFFE8F5EF) : const Color(0xFFF1F4F3),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 7,
          color: _wearConnected
              ? const Color(0xFF35A77B)
              : const Color(0xFF9AA7A4),
        ),
        const SizedBox(width: 6),
        Text(
          _wearConnected ? 'Đã kết nối' : 'Chưa kết nối',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _wearConnected
                ? const Color(0xFF318461)
                : const Color(0xFF7D8987),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String trailing) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          color: _ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Text(
        trailing,
        style: const TextStyle(fontSize: 11, color: Color(0xFF899592)),
      ),
    ],
  );

  Widget _metric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF83918F), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF83918F),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _metricDivider() => Container(
    width: 1,
    height: 46,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: const Color(0xFFEDF1F0),
  );

  Widget _activityCard(
    IconData icon,
    String label,
    String value,
    String unit,
    Color color,
  ) => _card(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 11),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$label · $unit',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF83918F), fontSize: 10),
        ),
      ],
    ),
  );

  Widget _emptyChart() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.show_chart_rounded,
          size: 27,
          color: _teal.withValues(alpha: .55),
        ),
        const SizedBox(height: 3),
        const Text(
          'Biểu đồ sẽ xuất hiện khi có dữ liệu đo',
          style: TextStyle(color: Color(0xFF83918F), fontSize: 11),
        ),
      ],
    ),
  );

  Future<void> _selectNavigationTab(int index) async {
    if (index == 0) return;
    setState(() => _selectedTab = index);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => switch (index) {
          1 => HealthJournalScreen(
            initialMember: _member,
            initialProfileId: _profileId,
          ),
          2 => AiAssistantScreen(
            initialMember: _member,
            initialProfileId: _profileId,
          ),
          _ => DevicesScreen(
            isWatchConnected: _wearConnected,
            pendingMeasurements: _pendingMeasurements.length,
            onSync: _flushMeasurements,
          ),
        },
      ),
    );
    if (mounted) setState(() => _selectedTab = 0);
  }
}

class _HeartRateChart extends StatelessWidget {
  const _HeartRateChart({required this.values});
  final List<int> values;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeartRatePainter(values),
    child: const SizedBox.expand(),
  );
}

class _HeartRatePainter extends CustomPainter {
  const _HeartRatePainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final grid = Paint()
      ..color = const Color(0xFFEDF1F0)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minPoint = values.reduce((a, b) => a < b ? a : b);
    final maxPoint = values.reduce((a, b) => a > b ? a : b);
    final minValue = math.max(35, minPoint - 12).toDouble();
    final maxValue = math.max(minValue + 1, maxPoint + 12).toDouble();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height -
          (values[i] - minValue) / (maxValue - minValue) * size.height;
      points.add(Offset(x, y));
    }
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      line.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4439A99C), Color(0x0039A99C)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF168B83)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = const Color(0xFF168B83);
    canvas.drawCircle(points.last, 4, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 3, dot);
  }

  @override
  bool shouldRepaint(covariant _HeartRatePainter oldDelegate) =>
      oldDelegate.values != values;
}
