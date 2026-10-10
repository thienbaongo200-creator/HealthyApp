import 'package:flutter/material.dart';
import 'package:frontend/services/manual_measurement_store.dart';
import 'package:frontend/widgets/widgets.dart';

import 'quick_add_screen.dart';

class HealthTrendsScreen extends StatefulWidget {
  const HealthTrendsScreen({super.key, this.member = 'Tôi'});

  final String member;

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

enum _TrendPeriod { week, month }

class _HealthTrendsScreenState extends State<HealthTrendsScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);

  _TrendPeriod _period = _TrendPeriod.week;
  bool _isLoading = true;
  String? _error;
  List<_PressureRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stored = await ManualMeasurementStore.readAll();
      if (!mounted) return;
      final records = <_PressureRecord>[];
      for (final item in stored) {
        if (item['type'] != 'bloodPressure' || item['member'] != widget.member) {
          continue;
        }
        final measuredAt = DateTime.tryParse(item['measured_at']?.toString() ?? '')
            ?.toLocal();
        final values = item['values'];
        if (measuredAt == null || values is! Map<String, dynamic>) continue;
        final systolic = (values['systolic'] as num?)?.toDouble();
        final diastolic = (values['diastolic'] as num?)?.toDouble();
        if (systolic == null || diastolic == null) continue;
        records.add(_PressureRecord(
          measuredAt: measuredAt,
          systolic: systolic,
          diastolic: diastolic,
        ));
      }
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể đọc dữ liệu trên thiết bị.';
        _isLoading = false;
      });
    }
  }

  DateTime get _periodStart {
    final today = DateTime.now();
    final dayCount = _period == _TrendPeriod.week ? 7 : 30;
    return DateTime(today.year, today.month, today.day).subtract(
      Duration(days: dayCount - 1),
    );
  }

  List<_PressureRecord> get _filteredRecords {
    final start = _periodStart;
    final end = DateTime.now();
    return _records
        .where((record) =>
            !record.measuredAt.isBefore(start) && !record.measuredAt.isAfter(end))
        .toList(growable: false);
  }

  List<_TrendPoint> get _points {
    final grouped = <DateTime, List<_PressureRecord>>{};
    for (final record in _filteredRecords) {
      final day = DateTime(
        record.measuredAt.year,
        record.measuredAt.month,
        record.measuredAt.day,
      );
      (grouped[day] ??= []).add(record);
    }
    final points = grouped.entries.map((entry) {
      final records = entry.value;
      return _TrendPoint(
        date: entry.key,
        systolic: records.map((record) => record.systolic).reduce((a, b) => a + b) /
            records.length,
        diastolic: records.map((record) => record.diastolic).reduce((a, b) => a + b) /
            records.length,
      );
    }).toList();
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  double? _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  String _periodLabel() => _period == _TrendPeriod.week
      ? '7 ngày gần nhất'
      : '30 ngày gần nhất';

  Future<void> _exportPdf() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất báo cáo PDF'),
        content: const Text(
          'Dự án chưa tích hợp thư viện tạo PDF. Dữ liệu thống kê vẫn được lưu an toàn trên thiết bị; chức năng xuất tệp sẽ khả dụng sau khi bổ sung module báo cáo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;
    final points = _points;
    final systolicAverage = _average(records.map((record) => record.systolic));
    final diastolicAverage = _average(records.map((record) => record.diastolic));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Thống kê & Xu hướng',
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
            onRefresh: _loadRecords,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                _periodTabs(),
                const SizedBox(height: 14),
                _chartCard(points),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Số liệu trung bình',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _periodLabel(),
                      style: const TextStyle(
                        color: Color(0xFF82908D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _summaryTable(records, systolicAverage, diastolicAverage),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Xuất báo cáo PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _teal,
                      backgroundColor: Colors.white.withValues(alpha: .78),
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFB8DAD5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 12,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Trang chủ', onTap: () => Navigator.pop(context)),
              _navItem(Icons.menu_book_rounded, 'Nhật ký'),
              const SizedBox(width: 55),
              _navItem(Icons.chat_bubble_outline_rounded, 'Tư vấn'),
              _navItem(Icons.watch_outlined, 'Thiết bị'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => QuickAddScreen(member: widget.member),
            ),
          );
          if (saved == true) await _loadRecords();
        },
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _periodTabs() => GlassCard(
        padding: const EdgeInsets.all(5),
        borderRadius: 16,
        child: Row(
          children: [
            _periodTab(_TrendPeriod.week, 'Theo tuần'),
            _periodTab(_TrendPeriod.month, 'Theo tháng'),
          ],
        ),
      );

  Widget _periodTab(_TrendPeriod period, String label) {
    final selected = _period == period;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _period = period),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _teal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF72827F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chartCard(List<_TrendPoint> points) => GlassCard(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Xu hướng huyết áp',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _periodLabel(),
                  style: const TextStyle(color: Color(0xFF82908D), fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (_isLoading)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: _teal)),
              )
            else if (_error != null)
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF82908D)),
                  ),
                ),
              )
            else if (points.isEmpty)
              SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        size: 32,
                        color: _teal.withValues(alpha: .65),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Chưa có dữ liệu huyết áp trong khoảng này',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF82908D), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(painter: _PressureChartPainter(points)),
              ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Legend(color: Color(0xFFE66B71), label: 'Tâm thu (mmHg)'),
                _Legend(color: Color(0xFF438ED8), label: 'Tâm trương (mmHg)'),
              ],
            ),
          ],
        ),
      );

  Widget _summaryTable(
    List<_PressureRecord> records,
    double? systolicAverage,
    double? diastolicAverage,
  ) {
    if (_isLoading) {
      return const GlassCard(
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (_error != null) {
      return GlassCard(
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF82908D))),
            TextButton(onPressed: _loadRecords, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Chỉ số', style: _tableHeader)),
                Expanded(child: Text('Trung bình', textAlign: TextAlign.end, style: _tableHeader)),
                Expanded(child: Text('Lần đo', textAlign: TextAlign.end, style: _tableHeader)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EFED)),
          _summaryRow(
            'Tâm thu',
            systolicAverage,
            records.length,
            const Color(0xFFE66B71),
          ),
          const Divider(height: 1, indent: 15, endIndent: 15, color: Color(0xFFE8EFED)),
          _summaryRow(
            'Tâm trương',
            diastolicAverage,
            records.length,
            const Color(0xFF438ED8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 13),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                records.isEmpty
                    ? 'Chưa có bản ghi để tính trung bình.'
                    : 'Tính từ ${records.length} lần đo đã nhập thủ công.',
                style: const TextStyle(color: Color(0xFF82908D), fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _tableHeader = TextStyle(
    color: Color(0xFF82908D),
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  Widget _summaryRow(String title, double? average, int count, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                average == null ? '—' : '${average.toStringAsFixed(1)} mmHg',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '$count',
                textAlign: TextAlign.end,
                style: const TextStyle(color: _ink, fontSize: 11),
              ),
            ),
          ],
        ),
      );

  Widget _navItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap ?? () => _showMessage('$label sẽ được bổ sung sau.'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: const Color(0xFF9AA6A3)),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: Color(0xFF9AA6A3), fontSize: 9),
              ),
            ],
          ),
        ),
      );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PressureRecord {
  const _PressureRecord({
    required this.measuredAt,
    required this.systolic,
    required this.diastolic,
  });

  final DateTime measuredAt;
  final double systolic;
  final double diastolic;
}

class _TrendPoint {
  const _TrendPoint({
    required this.date,
    required this.systolic,
    required this.diastolic,
  });

  final DateTime date;
  final double systolic;
  final double diastolic;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF687875), fontSize: 10)),
        ],
      );
}

class _PressureChartPainter extends CustomPainter {
  const _PressureChartPainter(this.points);
  final List<_TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    const left = 34.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 24.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final allValues = [
      for (final point in points) ...[point.systolic, point.diastolic],
    ];
    final low = allValues.reduce((a, b) => a < b ? a : b);
    final high = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = ((low - 10) / 10).floor() * 10.0;
    final maxValue = ((high + 10) / 10).ceil() * 10.0;
    final gridPaint = Paint()
      ..color = const Color(0xFFE5ECEA)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      final label = (maxValue - (maxValue - minValue) * i / 4).round().toString();
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFF95A19E), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - text.height / 2));
    }

    Offset pointAt(int index, double value) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);
      final normalized = ((value - minValue) / (maxValue - minValue))
          .clamp(0.0, 1.0)
          .toDouble();
      return Offset(x, top + chartHeight * (1 - normalized));
    }

    void drawSeries(double Function(_TrendPoint) valueOf, Color color) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final pointsForSeries = [
        for (var i = 0; i < points.length; i++) pointAt(i, valueOf(points[i])),
      ];
      if (pointsForSeries.length > 1) {
        final path = Path()..moveTo(pointsForSeries.first.dx, pointsForSeries.first.dy);
        for (final point in pointsForSeries.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, linePaint);
      }
      final dotPaint = Paint()..color = color;
      for (var i = 0; i < pointsForSeries.length; i++) {
        final point = pointsForSeries[i];
        canvas.drawCircle(point, 4, Paint()..color = Colors.white);
        canvas.drawCircle(point, 2.5, dotPaint);
        if (color == const Color(0xFFE66B71) &&
            (points.length <= 7 || i % 5 == 0 || i == points.length - 1)) {
          final date = points[i].date;
          final label = '${date.day}/${date.month}';
          final text = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(color: Color(0xFF95A19E), fontSize: 8),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset(point.dx - text.width / 2, size.height - text.height));
        }
      }
    }

    drawSeries((point) => point.systolic, const Color(0xFFE66B71));
    drawSeries((point) => point.diastolic, const Color(0xFF438ED8));
  }

  @override
  bool shouldRepaint(covariant _PressureChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
