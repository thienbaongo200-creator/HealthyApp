import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/views/auth/login_screen.dart';
import 'package:frontend/app_theme.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/services/api_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  validateApiBaseUrl();
  runApp(const HealthApp());
}

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  State<HealthApp> createState() => _HealthAppState();
}

class _HealthAppState extends State<HealthApp> {
  final ProfileSelectionController _profileSelection =
      ProfileSelectionController();

  @override
  void dispose() {
    _profileSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSelectionScope(
      controller: _profileSelection,
      child: MaterialApp(
        title: 'Healthy App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.light,
        themeMode: ThemeMode.light,
        supportedLocales: const [Locale('en', 'US'), Locale('vi', 'VN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const LoginScreen(),
      ),
    );
  }
}
