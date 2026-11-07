import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/views/auth/login_screen.dart';
import 'package:frontend/widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();
  static const _ink = AppColors.textPrimary;
  static const _teal = AppColors.primary;
  static const _remindersKey = 'health_reminders_enabled';

  bool _remindersEnabled = true;
  bool _aiConsentEnabled = false;
  bool _isLoading = true;
  bool _isLoadingAiConsent = true;
  bool _isUpdatingAiConsent = false;
  bool _isLoggingOut = false;
  List<Map<String, dynamic>> _consentProfiles = [];
  String? _consentProfileId;

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
      final profiles = await ApiService.fetchProfiles();
      final manageable = profiles
          .where((profile) {
            return isCurrentUserProfile(profile) ||
                profile['viewer_role'] == 'OWNER';
          })
          .toList(growable: false);
      final selected =
          manageable.where(isCurrentUserProfile).firstOrNull ??
          manageable.firstOrNull;
      if (selected == null) throw StateError('Không có hồ sơ được quản lý.');
      final profileId = selected['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        throw const FormatException('Hồ sơ không có ID hợp lệ.');
      }
      final consent = await ApiService.fetchAiConsent(profileId: profileId);
      if (mounted) {
        setState(() {
          _consentProfiles = manageable;
          _consentProfileId = profileId;
          _aiConsentEnabled = consent;
        });
      }
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
    final profileId = _consentProfileId;
    if (_isUpdatingAiConsent || profileId == null) return;
    setState(() => _isUpdatingAiConsent = true);
    try {
      final consent = await ApiService.updateAiConsent(
        profileId: profileId,
        consent: value,
      );
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
      errorMessage =
          'Không thể thu hồi phiên trên máy chủ; token cục bộ đã bị xóa.';
    }
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: Text('Cài đặt', style: Theme.of(context).textTheme.titleLarge),
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: _ink),
      ),
    ),
    body: SkyBackground(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            const SectionHeader(title: 'Tùy chọn ứng dụng'),
            const SizedBox(height: AppSpacing.x3),
            AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile.adaptive(
                value: _remindersEnabled,
                onChanged: _isLoading ? null : _setRemindersEnabled,
                activeTrackColor: _teal,
                secondary: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Nhắc nhở sức khỏe'),
                subtitle: const Text('Lưu tùy chọn trên thiết bị này.'),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            const SectionHeader(title: 'Quyền riêng tư & AI'),
            const SizedBox(height: AppSpacing.x3),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: _teal),
                      SizedBox(width: AppSpacing.x2),
                      Expanded(
                        child: Text(
                          'Dữ liệu sức khỏe được gửi tới máy chủ HealthyApp khi bạn đồng bộ.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_consentProfiles.length > 1) ...[
                    const SizedBox(height: AppSpacing.x2),
                    DropdownButtonFormField<String>(
                      initialValue: _consentProfileId,
                      decoration: const InputDecoration(
                        labelText: 'Hồ sơ áp dụng consent',
                      ),
                      items: _consentProfiles
                          .map((profile) {
                            final id = profile['id']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(profileDisplayName(profile)),
                            );
                          })
                          .toList(growable: false),
                      onChanged: _isLoadingAiConsent || _isUpdatingAiConsent
                          ? null
                          : (id) async {
                              if (id == null) return;
                              setState(() {
                                _consentProfileId = id;
                                _isLoadingAiConsent = true;
                              });
                              try {
                                final consent = await ApiService.fetchAiConsent(
                                  profileId: id,
                                );
                                if (mounted) {
                                  setState(() => _aiConsentEnabled = consent);
                                }
                              } catch (_) {
                                if (mounted) {
                                  _showMessage('Không thể tải consent hồ sơ.');
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoadingAiConsent = false);
                                }
                              }
                            },
                    ),
                  ],
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _aiConsentEnabled,
                    onChanged:
                        _isLoadingAiConsent ||
                            _isUpdatingAiConsent ||
                            _consentProfileId == null
                        ? null
                        : _setAiConsent,
                    activeTrackColor: _teal,
                    secondary: _isUpdatingAiConsent
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.psychology_alt_outlined,
                            color: _teal,
                          ),
                    title: const Text('Cho phép phân tích bằng Trợ lý AI'),
                    subtitle: Text(
                      _isLoadingAiConsent
                          ? 'Đang tải trạng thái đồng ý...'
                          : _aiConsentEnabled
                          ? 'Có thể dùng chat và đánh giá nguy cơ cho hồ sơ bạn được quyền xem.'
                          : 'Chat và đánh giá nguy cơ bị tắt cho đến khi bạn đồng ý.',
                    ),
                  ),
                  StatusBadge(
                    label: _isLoadingAiConsent
                        ? 'Đang tải trạng thái'
                        : _aiConsentEnabled
                        ? 'Đã cho phép phân tích'
                        : 'Phân tích đang tắt',
                    tone: _aiConsentEnabled
                        ? StatusTone.success
                        : StatusTone.neutral,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Tư vấn hiện dùng quy tắc xử lý ở backend; chưa kết nối nhà cung cấp AI bên ngoài. Bạn có thể thu hồi đồng ý bất cứ lúc nào. Nội dung chỉ tham khảo, không thay thế chẩn đoán của nhân viên y tế.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              height: 48,
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
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.dangerSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
