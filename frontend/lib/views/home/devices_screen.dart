import 'package:flutter/material.dart';
import 'package:frontend/widgets/widgets.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    super.key,
    required this.isWatchConnected,
    required this.pendingMeasurements,
    required this.onSync,
  });

  final bool isWatchConnected;
  final int pendingMeasurements;
  final Future<void> Function() onSync;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    if (!widget.isWatchConnected) {
      _showMessage('Hãy kết nối đồng hồ trước khi đồng bộ.');
      return;
    }
    if (widget.pendingMeasurements == 0) {
      _showMessage('Không có dữ liệu đang chờ đồng bộ.');
      return;
    }

    setState(() => _isSyncing = true);
    try {
      await widget.onSync();
      if (mounted) {
        _showMessage('Đã chạy đồng bộ. Dữ liệu chưa gửi được sẽ được giữ để thử lại.');
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

  void _pairDevice() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ghép nối thiết bị mới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Để đồng hồ Wear OS gửi dữ liệu, hãy mở ứng dụng Healthy trên đồng hồ và kết nối điện thoại cùng mạng Wi-Fi.',
                style: TextStyle(color: Color(0xFF687875), height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    return GlassCard(
      padding: const EdgeInsets.all(18),
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
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7D8B88),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              status,
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFE8EFED)),
          ),
          ...details,
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFF82908D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFF687875), fontSize: 12),
              ),
            ),
            Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _statusPill({required bool active, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE7F5EF) : const Color(0xFFF0F3F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 7,
              color: active ? const Color(0xFF39A477) : const Color(0xFF9AA6A3),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF318461) : const Color(0xFF7D8987),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final connected = widget.isWatchConnected;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Thiết bị kết nối',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety_outlined, color: _teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected
                            ? 'Đồng hồ đang gửi dữ liệu sức khỏe.'
                            : 'Kết nối đồng hồ để cập nhật dữ liệu sức khỏe.',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _deviceCard(
                icon: Icons.watch_rounded,
                iconColor: const Color(0xFF557AC4),
                title: 'Galaxy Watch',
                subtitle: 'Wear OS · Đồng hồ thông minh',
                status: _statusPill(
                  active: connected,
                  label: connected ? 'Đã kết nối' : 'Chưa kết nối',
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
                    gradientColors: const [Color(0xFF32A88D), Color(0xFF168B83)],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _deviceCard(
                icon: Icons.phone_iphone_rounded,
                iconColor: const Color(0xFF4B9C7A),
                title: 'Điện thoại chủ',
                subtitle: 'Flutter Mobile App',
                status: _statusPill(active: true, label: 'Thiết bị này'),
                details: [
                  _detailRow(Icons.verified_outlined, 'Ứng dụng', 'Healthy App'),
                  _detailRow(Icons.sync_alt_rounded, 'Nhận dữ liệu từ đồng hồ', 'Cổng 8080'),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _pairDevice,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('+ Ghép nối thiết bị mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  backgroundColor: Colors.white.withValues(alpha: .75),
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Color(0xFFB8DAD5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 12,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Trang chủ', onTap: () => Navigator.pop(context)),
              _navItem(Icons.menu_book_rounded, 'Nhật ký'),
              const SizedBox(width: 55),
              _navItem(Icons.chat_bubble_outline_rounded, 'Tư vấn'),
              _navItem(Icons.watch_outlined, 'Thiết bị', selected: true),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMessage('Ghi nhận chỉ số sẽ sớm được bổ sung.'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap ?? () => _showMessage('$label sẽ được bổ sung sau.'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? _teal : const Color(0xFF9AA6A3),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? _teal : const Color(0xFF9AA6A3),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}
