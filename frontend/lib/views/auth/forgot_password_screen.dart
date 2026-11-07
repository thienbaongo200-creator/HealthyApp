import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/app_card.dart';
import 'package:frontend/widgets/primary_button.dart';
import 'package:frontend/widgets/section_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _api = ApiService();
  bool _codeRequested = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeRequested = true);
      _message('Nếu email tồn tại, mã xác nhận đã được gửi.');
    } on ApiException catch (error) {
      _message(error.message, isError: true);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.resetPassword(
        email: _email.text.trim(),
        otp: _otp.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      _message('Mật khẩu đã được cập nhật.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      _message(error.message, isError: true);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: _codeRequested ? 'Đặt mật khẩu mới' : 'Quên mật khẩu?',
                    subtitle: _codeRequested
                        ? 'Nhập mã trong email và tạo mật khẩu mới.'
                        : 'Nhập email đăng ký để nhận mã xác nhận.',
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  TextFormField(
                    controller: _email,
                    enabled: !_codeRequested,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.contains('@') ? null : 'Nhập email hợp lệ.';
                    },
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mã xác nhận'),
                      validator: (value) => (value?.trim().length ?? 0) == 6
                          ? null
                          : 'Mã xác nhận gồm 6 chữ số.',
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Mật khẩu cần ít nhất 8 ký tự.',
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Mật khẩu nhập lại chưa khớp.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x5),
                  PrimaryButton(
                    label: _codeRequested ? 'Cập nhật mật khẩu' : 'Gửi mã xác nhận',
                    icon: _codeRequested ? Icons.lock_reset : Icons.mark_email_read_outlined,
                    isLoading: _loading,
                    onPressed: _loading
                        ? null
                        : (_codeRequested ? _resetPassword : _requestCode),
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: AppSpacing.x2),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _codeRequested = false);
                              await _requestCode();
                            },
                      child: Text(
                        'Gửi lại mã',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
