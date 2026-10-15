import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/widgets.dart';

import 'main_navigation_wrapper.dart';
import 'quick_add_screen.dart';

class HealthTrendsScreen extends StatefulWidget {
  const HealthTrendsScreen({
    super.key,
    this.member = 'Tôi',
    this.profileId,
  });

  final String member;
  final String? profileId;

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends State<HealthTrendsScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _measurements = <String, String>{
    'HEART_RATE': 'Nhịp tim',
    'BLOOD_PRESSURE': 'Huyết áp',
    'WEIGHT': 'Cân nặng',
    'BLOOD_GLUCOSE': 'Đường huyết',
  };

  String _selectedType = 'HEART_RATE';
  int _periodDays = 7;
  bool _isLoading = true;
  String? _error;
  List<_TrendPoint> _points = [];

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
      if (widget.member != 'Tôi' && widget.profileId == null) {
        throw const FormatException(
          'Chưa có UUID hồ sơ gia đình để truy vấn xu hướng.',
        );
      }
      final records = await ApiService.fetchHealthMeasurements(
        profileId: widget.profileId,
      );
      final start = DateTime.now().subtract(Duration(days: _periodDays));
      final grouped = <DateTime, List<_TrendPoint>>{};
      for (final record in records) {
        if (record['measurement_type'] != _selectedType) continue;
        final measuredAt = DateTime.tryParse(
          record['measured_at']?.toString() ?? '',
        )?.toLocal();
        final value = _number(record['value']);
        if (measuredAt == null ||
            measuredAt.isBefore(start) ||
            value == null) {
          continue;
        }
        final day = DateTime(measuredAt.year, measuredAt.month, measuredAt.day);
        final secondary = _selectedType == 'BLOOD_PRESSURE'
            ? _number(record['value_secondary'])
            : null;
        (grouped[day] ??= []).add(
          _TrendPoint(day, value.toDouble(), secondary?.toDouble()),
        );
      }
      final points = grouped.entries.map((entry) {
        final daily = entry.value;
        final secondaryValues = daily
            .where((point) => point.secondary != null)
            .map((point) => point.secondary!)
            .toList(growable: false);
        return _TrendPoint(
          entry.key,
          daily.map((point) => point.primary).reduce((a, b) => a + b) /
              daily.length,
          secondaryValues.isEmpty
              ? null
              : secondaryValues.reduce((a, b) => a + b) /
                    secondaryValues.length,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _points = [];
        _error = error is ApiException
            ? error.message
            : 'Không thể tải dữ liệu xu hướng. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  num? _number(dynamic raw) =>
      raw is num ? raw : num.tryParse(raw?.toString() ?? '');

  List<double> get _allValues => [
    for (final point in _points) point.primary,
    for (final point in _points)
      if (point.secondary != null) point.secondary!,
  ];

  String get _unit => switch (_selectedType) {
    'HEART_RATE' => 'bpm',
    'BLOOD_PRESSURE' => 'mmHg',
    'WEIGHT' => 'kg',
    _ => 'mg/dL',
  };

  double get _average {
    final values = _allValues;
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    bool fill = false,
  }) => LineChartBarData(
    spots: spots,
    isCurved: true,
    color: color,
    barWidth: 2.5,
    dotData: const FlDotData(show: true),
    belowBarData: BarAreaData(
      show: fill,
      color: color.withValues(alpha: .10),
    ),
  );

  Widget _chart() {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _loadRecords, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_points.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'Chưa có dữ liệu đo trong khoảng thời gian này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF82908D)),
          ),
        ),
      );
    }

    final allValues = _allValues;
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * .15;
    final rangePadding = padding < 1 ? 1.0 : padding;
    final primary = [
      for (var i = 0; i < _points.length; i++)
        FlSpot(i.toDouble(), _points[i].primary),
    ];
    final lines = <LineChartBarData>[
      _line(primary, _teal, fill: _selectedType != 'BLOOD_PRESSURE'),
    ];
    if (_selectedType == 'BLOOD_PRESSURE') {
      lines.add(
        _line(
          [
            for (var i = 0; i < _points.length; i++)
              if (_points[i].secondary != null)
                FlSpot(i.toDouble(), _points[i].secondary!),
          ],
          const Color(0xFF438ED8),
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: _points.length > 1 ? (_points.length - 1).toDouble() : 1,
          minY: minY - rangePadding,
          maxY: maxY + rangePadding,
          lineBarsData: lines,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: null,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Color(0xFF82908D),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _points.length > 7 ? 4 : 1,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= _points.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _dateLabel(_points[index].date),
                    style: const TextStyle(
                      color: Color(0xFF82908D),
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }

  Future<void> _openQuickAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(
          member: widget.member,
          profileId: widget.profileId,
        ),
      ),
    );
    if (saved == true && mounted) await _loadRecords();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
      ),
    ),
    body: SkyBackground(
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _teal,
          onRefresh: _loadRecords,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Chỉ số',
                  filled: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in _measurements.entries)
                    DropdownMenuItem(value: item.key, child: Text(item.value)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedType = value);
                  _loadRecords();
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 ngày')),
                  ButtonSegment(value: 30, label: Text('30 ngày')),
                ],
                selected: {_periodDays},
                onSelectionChanged: (selection) {
                  setState(() => _periodDays = selection.first);
                  _loadRecords();
                },
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_measurements[_selectedType]} · $_periodDays ngày',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _chart(),
                    if (!_isLoading && _error == null && _points.isNotEmpty)
                      Text(
                        'Trung bình: ${_average.toStringAsFixed(1)} $_unit · ${_points.length} ngày có dữ liệu',
                        style: const TextStyle(
                          color: Color(0xFF687875),
                          fontSize: 11,
                        ),
                      ),
                    if (_selectedType == 'BLOOD_PRESSURE') ...[
                      const SizedBox(height: 8),
                      const Wrap(
                        spacing: 16,
                        children: [
                          _Legend(color: _teal, label: 'Tâm thu'),
                          _Legend(
                            color: Color(0xFF438ED8),
                            label: 'Tâm trương',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: MainNavigationWrapper(
      selectedIndex: 0,
      onSelected: (index) {
        if (index == 0) Navigator.pop(context);
      },
      onQuickAdd: _openQuickAdd,
    ),
  );
}

class _TrendPoint {
  const _TrendPoint(this.date, this.primary, this.secondary);

  final DateTime date;
  final double primary;
  final double? secondary;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF687875), fontSize: 10),
      ),
    ],
  );
}
