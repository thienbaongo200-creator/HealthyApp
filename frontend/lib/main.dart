import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/watch_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Khoi tao Watch listener SAU runApp de dam bao
  // Flutter engine + plugin registration da san sang
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthy App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HealthDashboard(),
    );
  }
}

class HealthDashboard extends StatefulWidget {
  const HealthDashboard({super.key});

  @override
  State<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  int _heartRate = 0;
  int _steps = 0;
  double _calories = 0.0;
  bool _wearConnected = false;
  late final StreamSubscription<Map<String, dynamic>> _wearSubscription;

  @override
  void initState() {
    super.initState();

    // Lắng nghe dữ liệu từ Wear (HTTP POST /sync từ WatchSenderService)
    _wearSubscription = WatchService().wearDataStream.listen(
      (data) {
        if (!mounted) return;

        final heartRate = data['heartRate'] as int?;
        final steps = data['steps'] as int?;
        final calories = (data['calories'] as num?)?.toDouble();

        if (heartRate == null || steps == null || calories == null) {
          debugPrint('[Phone] Message Wear khong du du lieu: $data');
          return;
        }

        setState(() {
          _wearConnected = true;
          _heartRate = heartRate;
          _steps = steps;
          _calories = calories;
        });

        // Gui du lieu len API Backend
        ApiService.sendHealthData(
          heartRate: heartRate,
          steps: steps,
          calories: calories,
        ).then((success) {
          if (!success) {
            debugPrint('[Phone] Dong bo du lieu len API that bai');
          }
        });
      },
      onError: (error) {
        debugPrint('[Phone] Loi khi nhan message tu Wear: $error');
      },
    );

    // Khoi tao HTTP listener cho WatchSenderService
    // (chay sau khi UI da dung de server bind san sang truoc khi nhan du lieu)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWatchListener();
    });
  }

  Future<void> _initWatchListener() async {
    // Trong môi trường test (flutter test), bỏ qua việc bind HttpServer
    // để tránh tạo Timer pending (idle timeout) gây lỗi "A Timer is still pending".
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      debugPrint('[Phone] Bo qua khoi tao HTTP listener khi dang chay test');
      return;
    }

    debugPrint('[Phone] Dang khoi tao Watch listener...');
    try {
      await WatchService().initPhoneListener(port: 8080);
      debugPrint('[Phone] Watch listener da khoi tao thanh cong');
    } catch (e, st) {
      debugPrint('[Phone] Loi khoi tao Watch listener: $e\n$st');
    }
  }

  @override
  void dispose() {
    _wearSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Healthy App'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMetricCard(
              icon: Icons.favorite,
              label: 'Nhip tim',
              value: '$_heartRate',
              unit: 'bpm',
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              icon: Icons.directions_walk,
              label: 'Buoc chan',
              value: '$_steps',
              unit: 'buoc',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              icon: Icons.local_fire_department,
              label: 'Calo',
              value: _calories.toStringAsFixed(1),
              unit: 'kcal',
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                _wearConnected
                    ? 'Da ket noi voi dong ho'
                    : 'Dang cho ket noi tu dong ho...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        subtitle: Text(
          '$value $unit',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _refreshData() async {
    // Chi la gia lap pull-to-refresh nhe nhang
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
