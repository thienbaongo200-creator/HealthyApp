import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/watch_service.dart';
import 'package:frontend/widgets/gradient_button.dart';
import 'package:frontend/widgets/sky_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ===== State nhận dữ liệu (giữ nguyên từ code cũ) =====
  int _heartRate = 0;
  int _steps = 0;
  double _calories = 0.0;
  bool _wearConnected = false;

  // Lịch sử nhịp tim gần nhất để vẽ biểu đồ (tối đa 12 điểm)
  final List<int> _heartRateHistory = [];

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

          // Thêm vào lịch sử cho biểu đồ
          _heartRateHistory.add(heartRate);
          if (_heartRateHistory.length > 12) {
            _heartRateHistory.removeAt(0);
          }
        });

        // Gửi dữ liệu lên API Backend
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

    // Khởi tạo HTTP listener cho WatchSenderService
    // (chạy sau khi UI đã dựng để server bind sẵn sàng trước khi nhận dữ liệu)
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

  Future<void> _refreshData() async {
    // Chỉ là giả lập pull-to-refresh nhẹ nhàng
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã làm mới dữ liệu')));
    }
  }

  Widget _buildConnectionStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _wearConnected
            ? const Color(0xFFE8F5E9)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _wearConnected
              ? const Color(0xFF69F0AE)
              : Colors.white.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _wearConnected ? Icons.watch : Icons.watch_later_outlined,
            size: 18,
            color: _wearConnected
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            _wearConnected ? 'Đã kết nối' : 'Đang chờ kết nối...',
            style: TextStyle(
              color: _wearConnected
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chào mừng bạn!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          "Theo dõi sức khỏe của bạn ngay hôm nay",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildConnectionStatus(context),
                const SizedBox(height: 24),

                // --- TRẠNG THÁI SỨC KHỎE ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "Trạng thái sức khỏe",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 3,
                        children: [
                          HealthIndicatorItem(
                            icon: Icons.favorite,
                            iconColor: Colors.redAccent,
                            title: "Nhịp tim",
                            value: '$_heartRate bpm',
                          ),
                          const HealthIndicatorItem(
                            icon: Icons.opacity,
                            iconColor: Colors.teal,
                            title: "Huyết áp",
                            value: "—",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- HOẠT ĐỘNG HÔM NAY ---
                const Text(
                  "Hoạt động hôm nay",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ActivityButton(
                      icon: Icons.directions_walk,
                      label: "Bước đi",
                      value: '$_steps',
                      iconColor: Colors.blue,
                    ),
                    ActivityButton(
                      icon: Icons.local_fire_department,
                      label: "Calo",
                      value: '${_calories.toStringAsFixed(1)} kcal',
                      iconColor: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- BIỂU ĐỒ ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Theo dõi sức khỏe",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshData,
                      tooltip: 'Làm mới',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _heartRateHistory.length < 2
                      ? Center(
                          child: Text(
                            'Chưa có dữ liệu nhịp tim.\nĐợi dữ liệu từ đồng hồ...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : _HealthBarChart(
                          values: _heartRateHistory,
                          color: const Color(0xFF4CAF50),
                          baselineColor: Colors.grey.shade300,
                          barColor: const Color(0xFF66BB6A),
                        ),
                ),
                const SizedBox(height: 30),

                // --- NÚT HÀNH ĐỘNG ---
                GradientButton(
                  label: "Đăng nhập đồng hồ",
                  icon: Icons.watch,
                  onPressed: () {},
                  height: 52,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("Xem chi tiết"),
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

// Sub-widget trạng thái sức khỏe
class HealthIndicatorItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const HealthIndicatorItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

// Sub-widget hoạt động (hiển thị chỉ số thực từ đồng hồ)
class ActivityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const ActivityButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Biểu đồ cột đơn giản vẽ bằng CustomPaint (không cần thêm dependency)
class _HealthBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  final Color baselineColor;
  final Color barColor;

  const _HealthBarChart({
    required this.values,
    required this.color,
    required this.baselineColor,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _HealthBarChartPainter(
        values: values,
        color: color,
        baselineColor: baselineColor,
        barColor: barColor,
      ),
    );
  }
}

class _HealthBarChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;
  final Color baselineColor;
  final Color barColor;

  _HealthBarChartPainter({
    required this.values,
    required this.color,
    required this.baselineColor,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.reduce(max).toDouble();
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    // Đường baseline
    final linePaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height - 2),
      Offset(size.width, size.height - 2),
      linePaint,
    );

    final barWidth = (size.width / values.length) * 0.6;
    final gap = (size.width / values.length) * 0.4;

    for (int i = 0; i < values.length; i++) {
      final barHeight = (values[i] / safeMax) * (size.height - 12);
      final left = i * (barWidth + gap) + gap / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight - 2, barWidth, barHeight),
        const Radius.circular(4),
      );

      // Gradient cho từng cột
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [barColor.withValues(alpha: 0.4), barColor],
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, Paint()..shader = gradient);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthBarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
