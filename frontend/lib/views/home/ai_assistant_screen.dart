import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/views/home/quick_add_screen.dart';
import 'package:frontend/widgets/widgets.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.initialMember = 'Tôi'});

  final String initialMember;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _self = 'Ngô Quốc Thiên Bảo (Tôi)';
  static const _quickQuestions = [
    'Tôi nên theo dõi chỉ số nào mỗi ngày?',
    'Làm sao để ngủ tốt hơn?',
    'Đi bộ bao lâu là phù hợp?',
  ];

  late final TabController _tabController;
  late String _selectedMember;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Xin chào! Mình có thể giúp bạn tìm hiểu các chỉ số sức khỏe. Bạn muốn hỏi điều gì?',
      isUser: false,
      sentAt: DateTime.now(),
    ),
  ];

  bool _isAnalyzing = false;
  bool _analysisLoaded = false;
  String? _analysisError;
  int? _measurementsInPeriod;
  int? _peakHeartRate;
  DateTime? _peakHeartRateAt;

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.initialMember == 'Tôi'
        ? _self
        : widget.initialMember;
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _analyzeNow() async {
    if (_selectedMember != _self) {
      _showMessage('API hiện chỉ tải dữ liệu của tài khoản đang đăng nhập.');
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });
    try {
      final allMeasurements = await ApiService.fetchHealthMeasurements();
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recent = <({DateTime measuredAt, int heartRate})>[];
      for (final item in allMeasurements) {
        final measuredAt = DateTime.tryParse(
          item['measured_at']?.toString() ?? '',
        )?.toLocal();
        final heartRate = (item['heart_rate'] as num?)?.toInt();
        if (measuredAt == null ||
            measuredAt.isBefore(cutoff) ||
            heartRate == null) {
          continue;
        }
        recent.add((measuredAt: measuredAt, heartRate: heartRate));
      }
      recent.sort((a, b) => b.heartRate.compareTo(a.heartRate));
      if (!mounted) return;
      setState(() {
        _analysisLoaded = true;
        _measurementsInPeriod = recent.length;
        _peakHeartRate = recent.isEmpty ? null : recent.first.heartRate;
        _peakHeartRateAt = recent.isEmpty ? null : recent.first.measuredAt;
        _isAnalyzing = false;
      });
      _showMessage('Đã tải ${recent.length} bản ghi nhịp tim trong 7 ngày gần nhất.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analysisError = 'Không thể tải dữ liệu. Hãy kiểm tra kết nối và thử lại.';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _selectMember(String member) async {
    setState(() => _selectedMember = member);
    if (member != _self) {
      setState(() {
        _analysisLoaded = false;
        _measurementsInPeriod = null;
        _peakHeartRate = null;
        _peakHeartRateAt = null;
      });
    }
  }

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _sendMessage([String? suggestedQuestion]) {
    final text = (suggestedQuestion ?? _messageController.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _messages
        ..add(_ChatMessage(text: text, isUser: true, sentAt: DateTime.now()))
        ..add(_ChatMessage(
          text: 'Trợ lý AI chưa được kết nối với mô hình xử lý. Đây là bản xem trước giao diện nên mình chưa thể phân tích câu hỏi hoặc đưa ra tư vấn cá nhân. Hãy trao đổi với nhân viên y tế khi cần hướng dẫn phù hợp.',
          isUser: false,
          sentAt: DateTime.now(),
        ));
    });
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isChatTab = _tabController.index == 1;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Trợ lý AI & Đánh giá nguy cơ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    onSelected: _selectMember,
                    itemBuilder: (context) => [
                      for (final member in [_self, 'Bố', 'Mẹ'])
                        PopupMenuItem(value: member, child: Text(member)),
                    ],
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 330),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE1EBE8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, color: _teal, size: 18),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Đang xem: $_selectedMember',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: _ink, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: _teal,
                unselectedLabelColor: const Color(0xFF84918E),
                indicatorColor: _teal,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.health_and_safety_outlined, size: 18), text: 'Đánh giá nguy cơ'),
                  Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Trợ lý AI'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [_riskTab(), _chatTab()],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChatTab) _messageComposer(),
            BottomAppBar(
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
                    _navItem(Icons.chat_bubble_outline_rounded, 'Tư vấn', selected: true),
                    _navItem(Icons.watch_outlined, 'Thiết bị'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => QuickAddScreen(member: _selectedMember),
            ),
          );
          if (saved == true && mounted) {
            _showMessage('Bản ghi đã được lưu trên thiết bị.');
          }
        },
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _riskTab() => RefreshIndicator(
        color: _teal,
        onRefresh: _analyzeNow,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            _riskOverviewCard(),
            const SizedBox(height: 13),
            _systemWarningCard(),
            const SizedBox(height: 13),
            _aiInsightCard(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _isAnalyzing ? 'Đang phân tích...' : 'Phân tích ngay',
                icon: Icons.refresh_rounded,
                isLoading: _isAnalyzing,
                onPressed: _isAnalyzing ? null : _analyzeNow,
                gradientColors: const [Color(0xFF32A88D), Color(0xFF168B83)],
                height: 52,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _riskOverviewCard() => GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TỔNG QUAN RỦI RO SỨC KHỎE',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _sampleBadge(),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF348250), size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NGUY CƠ TIM MẠCH: THẤP',
                      style: TextStyle(
                        color: Color(0xFF348250),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _analysisLoaded
                  ? 'Đã tải ${_measurementsInPeriod ?? 0} bản ghi nhịp tim trong 7 ngày. API chưa có mô hình đánh giá nguy cơ.'
                  : 'Dựa trên 14 chỉ số trong 7 ngày qua. Trạng thái ổn định.',
              style: const TextStyle(
                color: Color(0xFF687875),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (_analysisError != null) ...[
              const SizedBox(height: 8),
              Text(
                _analysisError!,
                style: const TextStyle(color: Color(0xFFB64B4B), fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Mức “Thấp” và mô tả ban đầu là nội dung mẫu theo wireframe, chưa phải kết quả y tế cá nhân.',
              style: TextStyle(
                color: Color(0xFF8A9693),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      );

  Widget _systemWarningCard() {
    final hasHighHeartRate = _analysisLoaded &&
        _peakHeartRate != null &&
        _peakHeartRate! > 120;
    final hasMeasurements = _analysisLoaded && _measurementsInPeriod != 0;
    final title = hasHighHeartRate
        ? 'Nhịp tim cao nhất: ${_peakHeartRate} bpm'
        : _analysisLoaded && hasMeasurements
            ? 'Chưa thấy nhịp tim vượt ngưỡng minh họa'
            : 'Nhịp tim vượt ngưỡng';
    final detail = hasHighHeartRate
        ? 'Ghi nhận lúc ${_timeLabel(_peakHeartRateAt!)} trong dữ liệu đã tải.'
        : _analysisLoaded
            ? (_measurementsInPeriod == 0
                ? 'Chưa có bản ghi nhịp tim trong 7 ngày gần nhất.'
                : 'Không ghi nhận nhịp tim trên 120 bpm trong 7 ngày gần nhất.')
            : 'Ví dụ wireframe: phát hiện 135 bpm lúc 14:20.';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CẢNH BÁO TỪ HỆ THỐNG',
            style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasHighHeartRate || !_analysisLoaded
                    ? Icons.warning_rounded
                    : Icons.check_circle_outline_rounded,
                color: hasHighHeartRate || !_analysisLoaded
                    ? const Color(0xFFD75858)
                    : const Color(0xFF46916A),
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _sampleBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFF687875),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gợi ý: nghỉ ngơi và tránh vận động gắng sức đột ngột. Nếu có triệu chứng đáng lo ngại, hãy liên hệ nhân viên y tế.',
                      style: TextStyle(
                        color: Color(0xFF687875),
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ngưỡng 120 bpm ở đây chỉ dùng minh họa cho quy tắc giao diện, không phải ngưỡng chẩn đoán.',
                      style: TextStyle(color: Color(0xFF8A9693), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiInsightCard() => GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NHẬN ĐỊNH CHUYÊN SÂU TỪ TRỢ LÝ AI',
                    style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
                _sampleBadge(),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F6),
                borderRadius: BorderRadius.circular(14),
                border: const Border(left: BorderSide(color: _teal, width: 3)),
              ),
              child: const Text(
                '“Chào Bảo, hệ thống ghi nhận nhịp sinh học tuần qua khá tốt, ngoại trừ chiều thứ Ba có hiện tượng nhịp tim tăng vọt do vận động...”',
                style: TextStyle(
                  color: _ink,
                  fontSize: 12,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF8A9693), size: 15),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nội dung AI mẫu theo wireframe, chưa được sinh từ dữ liệu của bạn.',
                    style: TextStyle(color: Color(0xFF8A9693), fontSize: 10, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán y tế.',
              style: TextStyle(color: Color(0xFF8A9693), fontSize: 10, height: 1.4),
            ),
          ],
        ),
      );

  Widget _sampleBadge({bool compact = false}) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          compact ? 'MẪU' : 'MINH HỌA',
          style: const TextStyle(
            color: Color(0xFF966A22),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _chatTab() => Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(13),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: _teal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Khung chat đang ở chế độ xem trước. Mô hình AI chưa được kết nối.',
                          style: TextStyle(color: Color(0xFF687875), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final message in _messages) _messageBubble(message),
                if (_messages.length == 1) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
                    child: Text(
                      'Gợi ý câu hỏi',
                      style: TextStyle(color: Color(0xFF82908D), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final question in _quickQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          onPressed: () => _sendMessage(question),
                          label: Text(question),
                          labelStyle: const TextStyle(color: Color(0xFF327E76), fontSize: 11),
                          side: const BorderSide(color: Color(0xFFD6E8E3)),
                          backgroundColor: Colors.white.withValues(alpha: .8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _messageBubble(_ChatMessage message) {
    final color = message.isUser ? _teal : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE5F4F0),
              child: Icon(Icons.auto_awesome, color: _teal, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 5),
                  bottomRight: Radius.circular(message.isUser ? 5 : 18),
                ),
                border: message.isUser ? null : Border.all(color: const Color(0xFFE5ECEA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : _ink,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _timeLabel(message.sentAt),
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white.withValues(alpha: .75)
                            : const Color(0xFF94A09D),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _messageComposer() => Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FBFA),
          border: Border(top: BorderSide(color: Color(0xFFE4ECE9))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi sức khỏe...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFE1EBE8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFE1EBE8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: _teal),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, size: 19),
              style: IconButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(46, 46),
              ),
              tooltip: 'Gửi câu hỏi',
            ),
          ],
        ),
      );

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
              Icon(icon, size: 21, color: selected ? _teal : const Color(0xFF9AA6A3)),
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.sentAt,
  });

  final String text;
  final bool isUser;
  final DateTime sentAt;
}
