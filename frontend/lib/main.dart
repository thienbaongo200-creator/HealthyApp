import 'package:flutter/material.dart';
import 'package:frontend/views/auth/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthy App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const LoginScreen(),
    );
  }
}

// Widget trung gian kiểm tra trạng thái đăng nhập
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _checkLoginStatus() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'access_token');
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        // Đang chờ đọc bộ nhớ bảo mật
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        // Nếu đã có token -> Vào thẳng màn hình chính
        if (snapshot.hasData && snapshot.data == true) {
          return const Scaffold(
            body: Center(child: Text("Đã đăng nhập - Chuyển vào HomeScreen")),
          ); // Thay bằng HomeScreen() của bạn
        }

        // Nếu chưa có token -> Vào màn hình Login
        return const LoginScreen();
      },
    );
  }
}
