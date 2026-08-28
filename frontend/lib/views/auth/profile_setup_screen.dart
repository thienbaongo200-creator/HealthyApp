import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/sky_background.dart';
import '../home/dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  static const routeName = '/profile-setup';

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedGender = 'Nam';
  bool _genderSelected = true;
  bool _isLoading = false;
  DateTime? _selectedDate;
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final _heightFocusNode = FocusNode();
  final _weightFocusNode = FocusNode();

  @override
  void dispose() {
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _heightFocusNode.dispose();
    _weightFocusNode.dispose();
    super.dispose();
  }

  void _setGender(String gender) {
    setState(() {
      _selectedGender = gender;
      _genderSelected = true;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: earliest,
      lastDate: now,
      locale: const Locale('vi', 'VN'),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      fieldLabelText: 'DD/MM/YYYY',
      errorFormatText: 'Định dạng ngày không hợp lệ',
      errorInvalidText: 'Ngày không hợp lệ',
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
          _dobController.text =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    // Validate gender
    if (!_genderSelected) {
      _showSnackBar('Vui lòng chọn giới tính', Colors.redAccent);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Chuyển đổi gender sang tiếng Anh cho API
    final genderMap = {'Nam': 'male', 'Nữ': 'female'};
    final gender = genderMap[_selectedGender] ?? 'male';

    // Format dob thành YYYY-MM-DD cho API
    final dob = _selectedDate != null
        ? '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
        : '';

    // Chỉ gửi nếu có đủ dữ liệu
    final height = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;

    final result = await ApiService.instance.updateProfile(
      gender: gender,
      dob: dob,
      height: height,
      weight: weight,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackBar(result['message'], const Color(0xFF43A047));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } else {
      _showSnackBar(result['message'], Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required String suffix,
    IconData? icon,
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: icon != null ? Icon(icon) : null,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Vui lòng nhập ${label.toLowerCase()}';
            }
            final parsed = double.tryParse(v.trim());
            if (parsed == null || parsed <= 0) {
              return 'Phải là số dương';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SkyBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      20 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Thiết lập hồ sơ',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Để tính toán chỉ số chính xác hơn, hãy hoàn tất các thông tin dưới đây',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('Giới tính*'),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _setGender('Nam'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            _selectedGender == 'Nam'
                                            ? Colors.green.shade50
                                            : Colors.transparent,
                                      ),
                                      child: const Text('Nam'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _setGender('Nữ'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: _selectedGender == 'Nữ'
                                            ? Colors.green.shade50
                                            : Colors.transparent,
                                      ),
                                      child: const Text('Nữ'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildLabel('Ngày sinh*'),
                                  InkWell(
                                    onTap: _pickDate,
                                    child: IgnorePointer(
                                      child: TextFormField(
                                        controller: _dobController,
                                        keyboardType: TextInputType.datetime,
                                        decoration: const InputDecoration(
                                          hintText: 'DD/MM/YYYY',
                                          prefixIcon: Icon(
                                            Icons.calendar_month,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Vui lòng chọn ngày sinh';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildNumberField(
                                label: 'Chiều cao*',
                                placeholder: 'Nhập chiều cao',
                                controller: _heightController,
                                suffix: 'cm',
                                focusNode: _heightFocusNode,
                                onSubmitted: () =>
                                    _weightFocusNode.requestFocus(),
                              ),
                              const SizedBox(height: 16),
                              _buildNumberField(
                                label: 'Cân nặng*',
                                placeholder: 'Nhập cân nặng',
                                controller: _weightController,
                                suffix: 'kg',
                                focusNode: _weightFocusNode,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSubmit,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Text('Hoàn tất & Bắt đầu'),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const DashboardScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text('Bỏ qua, cập nhật sau'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
