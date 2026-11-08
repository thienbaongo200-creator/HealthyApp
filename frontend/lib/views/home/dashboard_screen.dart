import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mock_health_data_service.dart';
import 'package:frontend/services/watch_service.dart';
import 'package:frontend/services/wear_offline_queue.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  String _bloodPressure = '—';
  double? _glucose;
  double? _weight;
  double? _height;
  double? _sleepHours;
  bool _wearConnected = false;
  int _selectedTab = 0;
  String _member = 'Tôi';
  Map<String, dynamic>? _latestAIInsight;
  final List<int> _heartRateHistory = [];
  final WearOfflineQueue _wearQueue = WearOfflineQueue.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  int _pendingMeasurementCount = 0;
  late final StreamSubscription<Map<String, dynamic>> _wearSubscription;
  Timer? _batchFlushTimer;
  bool _isFlushingBatch = false;
  ProfileSelectionController? _profileSelection;
  String? _observedProfileId;
  int _measurementRequestId = 0;

  String? get _profileId => _profileSelection?.selectedProfileId;

  List<Map<String, dynamic>> get _profiles =>
      _profileSelection?.profiles ?? const [];

  Map<String, dynamic>? get _selectedProfile => _profiles
      .where((profile) => profile['id']?.toString() == _profileId)
      .firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = ProfileSelectionScope.of(context);
    if (identical(selection, _profileSelection)) return;
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    _profileSelection = selection;
    _observedProfileId = selection.selectedProfileId;
    selection.addListener(_onProfileSelectionChanged);
  }

  void _onProfileSelectionChanged() {
    if (!mounted) return;
    final profileId = _profileId;
    if (profileId == _observedProfileId) {
      setState(() {});
      return;
    }

    _observedProfileId = profileId;
    final profile = _selectedProfile;
    setState(() {
      _member = profile == null ? 'Tôi' : profileDisplayName(profile);
      _heartRate = 0;
      _bloodPressure = '—';
      _glucose = null;
      _weight = null;
      _height = null;
      _sleepHours = null;
      _heartRateHistory.clear();
      _latestAIInsight = null;
    });
    if (profileId != null) {
      unawaited(_loadLatestAIInsight());
      unawaited(_refreshData());
    }
  }

  String? get _profileSummary {
    final profile = _selectedProfile;
    return profile == null ? null : profileDemographicSubtitle(profile);
  }

  double? get _bmi {
    final height = _height;
    final weight = _weight;
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      return null;
    }
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

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
          _heartRateHistory.add(heartRate);
          if (_heartRateHistory.length > 12) _heartRateHistory.removeAt(0);
        });
      },
      onError: (Object error) {
        debugPrint('[Phone] Lỗi khi nhận dữ liệu từ Wear: $error');
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadProfilesAndRefresh().whenComplete(_initWatchListener));
      _refreshPendingCount();
    });
  }

  Future<void> _loadProfilesAndRefresh() async {
    try {
      final profiles = await ApiService.fetchProfiles();
      if (!mounted) return;
      final previousProfileId = _profileId;
      _profileSelection!.setProfiles(profiles);
      if (previousProfileId == _profileId) {
        await _loadLatestAIInsight();
        await _refreshData();
      }
    } catch (error) {
      if (mounted) _showMessage('Không thể tải hồ sơ thành viên: $error');
    }
    unawaited(_flushMeasurements());
  }

  Future<void> _loadLatestAIInsight() async {
    final profileId = _profileId;
    if (profileId == null) return;
    try {
      final insights = await ApiService.fetchAIInsights(profileId: profileId);
      if (!mounted || profileId != _profileId) return;
      setState(() => _latestAIInsight = insights.firstOrNull);
    } catch (error) {
      debugPrint('[Dashboard] Unable to load latest AI insight: $error');
      if (mounted && profileId == _profileId) {
        setState(() => _latestAIInsight = null);
      }
    }
  }

  Future<void> _enqueueWearSnapshot(
    String profileId,
    String deviceId,
    String sampleKey,
    int heartRate,
    int steps,
    double calories,
    String measuredAt,
    String startTime,
  ) async {
    for (final measurement in <Map<String, dynamic>>[
      {
        'measurement_type': 'HEART_RATE',
        'value': heartRate,
        'unit': 'bpm',
        'measured_at': measuredAt,
        'idempotency_key': '${sampleKey}_heart_rate',
        'device_id': deviceId,
      },
      {
        'measurement_type': 'STEPS',
        'value': steps,
        'unit': 'steps',
        'start_time': startTime,
        'end_time': measuredAt,
        'measured_at': measuredAt,
        'idempotency_key': '${sampleKey}_steps',
        'device_id': deviceId,
      },
      {
        'measurement_type': 'CALORIES',
        'value': calories,
        'unit': 'kcal',
        'start_time': startTime,
        'end_time': measuredAt,
        'measured_at': measuredAt,
        'idempotency_key': '${sampleKey}_calories',
        'device_id': deviceId,
      },
    ]) {
      await _wearQueue.enqueue(profileId, measurement);
    }
    await _refreshPendingCount();
    if (_pendingMeasurementCount >= 10) unawaited(_flushMeasurements());
  }

  Future<void> _persistWearData(Map<String, dynamic> data) async {
    final heartRate =
        (data['heart_rate'] as num?)?.toInt() ??
        (data['heartRate'] as num?)?.toInt();
    final steps = (data['steps'] as num?)?.toInt();
    final calories = (data['calories'] as num?)?.toDouble();
    if (heartRate == null || steps == null || calories == null) {
      throw const FormatException(
        'Wear payload is missing required measurements.',
      );
    }
    final identifier = data['device_identifier']?.toString().trim() ?? '';
    if (identifier.isEmpty) {
      throw const FormatException(
        'Wear payload must include its paired device identifier.',
      );
    }
    final accessibleProfileIds = _profiles
        .map((profile) => profile['id']?.toString())
        .whereType<String>()
        .toSet();
    final storedDevices = await _secureStorage.readAll();
    const identifierPrefix = 'paired_device_identifier_';
    final matches = <({String profileId, String deviceId})>[];
    for (final entry in storedDevices.entries.where((entry) {
      if (!entry.key.startsWith(identifierPrefix) ||
          entry.value != identifier) {
        return false;
      }
      final profileId = entry.key.substring(identifierPrefix.length);
      return accessibleProfileIds.contains(profileId);
    })) {
      final profileId = entry.key.substring(identifierPrefix.length);
      final deviceId = storedDevices['paired_device_$profileId'];
      if (deviceId != null && deviceId.isNotEmpty) {
        matches.add((profileId: profileId, deviceId: deviceId));
      }
    }
    if (matches.isEmpty) {
      for (final profileId in accessibleProfileIds) {
        final devices = await ApiService.fetchDevices(profileId: profileId);
        for (final device in devices) {
          if (device['device_identifier']?.toString() != identifier ||
              device['status'] != 'ACTIVE') {
            continue;
          }
          final deviceId = device['id']?.toString();
          if (deviceId != null && deviceId.isNotEmpty) {
            matches.add((profileId: profileId, deviceId: deviceId));
          }
        }
      }
    }
    if (matches.length != 1) {
      throw StateError(
        'Wear device must map to exactly one accessible profile.',
      );
    }
    final owner = matches.single;
    await _secureStorage.write(
      key: 'paired_device_${owner.profileId}',
      value: owner.deviceId,
    );
    await _secureStorage.write(
      key: 'paired_device_identifier_${owner.profileId}',
      value: identifier,
    );
    final measuredAt =
        DateTime.tryParse(
          (data['measured_at'] ?? data['timestamp'])?.toString() ?? '',
        ) ??
        DateTime.now().toUtc();
    final endTime = measuredAt.toUtc();
    final intervalSeconds = (data['interval_seconds'] as num?)?.toInt() ?? 60;
    final startTime = endTime.subtract(
      Duration(seconds: intervalSeconds.clamp(1, 3600).toInt()),
    );
    await _enqueueWearSnapshot(
      owner.profileId,
      owner.deviceId,
      data['idempotency_key']?.toString() ?? createIdempotencyKey(),
      heartRate,
      steps,
      calories,
      endTime.toIso8601String(),
      startTime.toIso8601String(),
    );
  }

  Future<void> _refreshPendingCount() async {
    final count = await _wearQueue.pendingCount();
    if (mounted) setState(() => _pendingMeasurementCount = count);
  }

  Future<void> _initWatchListener() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await WatchService().initPhoneListener(
        port: 8080,
        persistBeforeAcknowledgement: _persistWearData,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Phone] Không thể khởi tạo Watch listener: $error\n$stackTrace',
      );
    }
  }

  Future<void> _flushMeasurements() async {
    if (_isFlushingBatch) return;
    _isFlushingBatch = true;
    try {
      while (true) {
        final ready = await _wearQueue.ready(limit: 100);
        if (ready.isEmpty) break;
        final firstValid = ready.where((item) {
          final deviceId = item.measurement['device_id']?.toString() ?? '';
          return deviceId.isNotEmpty;
        }).firstOrNull;
        if (firstValid == null) {
          for (final item in ready) {
            await _wearQueue.markFailed(
              item.key,
              'No paired device was recorded with this sample.',
            );
          }
          break;
        }
        final selectedProfileId = firstValid.profileId;
        final batch = ready
            .where(
              (item) =>
                  item.profileId == selectedProfileId &&
                  (item.measurement['device_id']?.toString().isNotEmpty ??
                      false),
            )
            .toList();
        final payloads = batch.map((item) => item.measurement).toList();
        await _wearQueue.markSending(batch);
        final result = await ApiService.sendHealthMeasurements(
          payloads,
          profileId: selectedProfileId,
        );
        if (result == null) {
          for (final item in batch) {
            await _wearQueue.scheduleRetry(item, 'Network or server error');
          }
          break;
        }
        for (final item in batch) {
          if (result.acknowledgedKeys.contains(item.key)) {
            await _wearQueue.markSynced(item.key);
          } else if (result.rejectedKeys.contains(item.key)) {
            await _wearQueue.markFailed(
              item.key,
              'Rejected by server validation',
            );
          } else {
            await _wearQueue.scheduleRetry(item, 'Server requested retry');
          }
        }
      }
    } finally {
      _isFlushingBatch = false;
      await _refreshPendingCount();
    }
  }

  @override
  void dispose() {
    _profileSelection?.removeListener(_onProfileSelectionChanged);
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
    final requestId = ++_measurementRequestId;
    final requestProfileId = _profileId;
    if (requestProfileId == null) {
      if (mounted) {
        setState(() {
          _heartRate = 0;
          _bloodPressure = '—';
          _glucose = null;
          _weight = null;
          _height = null;
          _sleepHours = null;
          _heartRateHistory.clear();
        });
      }
      return;
    }
    try {
      final records = await ApiService.fetchHealthMeasurements(
        profileId: requestProfileId,
      );
      if (!mounted ||
          requestId != _measurementRequestId ||
          requestProfileId != _profileId) {
        return;
      }
      Map<String, dynamic>? latest(String type) {
        final record = records
            .where((r) => r['measurement_type'] == type)
            .firstOrNull;
        return record;
      }

      Map<String, dynamic>? latestByMeasuredAt(String type) {
        Map<String, dynamic>? result;
        DateTime? latestAt;
        for (final record in records) {
          if (record['measurement_type'] != type) continue;
          final measuredAt = DateTime.tryParse(
            record['measured_at']?.toString() ?? '',
          );
          if (result == null ||
              (measuredAt != null &&
                  (latestAt == null || measuredAt.isAfter(latestAt)))) {
            result = record;
            latestAt = measuredAt;
          }
        }
        return result;
      }

      num? numeric(dynamic value) =>
          value is num ? value : num.tryParse(value?.toString() ?? '');
      final heartRate = numeric(latest('HEART_RATE')?['value'])?.toInt();
      final bloodPressure = latest('BLOOD_PRESSURE');
      final glucose = numeric(latest('BLOOD_GLUCOSE')?['value'])?.toDouble();
      final profile = _selectedProfile;
      final weight =
          numeric(latestByMeasuredAt('WEIGHT')?['value'])?.toDouble() ??
          numeric(profile?['weight_kg'])?.toDouble();
      final height =
          numeric(latestByMeasuredAt('HEIGHT')?['value'])?.toDouble() ??
          numeric(profile?['height_cm'])?.toDouble();
      final sleep = latest('SLEEP');
      setState(() {
        if (heartRate != null) _heartRate = heartRate;
        if (bloodPressure != null) {
          final systolic = numeric(bloodPressure['value']);
          final diastolic = numeric(bloodPressure['value_secondary']);
          if (systolic != null && diastolic != null) {
            _bloodPressure =
                '${systolic.toStringAsFixed(0)}/${diastolic.toStringAsFixed(0)}';
          }
        }
        if (glucose != null) _glucose = glucose;
        _weight = weight;
        _height = height;
        if (sleep != null) _sleepHours = numeric(sleep['value'])?.toDouble();
        if (heartRate != null &&
            (_heartRateHistory.isEmpty ||
                _heartRateHistory.last != heartRate)) {
          _heartRateHistory.add(heartRate);
          if (_heartRateHistory.length > 12) _heartRateHistory.removeAt(0);
        }
      });
    } catch (error) {
      if (mounted &&
          requestId == _measurementRequestId &&
          requestProfileId == _profileId) {
        _showMessage(
          error is ApiException
              ? error.message
              : 'Không thể tải dữ liệu sức khỏe.',
        );
      }
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
        _profileSelection!.setProfiles(await ApiService.fetchProfiles());
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
                title: Text(profileDisplayName(profile)),
                subtitle: Text(profileDemographicSubtitle(profile)),
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
      _profileSelection!.selectProfileId(member);
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
                if (_profileSummary case final summary?) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFF83918F),
                      fontSize: 12,
                    ),
                  ),
                ],
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Divider(height: 1, color: Color(0xFFEDF1F0)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.calculate_outlined,
                              color: const Color(0xFF9A7BC1),
                              label: 'BMI',
                              value: _bmi?.toStringAsFixed(1) ?? '—',
                              unit: 'kg/m²',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _selectNavigationTab(2),
                  child: _card(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6F3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_outlined,
                            color: _teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Nhận định sức khỏe gần nhất',
                                      style: TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_latestAIInsight?['risk_level'] is String)
                                    Text(
                                      _latestAIInsight!['risk_level'] as String,
                                      style: const TextStyle(
                                        color: _teal,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _latestAIInsight?['summary']?.toString() ??
                                    'Chưa có nhận định được lưu. Chạm để mở phân tích AI.',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF667572),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Mở Trợ lý sức khỏe',
                                style: TextStyle(
                                  color: _teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
            pendingMeasurements: _pendingMeasurementCount,
            profileId: _profileId,
            member: _member,
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
