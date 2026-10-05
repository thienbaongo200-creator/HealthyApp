import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/mock_health_data_service.dart';
import 'services/watch_sender_service.dart'; // ✅ Đổi sang service gửi HTTP mới

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
  bool _isPermissionGranted = false;
  final MockHealthDataService _mockData = MockHealthDataService();

  // ✅ Khởi tạo Sender Service chuẩn HTTP
  final WatchSenderService _senderService = WatchSenderService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWearState();
    });
  }

  Future<void> _initWearState() async {
    await _requestPermissions();

    // ✅ Bắt đầu chu kỳ gửi dữ liệu HTTP
    _startMockDataAndSync();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.sensors,
      Permission.activityRecognition,
    ].request();

    final sensorsGranted = statuses[Permission.sensors]?.isGranted ?? false;
    final activityGranted =
        statuses[Permission.activityRecognition]?.isGranted ?? false;

    if (mounted) {
      setState(() {
        _isPermissionGranted = sensorsGranted && activityGranted;
      });
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
    if (!mounted) return;

    final sample = _mockData.nextSample();
    setState(() {
      _heartRate = sample.heartRate;
      _steps = sample.steps;
      _calories = sample.calories;
    });

    try {
      await _senderService.sendDataToPhone(sample.toJson());
    } finally {
      _scheduleNextSample();
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
                  '${_mockData.activityState == MockActivityState.active ? 'Active' : 'Resting'}'
                  ' • ${_mockData.activityState == MockActivityState.active ? '5' : '60'}s'
                  '${_isPermissionGranted ? ' • Permissions OK' : ' • Check permissions'}',
                  style: TextStyle(
                    color: _isPermissionGranted
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
