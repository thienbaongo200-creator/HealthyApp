import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/manual_measurement_store.dart';
import 'package:frontend/widgets/widgets.dart';

enum _MetricType { bloodPressure, heartRate, weight, glucose, temperature, height }

class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key, this.member = 'Tôi'});

  final String member;

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _canvas = Color(0xFFF5F9F8);

  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _heightController = TextEditingController();
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
    _noteController.dispose();
    super.dispose();
  }

  String _typeLabel(_MetricType type) => switch (type) {
        _MetricType.bloodPressure => 'Huyết áp',
        _MetricType.heartRate => 'Nhịp tim',
        _MetricType.weight => 'Cân nặng',
        _MetricType.glucose => 'Đường huyết',
        _MetricType.temperature => 'Thân nhiệt',
        _MetricType.height => 'Chiều cao',
      };

  IconData _typeIcon(_MetricType type) => switch (type) {
        _MetricType.bloodPressure => Icons.monitor_heart_outlined,
        _MetricType.heartRate => Icons.favorite_border_rounded,
        _MetricType.weight => Icons.monitor_weight_outlined,
        _MetricType.glucose => Icons.water_drop_outlined,
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
      _measuredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: unit,
          filled: true,
          fillColor: Colors.white.withValues(alpha: .82),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1EBE8)),
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
      _MetricType.weight => {'weight_kg': double.parse(normalized(_weightController))},
      _MetricType.glucose => {
          'glucose_mg_dl': double.parse(normalized(_glucoseController)),
        },
      _MetricType.temperature => {
          'temperature_c': double.parse(normalized(_temperatureController)),
        },
      _MetricType.height => {'height_cm': double.parse(normalized(_heightController))},
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == _MetricType.bloodPressure) {
      final systolic = double.parse(_systolicController.text.replaceAll(',', '.'));
      final diastolic = double.parse(_diastolicController.text.replaceAll(',', '.'));
      if (systolic <= diastolic) {
        _showMessage('Tâm thu phải lớn hơn tâm trương.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await ManualMeasurementStore.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'type': _selectedType.name,
        'label': _typeLabel(_selectedType),
        'member': widget.member,
        'measured_at': _measuredAt.toIso8601String(),
        'values': _valuesForSelectedType(),
        'note': _noteController.text.trim(),
        'source': 'manual',
      });
      if (!mounted) return;
      _showMessage('Đã lưu bản ghi trên thiết bị này.');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _showMessage('Không thể lưu bản ghi. Vui lòng thử lại.');
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
        title: const Text(
          'Ghi nhận chỉ số',
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
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Chọn loại chỉ số',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
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
                      for (final type in _MetricType.values)
                        _metricTile(type),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Thông tin đo',
                                style: TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              _typeLabel(_selectedType),
                              style: const TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            side: const BorderSide(color: Color(0xFFE1EBE8)),
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
                            fillColor: Colors.white.withValues(alpha: .82),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bản ghi được lưu an toàn trên thiết bị. Các chỉ số nhập tay chưa đồng bộ lên máy chủ.',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : () => Navigator.maybePop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink,
                                  minimumSize: const Size.fromHeight(48),
                                  side: const BorderSide(color: Color(0xFFD7E3E0)),
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
                              child: GradientButton(
                                label: 'Lưu dữ liệu',
                                icon: Icons.save_outlined,
                                onPressed: _isSaving ? null : _save,
                                isLoading: _isSaving,
                                height: 48,
                                gradientColors: const [
                                  Color(0xFF32A88D),
                                  Color(0xFF168B83),
                                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5F4F0) : Colors.white.withValues(alpha: .84),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE1EBE8),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x1A168B83), blurRadius: 10, offset: Offset(0, 3))]
              : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_typeIcon(type), color: selected ? _teal : const Color(0xFF72827F), size: 22),
            const SizedBox(height: 7),
            Text(
              _typeLabel(type),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _teal : _ink,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
