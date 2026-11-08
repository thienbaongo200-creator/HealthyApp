import 'package:flutter/material.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'main_navigation_wrapper.dart';
import 'quick_add_screen.dart';
import 'package:frontend/widgets/widgets.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/watch_sync_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    super.key,
    required this.isWatchConnected,
    required this.pendingMeasurements,
    required this.onSync,
    this.profileId,
    this.member = 'Tôi',
  });

  final bool isWatchConnected;
  final int pendingMeasurements;
  final Future<void> Function() onSync;
  final String? profileId;
  final String member;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const _teal = AppColors.primary;
  static const _ink = AppColors.textPrimary;
  static const _storage = FlutterSecureStorage();
  bool _isSyncing = false;
  String? _pairedDeviceId;
  String? _profileId;
  int _deviceRequestId = 0;
  ProfileSelectionController? _profileSelection;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId;
    _loadPairedDevice();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = ProfileSelectionScope.of(context);
    if (identical(selection, _profileSelection)) return;
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    _profileSelection = selection;
    final selectedProfileId = selection.selectedProfileId;
    if (selectedProfileId != null && selectedProfileId != _profileId) {
      _profileId = selectedProfileId;
      _pairedDeviceId = null;
      _loadPairedDevice();
    }
    selection.addListener(_onProfileSelectionChanged);
  }

  String get _member {
    final profile = _profileSelection?.selectedProfile;
    return profile == null ? widget.member : profileDisplayName(profile);
  }

  void _onProfileSelectionChanged() {
    final profileId = _profileSelection?.selectedProfileId;
    if (!mounted || profileId == null || profileId == _profileId) return;
    setState(() {
      _profileId = profileId;
      _pairedDeviceId = null;
    });
    _loadPairedDevice();
  }

  @override
  void dispose() {
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    super.dispose();
  }

  Future<void> _loadPairedDevice() async {
    final requestId = ++_deviceRequestId;
    final id = _profileId;
    if (id == null) {
      if (mounted) setState(() => _pairedDeviceId = null);
      return;
    }
    final value = await _storage.read(key: 'paired_device_$id');
    if (!mounted || requestId != _deviceRequestId || id != _profileId) return;
    if (mounted) setState(() => _pairedDeviceId = value);
  }

  Future<void> _syncNow() async {
    if (widget.pendingMeasurements == 0) {
      _showMessage('Không có dữ liệu đang chờ đồng bộ.');
      return;
    }

    setState(() => _isSyncing = true);
    try {
      await widget.onSync();
      if (mounted) {
        _showMessage(
          'Đã chạy đồng bộ. Dữ liệu chưa gửi được sẽ được giữ để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pairDevice() async {
    final profileId = _profileId;
    if (profileId == null) {
      _showMessage('Chọn hồ sơ trước khi ghép nối thiết bị.');
      return;
    }
    final identifier = TextEditingController(text: watchDeviceIdentifier);
    final name = TextEditingController(text: 'Wear OS');
    final details = await showDialog<({String identifier, String name})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ghép nối thiết bị'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: identifier,
              decoration: const InputDecoration(
                labelText: 'Mã thiết bị',
                helperText: 'Phải trùng WATCH_DEVICE_IDENTIFIER của Wear OS.',
              ),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên thiết bị'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              identifier: identifier.text.trim(),
              name: name.text.trim(),
            )),
            child: const Text('Ghép nối'),
          ),
        ],
      ),
    );
    identifier.dispose();
    name.dispose();
    if (details == null || details.identifier.isEmpty) return;
    try {
      final device = await ApiService.pairDevice(
        profileId: profileId,
        identifier: details.identifier,
        name: details.name,
      );
      final deviceId = device['id']?.toString();
      if (deviceId == null || deviceId.isEmpty) {
        throw const FormatException('Device API did not return an ID.');
      }
      await _storage.write(key: 'paired_device_$profileId', value: deviceId);
      await _storage.write(
        key: 'paired_device_identifier_$profileId',
        value: details.identifier,
      );
      if (mounted && profileId == _profileId) {
        setState(() => _pairedDeviceId = deviceId);
        _showMessage('Thiết bị đã ghép với hồ sơ.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException ? error.message : 'Ghép nối thất bại.',
        );
      }
    }
  }

  Widget _deviceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget status,
    required List<Widget> details,
    Widget? footer,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              status,
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
            child: Divider(height: 1, color: AppColors.border),
          ),
          ...details,
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.x4),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.x3),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _statusPill({required bool active, required String label}) =>
      StatusBadge(
        label: label,
        tone: active ? StatusTone.success : StatusTone.neutral,
        icon: Icons.circle,
      );

  @override
  Widget build(BuildContext context) {
    final connected = widget.isWatchConnected;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Thiết bị kết nối',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x6,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety_outlined, color: _teal),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        connected
                            ? 'Đồng hồ đang gửi dữ liệu sức khỏe.'
                            : 'Kết nối đồng hồ để cập nhật dữ liệu sức khỏe.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _deviceCard(
                icon: Icons.watch_rounded,
                iconColor: AppColors.primary,
                title: 'Galaxy Watch',
                subtitle: _pairedDeviceId == null
                    ? 'Wear OS · Chưa ghép với hồ sơ'
                    : 'Wear OS · Đã ghép nối',
                status: _statusPill(
                  active: connected,
                  label: _pairedDeviceId != null
                      ? 'Đã ghép nối'
                      : connected
                      ? 'Đã kết nối'
                      : 'Chưa kết nối',
                ),
                details: [
                  _detailRow(
                    Icons.bluetooth_connected,
                    'Trạng thái kết nối',
                    connected ? 'Đang hoạt động' : 'Đang chờ đồng hồ',
                  ),
                  _detailRow(
                    Icons.battery_unknown_outlined,
                    'Pin đồng hồ',
                    'Chưa nhận dữ liệu pin',
                  ),
                  _detailRow(
                    Icons.cloud_sync_outlined,
                    'Bản ghi chờ gửi',
                    '${widget.pendingMeasurements}',
                  ),
                ],
                footer: SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: _isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ ngay',
                    icon: Icons.sync_rounded,
                    onPressed: _isSyncing ? null : _syncNow,
                    isLoading: _isSyncing,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _deviceCard(
                icon: Icons.phone_iphone_rounded,
                iconColor: AppColors.primary,
                title: 'Điện thoại chủ',
                subtitle: 'Flutter Mobile App',
                status: _statusPill(active: true, label: 'Thiết bị này'),
                details: [
                  _detailRow(
                    Icons.verified_outlined,
                    'Ứng dụng',
                    'Healthy App',
                  ),
                  _detailRow(
                    Icons.sync_alt_rounded,
                    'Nhận dữ liệu từ đồng hồ',
                    'Cổng 8080',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              OutlinedButton.icon(
                onPressed: _pairDevice,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(
                  _pairedDeviceId == null
                      ? '+ Ghép nối thiết bị mới'
                      : 'Ghép lại / đổi thiết bị',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  backgroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MainNavigationWrapper(
        selectedIndex: 3,
        onSelected: (index) {
          if (index == 0) {
            Navigator.pop(context);
          }
          if (index == 1 || index == 2) {
            _showMessage(index == 1 ? 'Nhật ký' : 'Tư vấn');
          }
        },
        onQuickAdd: _openQuickAdd,
      ),
    );
  }

  Future<void> _openQuickAdd() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(member: _member, profileId: _profileId),
      ),
    );
  }
}
