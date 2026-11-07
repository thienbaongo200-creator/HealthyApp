import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/widgets/widgets.dart';

enum _MetricType {
  bloodPressure,
  heartRate,
  glucose,
  sleep,
  weight,
  height,
  temperature,
}

class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key, this.member = 'Tôi', this.profileId});

  final String member;
  final String? profileId;

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  static const _teal = AppColors.primary;
  static const _ink = AppColors.textPrimary;
  static const _canvas = AppColors.background;

  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _heightController = TextEditingController();
  final _sleepController = TextEditingController();
  final _noteController = TextEditingController();

  _MetricType _selectedType = _MetricType.bloodPressure;
  DateTime _measuredAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _weightController.dispose();
    _glucoseController.dispose();
    _temperatureController.dispose();
    _heightController.dispose();
    _sleepController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _typeLabel(_MetricType type) => switch (type) {
    _MetricType.bloodPressure => 'Huyết áp',
    _MetricType.heartRate => 'Nhịp tim',
    _MetricType.weight => 'Cân nặng',
    _MetricType.glucose => 'Đường huyết',
    _MetricType.sleep => 'Giấc ngủ',
    _MetricType.temperature => 'Thân nhiệt',
    _MetricType.height => 'Chiều cao',
  };

  IconData _typeIcon(_MetricType type) => switch (type) {
    _MetricType.bloodPressure => Icons.monitor_heart_outlined,
    _MetricType.heartRate => Icons.favorite_border_rounded,
    _MetricType.weight => Icons.monitor_weight_outlined,
    _MetricType.glucose => Icons.water_drop_outlined,
    _MetricType.sleep => Icons.bedtime_outlined,
    _MetricType.temperature => Icons.thermostat_rounded,
    _MetricType.height => Icons.height_rounded,
  };

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Chọn ngày đo',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
      helpText: 'Chọn giờ đo',
    );
    if (time == null || !mounted) return;
    setState(() {
      _measuredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required double min,
    required double max,
    String? hint,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: unit,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
    ),
    validator: (text) {
      if (text == null || text.trim().isEmpty) return 'Vui lòng nhập $label';
      final value = double.tryParse(text.trim().replaceAll(',', '.'));
      if (value == null || value < min || value > max) {
        return 'Nhập giá trị từ $min đến $max $unit';
      }
      return null;
    },
  );

  List<Widget> _selectedFields() => switch (_selectedType) {
    _MetricType.bloodPressure => [
      Row(
        children: [
          Expanded(
            child: _numberField(
              controller: _systolicController,
              label: 'Tâm thu',
              unit: 'mmHg',
              min: 50,
              max: 260,
              hint: '120',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _numberField(
              controller: _diastolicController,
              label: 'Tâm trương',
              unit: 'mmHg',
              min: 30,
              max: 180,
              hint: '80',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _numberField(
        controller: _heartRateController,
        label: 'Nhịp tim',
        unit: 'bpm',
        min: 30,
        max: 250,
        hint: 'Ví dụ: 72',
      ),
    ],
    _MetricType.heartRate => [
      _numberField(
        controller: _heartRateController,
        label: 'Nhịp tim',
        unit: 'bpm',
        min: 30,
        max: 250,
        hint: 'Ví dụ: 72',
      ),
    ],
    _MetricType.weight => [
      _numberField(
        controller: _weightController,
        label: 'Cân nặng',
        unit: 'kg',
        min: 2,
        max: 500,
        hint: 'Ví dụ: 60.5',
      ),
    ],
    _MetricType.glucose => [
      _numberField(
        controller: _glucoseController,
        label: 'Đường huyết',
        unit: 'mg/dL',
        min: 10,
        max: 1000,
        hint: 'Ví dụ: 95',
      ),
    ],
    _MetricType.sleep => [
      _numberField(
        controller: _sleepController,
        label: 'Thời lượng ngủ',
        unit: 'giờ',
        min: 0,
        max: 24,
        hint: 'Ví dụ: 7.5',
      ),
    ],
    _MetricType.temperature => [
      _numberField(
        controller: _temperatureController,
        label: 'Thân nhiệt',
        unit: '°C',
        min: 25,
        max: 45,
        hint: 'Ví dụ: 36.5',
      ),
    ],
    _MetricType.height => [
      _numberField(
        controller: _heightController,
        label: 'Chiều cao',
        unit: 'cm',
        min: 30,
        max: 280,
        hint: 'Ví dụ: 165',
      ),
    ],
  };

  Map<String, dynamic> _valuesForSelectedType() {
    String normalized(TextEditingController controller) =>
        controller.text.trim().replaceAll(',', '.');
    return switch (_selectedType) {
      _MetricType.bloodPressure => {
        'systolic': double.parse(normalized(_systolicController)),
        'diastolic': double.parse(normalized(_diastolicController)),
        'heart_rate': double.parse(normalized(_heartRateController)),
      },
      _MetricType.heartRate => {
        'heart_rate': double.parse(normalized(_heartRateController)),
      },
      _MetricType.weight => {
        'weight_kg': double.parse(normalized(_weightController)),
      },
      _MetricType.glucose => {
        'glucose_mg_dl': double.parse(normalized(_glucoseController)),
      },
      _MetricType.sleep => {
        'sleep_hours': double.parse(normalized(_sleepController)),
      },
      _MetricType.temperature => {
        'temperature_c': double.parse(normalized(_temperatureController)),
      },
      _MetricType.height => {
        'height_cm': double.parse(normalized(_heightController)),
      },
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == _MetricType.bloodPressure) {
      final systolic = double.parse(
        _systolicController.text.replaceAll(',', '.'),
      );
      final diastolic = double.parse(
        _diastolicController.text.replaceAll(',', '.'),
      );
      if (systolic <= diastolic) {
        _showMessage('Tâm thu phải lớn hơn tâm trương.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final values = _valuesForSelectedType();
      final measuredAt = _measuredAt.toUtc().toIso8601String();
      final key = 'manual-${DateTime.now().microsecondsSinceEpoch}';
      final records = <Map<String, dynamic>>[];
      void add(String type, num value, String unit, {num? secondary}) {
        records.add({
          'measurement_type': type,
          'value': value,
          'value_secondary': ?secondary,
          'unit': unit,
          'measured_at': measuredAt,
          'source': 'MANUAL',
          'idempotency_key': '${key}_$type',
        });
      }

      switch (_selectedType) {
        case _MetricType.bloodPressure:
          add(
            'BLOOD_PRESSURE',
            values['systolic'] as num,
            'mmHg',
            secondary: values['diastolic'] as num,
          );
          add('HEART_RATE', values['heart_rate'] as num, 'bpm');
          break;
        case _MetricType.heartRate:
          add('HEART_RATE', values['heart_rate'] as num, 'bpm');
          break;
        case _MetricType.weight:
          add('WEIGHT', values['weight_kg'] as num, 'kg');
          break;
        case _MetricType.glucose:
          add('BLOOD_GLUCOSE', values['glucose_mg_dl'] as num, 'mg/dL');
          break;
        case _MetricType.sleep:
          add('SLEEP', values['sleep_hours'] as num, 'h');
          break;
        case _MetricType.temperature:
          add('TEMPERATURE', values['temperature_c'] as num, '°C');
          break;
        case _MetricType.height:
          add('HEIGHT', values['height_cm'] as num, 'cm');
          break;
      }
      await ApiService.createManualMeasurements(
        records,
        profileId: widget.profileId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException
              ? error.message
              : 'Không thể lưu bản ghi. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ghi nhận chỉ số',
          style: Theme.of(context).textTheme.titleLarge,
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
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x6 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chọn loại chỉ số',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 1.08,
                    children: [
                      for (final type in _MetricType.values) _metricTile(type),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Thông tin đo',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              _typeLabel(_selectedType),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _pickDateTime,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(_formatDateTime(_measuredAt)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(AppSpacing.x3),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._selectedFields(),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: 'Ghi chú (không bắt buộc)',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bản ghi được lưu an toàn trên thiết bị. Các chỉ số nhập tay chưa đồng bộ lên máy chủ.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.maybePop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink,
                                  minimumSize: const Size.fromHeight(48),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: 'Lưu dữ liệu',
                                icon: Icons.save_outlined,
                                onPressed: _isSaving ? null : _save,
                                isLoading: _isSaving,
                                height: 48,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricTile(_MetricType type) {
    final selected = type == _selectedType;
    return InkWell(
      onTap: _isSaving ? null : () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x1,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _teal : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _typeIcon(type),
              color: selected ? _teal : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              _typeLabel(type),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? _teal : _ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
