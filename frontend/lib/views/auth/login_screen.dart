import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import 'profile_setup_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../home/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final _accountFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _accountFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    ProfileSelectionScope.of(context).clear();

    String inputAccount = _accountController.text.trim();
    String password = _passwordController.text;

    try {
      final token = await _apiService.login(inputAccount, password);
      await _apiService.setToken(token);
      // Drop cached profiles before fetching the newly authenticated account.
      ProfileSelectionScope.of(context).clear();
      _showSnackBar('Đăng nhập thành công!', AppColors.success);
      final profileComplete = await ApiService.isCurrentProfileComplete();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => profileComplete
                ? const DashboardScreen()
                : const ProfileSetupScreen(),
          ),
        );
      }
    } on ApiException catch (e, stackTrace) {
      developer.log(
        'Login API returned HTTP ${e.statusCode}: ${e.message}',
        name: 'LoginScreen',
        level: 900,
        error: e,
        stackTrace: stackTrace,
      );
      if (e.statusCode == 401) {
        _showSnackBar(
          'Tài khoản hoặc mật khẩu không chính xác!',
          AppColors.danger,
        );
      } else {
        _showSnackBar(
          'Server trả về lỗi HTTP ${e.statusCode}.',
          AppColors.danger,
        );
      }
    } on SocketException catch (e, stackTrace) {
      developer.log(
        'Login socket error: $e',
        name: 'LoginScreen',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _showSnackBar(
        'Không kết nối được server. Kiểm tra IP, Wi-Fi và firewall.',
        AppColors.danger,
      );
    } on TimeoutException catch (e, stackTrace) {
      developer.log(
        'Login timed out: $e',
        name: 'LoginScreen',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _showSnackBar(
        'Server không phản hồi trong thời gian chờ.',
        AppColors.danger,
      );
    } on http.ClientException catch (e, stackTrace) {
      developer.log(
        'Login HTTP client error: $e',
        name: 'LoginScreen',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _showSnackBar(
        'Lỗi HTTP client. Xem log để biết chi tiết.',
        AppColors.danger,
      );
    } on FormatException catch (e, stackTrace) {
      developer.log(
        'Invalid login API response: $e',
        name: 'LoginScreen',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _showSnackBar('Server trả về dữ liệu không hợp lệ.', AppColors.danger);
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected login error: $e',
        name: 'LoginScreen',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _showSnackBar('Lỗi không xác định khi đăng nhập.', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SkyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x6,
              AppSpacing.x4,
              AppSpacing.x6,
              AppSpacing.x4 + MediaQuery.of(context).viewInsets.bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.x3),
                    // 🌿 Logo
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.surface.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/images/heartbeat.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 10,
                              child: Icon(
                                Icons.eco,
                                size: 18,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Icon(
                                Icons.spa,
                                size: 14,
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    // 🌿 Tiêu đề có đường kẻ hai bên giống thiết kế
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: AppColors.border, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x3,
                          ),
                          child: Text(
                            'Chào mừng đến với',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: AppColors.border, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Ứng dụng sức khỏe',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Quản lý sức khỏe của bạn\nđều đặn và hiệu quả',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x8),

                    // 🌿 Ô nhập Tài khoản (Email hoặc số điện thoại)
                    TextFormField(
                      controller: _accountController,
                      focusNode: _accountFocusNode,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.all(AppSpacing.x4),
                        labelText: 'Email hoặc số điện thoại',
                        hintText: 'Nhập email hoặc số điện thoại',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1,
                          ),
                        ),
                      ),
                      validator: (v) => v!.trim().isEmpty
                          ? 'Vui lòng nhập email hoặc số điện thoại'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x5),

                    // 🌿 Ô nhập Mật khẩu
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: !_isPasswordVisible,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.all(AppSpacing.x4),
                        labelText: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                    ),

                    // Quên mật khẩu
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x2,
                          ),
                        ),
                        child: Text(
                          'Quên mật khẩu?',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),

                    // 🌿 Nút Đăng nhập bo tròn (Pill shape)
                    SizedBox(
                      height: 48,
                      child: PrimaryButton(
                        label: 'Đăng nhập',
                        icon: Icons.login_rounded,
                        onPressed: _isLoading ? null : _handleLogin,
                        isLoading: _isLoading,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    // 🌿 Đường kẻ "Hoặc"

                    // 🌿 Chuyển hướng Đăng ký gọn gàng ở dưới cùng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản? ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Đăng ký ngay',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
