import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/sky_background.dart';
import '../../widgets/gradient_button.dart';
import 'profile_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await ApiService.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSnackBar(result['message'] as String, const Color(0xFF43A047));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
      );
    } else {
      _showSnackBar(result['message'] as String, Colors.redAccent);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SkyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // 🌿 Icon + Tiêu đề
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 40,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Tạo tài khoản mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đăng ký để trải nghiệm chăm sóc sức khỏe xanh 🌿',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF558B2F).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 🌿 Card form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Username
                        TextFormField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          style: const TextStyle(color: Color(0xFF33691E)),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _emailFocusNode.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Tên đăng nhập',
                            hintText: 'Nhập username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v!.trim().isEmpty
                              ? 'Vui lòng nhập tên đăng nhập'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          style: const TextStyle(color: Color(0xFF33691E)),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email liên hệ',
                            hintText: 'example@email.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => !v!.contains('@')
                              ? 'Định dạng Email không hợp lệ'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Mật khẩu
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Color(0xFF33691E)),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _confirmPasswordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            hintText: 'Ít nhất 6 ký tự',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              }),
                            ),
                          ),
                          validator: (v) => v!.length < 6
                              ? 'Mật khẩu phải từ 6 ký tự trở lên'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Xác nhận mật khẩu
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          obscureText: !_isConfirmPasswordVisible,
                          style: const TextStyle(color: Color(0xFF33691E)),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            hintText: 'Nhập lại mật khẩu',
                            prefixIcon: const Icon(Icons.lock_clock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              }),
                            ),
                          ),
                          validator: (v) => v != _passwordController.text
                              ? 'Mật khẩu xác nhận không khớp'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        // Nút Đăng ký Gradient
                        GradientButton(
                          label: 'Đăng ký ngay',
                          icon: Icons.check_circle_outline,
                          onPressed: _isLoading ? null : _handleRegister,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quay lại đăng nhập
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(
                          color: const Color(0xFF558B2F).withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8F5E9,
                            ).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
