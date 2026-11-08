import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';
import 'services/mock_health_data_service.dart';
import 'services/watch_pending_queue.dart';
import 'services/watch_sender_service.dart';
import 'services/watch_sync_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WearApp());
}

class WearApp extends StatelessWidget {
  const WearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wear OS App',
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: Colors.black),
      home: const WearDashboard(),
    );
  }
}

class WearDashboard extends StatefulWidget {
  const WearDashboard({super.key});

  @override
  State<WearDashboard> createState() => _WearDashboardState();
}

class _WearDashboardState extends State<WearDashboard> {
  int _heartRate = 75;
  int _steps = 0;
  double _calories = 0;
  Timer? _timer;
  Timer? _retryTimer;
  bool _isSyncing = false;
  String _syncStatus = 'Đang khởi tạo';
  final MockHealthDataService _mockData = MockHealthDataService();
  final WatchSenderService _senderService = WatchSenderService();
  final WatchPendingQueue _pendingQueue = WatchPendingQueue.instance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWearState();
    });
  }

  Future<void> _initWearState() async {
    if (mounted) {
      if (useMockWearOs) {
        debugPrint('[Wear OS] $wearMockArchitectureNote.');
        setState(() => _syncStatus = 'Mock Mode • Offline Queue & Sync');
        _startMockDataAndSync();
        _retryTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => unawaited(_flushPending()),
        );
      } else {
        setState(() => _syncStatus = 'Real sensors chưa được cấu hình');
        debugPrint(
          '[Wear OS] USE_MOCK_WEAR_OS=false, but a real sensor adapter '
          'is not configured. Mock samples are disabled.',
        );
      }
    }
  }

  void _startMockDataAndSync() {
    _timer?.cancel();
    _scheduleNextSample();
  }

  void _scheduleNextSample() {
    if (!mounted) return;
    final interval = _mockData.activityState == MockActivityState.active
        ? const Duration(seconds: 5)
        : const Duration(seconds: 60);
    _timer = Timer(interval, () {
      unawaited(_generateAndSync());
    });
  }

  Future<void> _generateAndSync() async {
    if (!mounted || !useMockWearOs) return;

    final sample = _mockData.nextSample();
    setState(() {
      _heartRate = sample.heartRate;
      _steps = sample.steps;
      _calories = sample.calories;
    });

    try {
      await _pendingQueue.enqueue(sample.toJson());
      await _flushPending();
    } catch (error, stackTrace) {
      debugPrint('[Wear OS] Could not queue sample: $error\n$stackTrace');
      if (mounted) setState(() => _syncStatus = 'Không lưu được mẫu mới');
    } finally {
      _scheduleNextSample();
    }
  }

  Future<void> _flushPending() async {
    if (!mounted || _isSyncing || !useMockWearOs) return;
    _isSyncing = true;
    try {
      while (mounted) {
        final item = await _pendingQueue.firstReady();
        if (item == null) break;
        final sent = await _senderService.sendDataToPhone(item.payload);
        if (!sent) {
          await _pendingQueue.scheduleRetry(item);
          if (mounted) {
            setState(() => _syncStatus = 'Đang chờ kết nối • sẽ thử lại');
          }
          break;
        }
        await _pendingQueue.acknowledge(item.idempotencyKey);
        if (mounted) setState(() => _syncStatus = 'Đã đồng bộ');
      }
    } catch (error, stackTrace) {
      debugPrint('[Wear OS] Queue sync failed: $error\n$stackTrace');
      if (mounted) setState(() => _syncStatus = 'Lỗi đồng bộ • sẽ thử lại');
    } finally {
      _isSyncing = false;
    }
  }

  void _setActivityState(MockActivityState state) {
    if (_mockData.activityState == state) return;
    setState(() {
      _mockData.activityState = state;
    });
    _timer?.cancel();
    _scheduleNextSample();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.redAccent, size: 26),
                const SizedBox(height: 2),
                Text(
                  '$_heartRate bpm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(
                  Icons.directions_walk,
                  color: Colors.blueAccent,
                  size: 26,
                ),
                const SizedBox(height: 2),
                Text(
                  '$_steps bước',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_calories.toStringAsFixed(1)} kcal',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SegmentedButton<MockActivityState>(
                  segments: const [
                    ButtonSegment(
                      value: MockActivityState.resting,
                      label: Text('Nghỉ'),
                    ),
                    ButtonSegment(
                      value: MockActivityState.active,
                      label: Text('Vận động'),
                    ),
                  ],
                  selected: {_mockData.activityState},
                  onSelectionChanged: (selection) =>
                      _setActivityState(selection.first),
                ),
                const SizedBox(height: 8),
                Text(
                  '${useMockWearOs ? 'MOCK' : 'REAL'}'
                  ' • ${_mockData.activityState == MockActivityState.active ? '5' : '60'}s'
                  ' • $_syncStatus',
                  style: TextStyle(
                    color: _syncStatus == 'Đã đồng bộ'
                        ? AppColors.success
                        : AppColors.warning,
                    fontSize: 12,
                  ),
                ),
                if (useMockWearOs) ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      wearMockArchitectureNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
