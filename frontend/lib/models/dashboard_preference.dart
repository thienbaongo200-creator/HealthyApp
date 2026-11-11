class MetricDefinition {
  const MetricDefinition({required this.code, required this.label, required this.unit});
  final String code;
  final String label;
  final String unit;

  static const all = <MetricDefinition>[
    MetricDefinition(code: 'HEART_RATE', label: 'Nhịp tim', unit: 'bpm'),
    MetricDefinition(code: 'BLOOD_PRESSURE', label: 'Huyết áp', unit: 'mmHg'),
    MetricDefinition(code: 'BMI', label: 'BMI', unit: 'kg/m²'),
    MetricDefinition(code: 'TEMPERATURE', label: 'Thân nhiệt', unit: '°C'),
    MetricDefinition(code: 'WEIGHT', label: 'Cân nặng', unit: 'kg'),
    MetricDefinition(code: 'HEIGHT', label: 'Chiều cao', unit: 'cm'),
    MetricDefinition(code: 'SLEEP', label: 'Giấc ngủ', unit: 'giờ'),
    MetricDefinition(code: 'BLOOD_GLUCOSE', label: 'Đường huyết', unit: 'mg/dL'),
    MetricDefinition(code: 'STEPS', label: 'Số bước chân', unit: 'bước'),
    MetricDefinition(code: 'CALORIES', label: 'Năng lượng tiêu hao', unit: 'kcal'),
  ];

  static MetricDefinition byCode(String code) => all.firstWhere((m) => m.code == code);
}

class DashboardPreference {
  const DashboardPreference({required this.profileId, required this.selectedMetrics, required this.metricOrder});
  final String profileId;
  final List<String> selectedMetrics;
  final List<String> metricOrder;

  static const defaults = ['HEART_RATE', 'BLOOD_PRESSURE', 'BMI', 'TEMPERATURE'];
  factory DashboardPreference.fromJson(Map<String, dynamic> json) => DashboardPreference(
    profileId: json['profile_id'].toString(),
    selectedMetrics: List<String>.from(json['selected_metrics'] ?? defaults),
    metricOrder: List<String>.from(json['metric_order'] ?? json['selected_metrics'] ?? defaults),
  );

  Map<String, dynamic> toJson() => {'profile_id': profileId, 'selected_metrics': selectedMetrics, 'metric_order': metricOrder};
}
