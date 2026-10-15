import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/views/auth/login_screen.dart';
import 'package:frontend/widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();
  static const _ink = Color(0xFF18343A);
  static const _teal = Color(0xFF168B83);
  static const _remindersKey = 'health_reminders_enabled';

  bool _remindersEnabled = true;
  bool _aiConsentEnabled = false;
  bool _isLoading = true;
  bool _isLoadingAiConsent = true;
  bool _isUpdatingAiConsent = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAiConsent();
  }

  Future<void> _loadSettings() async {
    final value = await _storage.read(key: _remindersKey);
    if (!mounted) return;
    setState(() {
      _remindersEnabled = value != 'false';
      _isLoading = false;
    });
  }

  Future<void> _setRemindersEnabled(bool value) async {
    await _storage.write(key: _remindersKey, value: value.toString());
    if (mounted) setState(() => _remindersEnabled = value);
  }

  Future<void> _loadAiConsent() async {
    try {
      final consent = await ApiService.fetchAiConsent();
      if (mounted) setState(() => _aiConsentEnabled = consent);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException ? error.message : 'Không thể tải tùy chọn AI.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAiConsent = false);
    }
  }

  Future<void> _setAiConsent(bool value) async {
    if (_isUpdatingAiConsent) return;
    setState(() => _isUpdatingAiConsent = true);
    try {
      final consent = await ApiService.updateAiConsent(value);
      if (mounted) setState(() => _aiConsentEnabled = consent);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException
              ? error.message
              : 'Không thể cập nhật tùy chọn AI.',
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAiConsent = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    String? errorMessage;
    try {
      await ApiService.logout();
    } catch (_) {
      errorMessage = 'Không thể thu hồi phiên trên máy chủ; token cục bộ đã bị xóa.';
    }
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F9F8),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Cài đặt',
        style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: _ink),
      ),
    ),
    body: SkyBackground(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tùy chọn ứng dụng',
              style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile.adaptive(
                value: _remindersEnabled,
                onChanged: _isLoading ? null : _setRemindersEnabled,
                activeTrackColor: _teal,
                secondary: const Icon(Icons.notifications_active_outlined, color: _teal),
                title: const Text('Nhắc nhở sức khỏe'),
                subtitle: const Text('Lưu tùy chọn trên thiết bị này.'),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Quyền riêng tư & AI',
              style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: _teal),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dữ liệu sức khỏe được gửi tới máy chủ HealthyApp khi bạn đồng bộ.',
                          style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _aiConsentEnabled,
                    onChanged: _isLoadingAiConsent || _isUpdatingAiConsent
                        ? null
                        : _setAiConsent,
                    activeTrackColor: _teal,
                    secondary: _isUpdatingAiConsent
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_outlined, color: _teal),
                    title: const Text('Cho phép phân tích bằng Trợ lý AI'),
                    subtitle: Text(
                      _isLoadingAiConsent
                          ? 'Đang tải trạng thái đồng ý...'
                          : _aiConsentEnabled
                          ? 'Có thể dùng chat và đánh giá nguy cơ cho hồ sơ bạn được quyền xem.'
                          : 'Chat và đánh giá nguy cơ bị tắt cho đến khi bạn đồng ý.',
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tư vấn hiện dùng quy tắc xử lý ở backend; chưa kết nối nhà cung cấp AI bên ngoài. Bạn có thể thu hồi đồng ý bất cứ lúc nào. Nội dung chỉ tham khảo, không thay thế chẩn đoán của nhân viên y tế.',
                    style: TextStyle(color: Color(0xFF687875), height: 1.45, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB64B4B),
                  side: const BorderSide(color: Color(0xFFE6C9C9)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
