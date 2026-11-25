import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/error_mapper.dart';
import 'package:frontend/widgets/app_card.dart';
import 'package:frontend/widgets/primary_button.dart';
import 'package:frontend/widgets/section_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.apiService});

  @visibleForTesting
  final ApiService? apiService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  bool _codeRequested = false;
  bool _loading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  ApiService get _api => widget.apiService ?? ApiService();

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_emailFieldKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _api.requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeRequested = true);
      _startResendCountdown();
      _message('Nếu email tồn tại, mã xác nhận đã được gửi.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 429) {
        _startResendCountdown();
        _message(
          'Bạn đã yêu cầu quá nhiều lần, vui lòng thử lại sau ít phút.',
          isError: true,
        );
      } else {
        _message(ErrorMapper.toUserMessage(error.message), isError: true);
      }
    } catch (_) {
      if (!mounted) return;
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
      if (!mounted) return;
      _message(
        error.statusCode == 429
            ? 'Bạn đã yêu cầu quá nhiều lần, vui lòng thử lại sau ít phút.'
            : ErrorMapper.toUserMessage(error.message),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _message('Không thể kết nối máy chủ. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
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
                    title: _codeRequested
                        ? 'Đặt mật khẩu mới'
                        : 'Quên mật khẩu?',
                    subtitle: _codeRequested
                        ? 'Nhập mã 6 chữ số và mật khẩu mới bên dưới. Các thông tin sẽ được xác nhận cùng lúc.'
                        : 'Nhập email đăng ký để nhận mã xác nhận.',
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  TextFormField(
                    key: _emailFieldKey,
                    controller: _email,
                    enabled: !_codeRequested,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Vui lòng nhập email.';
                      return RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)
                          ? null
                          : 'Nhập email hợp lệ.';
                    },
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      'Mã OTP',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    FormField<String>(
                      validator: (_) => _otp.text.length == 6
                          ? null
                          : 'Mã xác nhận gồm 6 chữ số.',
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OtpInput(controller: _otp, hasError: field.hasError),
                          if (field.hasError) ...[
                            const SizedBox(height: 8),
                            Text(
                              field.errorText!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới',
                      ),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Mật khẩu cần ít nhất 8 ký tự.',
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Mật khẩu nhập lại chưa khớp.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x5),
                  PrimaryButton(
                    label: _codeRequested
                        ? 'Cập nhật mật khẩu'
                        : _resendSeconds > 0
                        ? 'Gửi mã sau $_resendSeconds giây'
                        : 'Gửi mã xác nhận',
                    icon: _codeRequested
                        ? Icons.lock_reset
                        : Icons.mark_email_read_outlined,
                    isLoading: _loading,
                    onPressed:
                        _loading || (!_codeRequested && _resendSeconds > 0)
                        ? null
                        : (_codeRequested ? _resetPassword : _requestCode),
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: AppSpacing.x2),
                    TextButton(
                      onPressed: _loading || _resendSeconds > 0
                          ? null
                          : _requestCode,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Gửi lại mã sau $_resendSeconds giây'
                            : 'Gửi lại mã',
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

class _OtpInput extends StatefulWidget {
  const _OtpInput({required this.controller, required this.hasError});

  final TextEditingController controller;
  final bool hasError;

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final boxWidth = (constraints.maxWidth - gap * 5) / 6;
        return SizedBox(
          height: 54,
          child: Stack(
            children: [
              Row(
                children: List.generate(6, (index) {
                  final character = index < widget.controller.text.length
                      ? widget.controller.text[index]
                      : '';
                  final isActive =
                      _focusNode.hasFocus &&
                      index == widget.controller.text.length.clamp(0, 5);
                  return Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : gap),
                    child: Container(
                      key: Key('otp-digit-$index'),
                      width: boxWidth,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.hasError
                              ? AppColors.danger
                              : isActive
                              ? AppColors.primary
                              : AppColors.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        character,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: TextField(
                  key: const Key('otp-input'),
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                  ),
                  cursorColor: Colors.transparent,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
