import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
  int _steps = 1200;
  Timer? _timer;
  bool _isPermissionGranted = false;

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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;

      final newHeartRate = 65 + Random().nextInt(35);
      final newSteps = _steps + Random().nextInt(10);
      final calculatedCalories = double.parse(
        (newSteps * 0.04).toStringAsFixed(1),
      );

      setState(() {
        _heartRate = newHeartRate;
        _steps = newSteps;
      });

      // ✅ Đóng gói JSON gửi qua HTTP POST (10.0.2.2:8080/sync)
      final payload = {
        'heartRate': _heartRate,
        'steps': _steps,
        'calories': calculatedCalories,
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        final success = await _senderService.sendDataToPhone(payload);
        if (success) {
          debugPrint('[Wear] ✅ Đã gửi thành công: $payload');
        } else {
          debugPrint('[Wear] ⚠️ Gửi thất bại, sẽ thử lại sau 5s...');
        }
      } catch (e) {
        debugPrint('[Wear Error] ❌ Lỗi gửi dữ liệu: $e');
      }
    });
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
                  _isPermissionGranted
                      ? 'HTTP Syncing (5s)...'
                      : 'Check Permissions',
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
