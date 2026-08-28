import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/api_service.dart';
import '../../widgets/sky_background.dart';
import '../../widgets/gradient_button.dart';
import 'profile_setup_screen.dart';
import 'register_screen.dart';

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

    String inputAccount = _accountController.text.trim();
    String password = _passwordController.text;

    try {
      final String? token = await _apiService.login(inputAccount, password);
      if (token != null) {
        _apiService.setToken(token);
        _showSnackBar('Đăng nhập thành công!', const Color(0xFF43A047));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        }
      } else {
        _showSnackBar(
          'Tài khoản hoặc mật khẩu không chính xác!',
          Colors.redAccent,
        );
      }
    } catch (e) {
      _showSnackBar('Mất kết nối server hoặc lỗi hệ thống!', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        _showSnackBar('Đăng nhập Google đã bị hủy!', Colors.orangeAccent);
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        _showSnackBar(
          'Không thể lấy access token từ Google!',
          Colors.redAccent,
        );
        return;
      }
      final String? token = await _apiService.loginWithGoogle(accessToken);
      if (token != null) {
        _apiService.setToken(token);
        _showSnackBar('Đăng nhập Google thành công!', const Color(0xFF43A047));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        }
      } else {
        _showSnackBar('Đăng nhập Google thất bại!', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Lỗi đăng nhập Google', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleFacebookSignIn() {
    _showSnackBar(
      'Tính năng đăng nhập Facebook đang phát triển',
      Colors.orangeAccent,
    );
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
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // 🌿 Logo
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Image.asset(
                              'lib/assets/images/heartbeat.png',
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
                              color: const Color(
                                0xFF66BB6A,
                              ).withValues(alpha: 0.7),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Icon(
                              Icons.spa,
                              size: 14,
                              color: const Color(
                                0xFF81C784,
                              ).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🌿 Tiêu đề có đường kẻ hai bên giống thiết kế
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: const Color(0xFF558B2F).withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Chào mừng đến với',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(
                              0xFF558B2F,
                            ).withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: const Color(0xFF558B2F).withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ứng dụng sức khỏe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý sức khỏe của bạn\nđều đặn và hiệu quả',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF558B2F).withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 🌿 Ô nhập Tài khoản (Email hoặc số điện thoại)
                  TextFormField(
                    controller: _accountController,
                    focusNode: _accountFocusNode,
                    style: const TextStyle(color: Color(0xFF33691E)),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'Email hoặc số điện thoại',
                      hintText: 'Nhập email hoặc số điện thoại',
                      hintStyle: TextStyle(
                        color: const Color(0xFFA5D6A7).withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => v!.trim().isEmpty
                        ? 'Vui lòng nhập email hoặc số điện thoại'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 🌿 Ô nhập Mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Color(0xFF33691E)),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu',
                      hintStyle: TextStyle(
                        color: const Color(0xFFA5D6A7).withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFF81C784),
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
                      onPressed: () {
                        _showSnackBar(
                          'Tính năng đang phát triển',
                          const Color(0xFF66BB6A),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: Color(0xFF42A5F5),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 🌿 Nút Đăng nhập bo tròn (Pill shape)
                  SizedBox(
                    height: 50,
                    child: GradientButton(
                      label: 'Đăng nhập',
                      icon: Icons.login_rounded,
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🌿 Đường kẻ "Hoặc"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: const Color(0xFFA5D6A7).withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Hoặc',
                          style: TextStyle(
                            color: const Color(0xFF558B2F),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: const Color(0xFFA5D6A7).withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🌿 Nút mạng xã hội (Facebook & Google)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleFacebookSignIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: const Color(
                                0xFFA5D6A7,
                              ).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.facebook,
                                color: Color(0xFF1877F2),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đăng nhập với Facebook',
                                style: TextStyle(
                                  color: Color(0xFF33691E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: const Color(
                                0xFFA5D6A7,
                              ).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata,
                                color: Colors.redAccent,
                                size: 24,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Đăng nhập với Google',
                                style: TextStyle(
                                  color: Color(0xFF33691E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🌿 Chuyển hướng Đăng ký gọn gàng ở dưới cùng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(
                          color: const Color(0xFF558B2F).withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
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
                        child: const Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
