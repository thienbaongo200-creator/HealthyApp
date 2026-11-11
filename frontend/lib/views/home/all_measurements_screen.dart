import 'package:flutter/material.dart';
import '../../models/dashboard_preference.dart';

class AllMeasurementsScreen extends StatelessWidget {
  const AllMeasurementsScreen({super.key, required this.measurements});
  final List<Map<String, dynamic>> measurements;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tất cả chỉ số')),
    body: ListView.builder(itemCount: MetricDefinition.all.length, itemBuilder: (context, index) {
      final metric = MetricDefinition.all[index];
      final records = measurements.where((row) => row['measurement_type'] == metric.code).toList()
        ..sort((a, b) => (b['measured_at'] ?? '').toString().compareTo((a['measured_at'] ?? '').toString()));
      final latest = records.isEmpty ? null : records.first;
      final value = latest == null ? 'Chưa có dữ liệu' : '${latest['value']}${metric.code == 'BLOOD_PRESSURE' && latest['value_secondary'] != null ? '/${latest['value_secondary']}' : ''} ${latest['unit'] ?? metric.unit}';
      return ListTile(title: Text(metric.label), subtitle: Text(value), trailing: latest == null ? null : Text('${records.length} lần đo'));
    }),
  );
}
