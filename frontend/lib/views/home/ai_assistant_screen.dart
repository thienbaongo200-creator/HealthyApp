import 'package:flutter/material.dart';
import 'main_navigation_wrapper.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ai_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/views/home/quick_add_screen.dart';
import 'package:frontend/widgets/widgets.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    this.initialMember = 'Tôi',
    this.initialProfileId,
  });

  final String initialMember;
  final String? initialProfileId;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _self = '(Tôi)';
  static const _quickQuestions = [
    'Tôi nên theo dõi chỉ số nào mỗi ngày?',
    'Làm sao để ngủ tốt hơn?',
    'Đi bộ bao lâu là phù hợp?',
  ];

  late final TabController _tabController;
  late String _selectedMember;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final AiApiService _aiApiService = AiApiService();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
          'Xin chào! Mình có thể giúp bạn tìm hiểu các chỉ số sức khỏe. Bạn muốn hỏi điều gì?',
      isUser: false,
      sentAt: DateTime.now(),
    ),
  ];
  List<Map<String, dynamic>> _conversations = [];

  bool _isAnalyzing = false;
  bool _isSendingChat = false;
  bool _isLoadingChatProfile = true;
  bool _isLoadingConversations = false;
  String? _chatProfileId;
  String? _chatProfileError;
  String? _chatHistoryError;
  String? _conversationId;
  bool _profileSelectionChanged = false;
  int _profileLoadRequest = 0;
  int _conversationLoadRequest = 0;
  bool _analysisLoaded = false;
  String? _analysisError;
  int? _measurementsInPeriod;
  int? _peakHeartRate;
  DateTime? _peakHeartRateAt;
  String? _riskLevel;
  List<String> _riskWarnings = [];
  List<String> _riskRecommendations = [];
  String? _riskRecommendation;
  String? _riskInterpretation;
  String? _riskGeneratedBy;
  int? _riskAnalyzedCount;

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.initialMember == 'Tôi'
        ? _self
        : widget.initialMember;
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChatProfile());
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
    if (_chatProfileId == null) {
      _showMessage('Hồ sơ đang xem chưa sẵn sàng.');
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });
    try {
      final risk = await _aiApiService.assessRisk(profileId: _chatProfileId!);
      final allMeasurements = await ApiService.fetchHealthMeasurements(
        profileId: _chatProfileId,
      );
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recent = <({DateTime measuredAt, int heartRate})>[];
      for (final item in allMeasurements) {
        final measuredAt = DateTime.tryParse(
          item['measured_at']?.toString() ?? '',
        )?.toLocal();
        final rawHeartRate = item['measurement_type'] == 'HEART_RATE'
            ? item['value']
            : item['heart_rate'];
        final heartRate = rawHeartRate is num
            ? rawHeartRate.toInt()
            : int.tryParse(rawHeartRate?.toString() ?? '');
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
        _riskLevel = risk.riskLevel;
        _riskAnalyzedCount = risk.analyzedCount;
        _riskWarnings = risk.warnings;
        _riskRecommendations = risk.recommendations;
        _riskRecommendation = risk.recommendation;
        _riskInterpretation = risk.interpretation;
        _riskGeneratedBy = risk.generatedBy;
        _isAnalyzing = false;
      });
      _showMessage('Đã phân tích ${_riskAnalyzedCount ?? 0} chỉ số gần nhất.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analysisError = error.toString().contains('403')
            ? 'Bạn không có quyền xem đánh giá của hồ sơ này.'
            : 'Không thể tải đánh giá nguy cơ. Hãy kiểm tra kết nối và thử lại.';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _selectMember(String member) async {
    _profileSelectionChanged = true;
    _conversationLoadRequest++;
    setState(() {
      _selectedMember = member;
      _chatProfileId = null;
      _conversationId = null;
      _conversations = [];
      _chatHistoryError = null;
      _messages
        ..clear()
        ..add(_welcomeMessage());
    });
    await _loadChatProfile();
    setState(() {
      _analysisLoaded = false;
      _measurementsInPeriod = null;
      _peakHeartRate = null;
      _peakHeartRateAt = null;
      _riskLevel = null;
      _riskWarnings = [];
      _riskRecommendations = [];
      _riskRecommendation = null;
      _riskInterpretation = null;
      _riskGeneratedBy = null;
      _riskAnalyzedCount = null;
    });
  }

  Future<void> _loadChatProfile() async {
    final requestId = ++_profileLoadRequest;
    setState(() {
      _isLoadingChatProfile = true;
      _chatProfileError = null;
    });
    try {
      final profiles = await _aiApiService.fetchProfiles();
      if (!mounted || requestId != _profileLoadRequest) return;
      final initialProfileId =
          !_profileSelectionChanged && widget.initialProfileId != null
          ? widget.initialProfileId
          : null;
      final profile = initialProfileId != null
          ? profiles
                .where((item) => item['id']?.toString() == initialProfileId)
                .firstOrNull
          : _selectedMember == _self
          ? profiles.where((item) => item['profile_type'] == 'SELF').firstOrNull
          : profiles
                .where(
                  (item) =>
                      item['full_name']?.toString().trim().toLowerCase() ==
                      _selectedMember.trim().toLowerCase(),
                )
                .firstOrNull;
      if (profile == null || profile['id'] == null) {
        throw Exception(
          'Không tìm thấy hồ sơ "$_selectedMember". Vui lòng chọn thành viên có hồ sơ đã tạo.',
        );
      }
      if (!mounted || requestId != _profileLoadRequest) return;
      setState(() => _chatProfileId = profile['id'].toString());
      ProfileSelectionScope.of(
        context,
      ).selectProfileId(profile['id'].toString());
      await _loadConversationHistory(profile['id'].toString());
    } catch (error) {
      if (!mounted || requestId != _profileLoadRequest) return;
      setState(
        () => _chatProfileError = error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted && requestId == _profileLoadRequest) {
        setState(() => _isLoadingChatProfile = false);
      }
    }
  }

  Future<void> _loadConversationHistory(String profileId) async {
    final requestId = ++_conversationLoadRequest;
    setState(() {
      _isLoadingConversations = true;
      _chatHistoryError = null;
    });
    try {
      final conversations = await _aiApiService.fetchConversations(
        profileId: profileId,
      );
      if (!mounted ||
          requestId != _conversationLoadRequest ||
          _chatProfileId != profileId) {
        return;
      }

      final latestConversation = conversations.isEmpty
          ? null
          : conversations.first;
      final conversationId = latestConversation?['id']?.toString();
      final messages = conversationId == null
          ? <Map<String, dynamic>>[]
          : await _aiApiService.fetchConversationMessages(
              conversationId: conversationId,
            );
      if (!mounted ||
          requestId != _conversationLoadRequest ||
          _chatProfileId != profileId) {
        return;
      }

      setState(() {
        _conversations = conversations;
        _conversationId = conversationId;
        _messages
          ..clear()
          ..addAll(messages.map(_chatMessageFromJson));
        if (_messages.isEmpty) _messages.add(_welcomeMessage());
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted ||
          requestId != _conversationLoadRequest ||
          _chatProfileId != profileId) {
        return;
      }
      setState(() {
        _chatHistoryError =
            'Không thể tải lịch sử hội thoại. Vui lòng thử lại. ($error)';
      });
    } finally {
      if (mounted &&
          requestId == _conversationLoadRequest &&
          _chatProfileId == profileId) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  Future<void> _selectConversation(String conversationId) async {
    if (_isLoadingConversations || conversationId == _conversationId) return;
    final profileId = _chatProfileId;
    if (profileId == null) return;
    final requestId = ++_conversationLoadRequest;
    setState(() {
      _isLoadingConversations = true;
      _chatHistoryError = null;
    });
    try {
      final messages = await _aiApiService.fetchConversationMessages(
        conversationId: conversationId,
      );
      if (!mounted ||
          requestId != _conversationLoadRequest ||
          _chatProfileId != profileId) {
        return;
      }
      setState(() {
        _conversationId = conversationId;
        _messages
          ..clear()
          ..addAll(messages.map(_chatMessageFromJson));
        if (_messages.isEmpty) _messages.add(_welcomeMessage());
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted &&
          requestId == _conversationLoadRequest &&
          _chatProfileId == profileId) {
        setState(() {
          _chatHistoryError =
              'Không thể mở hội thoại đã chọn. Vui lòng thử lại. ($error)';
        });
      }
    } finally {
      if (mounted &&
          requestId == _conversationLoadRequest &&
          _chatProfileId == profileId) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  _ChatMessage _chatMessageFromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString();
    final sentAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return _ChatMessage(
      text: json['content']?.toString() ?? '',
      isUser: role == 'USER',
      sentAt: sentAt?.toLocal() ?? DateTime.now(),
    );
  }

  _ChatMessage _welcomeMessage() => _ChatMessage(
    text:
        'Xin chào! Mình có thể giúp bạn tìm hiểu các chỉ số sức khỏe. Bạn muốn hỏi điều gì?',
    isUser: false,
    sentAt: DateTime.now(),
  );

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String get _riskLabel => switch (_riskLevel) {
    'HIGH' => 'Cao',
    'MEDIUM' => 'Trung bình',
    'LOW' => 'Thấp',
    _ => 'Chưa đủ dữ liệu',
  };

  Color get _riskColor => switch (_riskLevel) {
    'HIGH' => const Color(0xFFB64B4B),
    'MEDIUM' => const Color(0xFF966A22),
    'LOW' => const Color(0xFF348250),
    _ => const Color(0xFF687875),
  };

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? suggestedQuestion]) async {
    final text = (suggestedQuestion ?? _messageController.text).trim();
    if (text.isEmpty || _isSendingChat) return;
    if (_isLoadingChatProfile || _chatProfileId == null) {
      _showMessage(
        _chatProfileError ??
            'Đang tải hồ sơ hoặc hồ sơ được chọn chưa sẵn sàng.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, sentAt: DateTime.now()),
      );
      _isSendingChat = true;
    });
    _messageController.clear();
    _scrollToBottom();
    try {
      final response = await _aiApiService.sendMessage(
        profileId: _chatProfileId!,
        message: text,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = response['conversation_id']?.toString();
        final conversationId = _conversationId;
        if (conversationId != null) {
          _conversations.removeWhere(
            (conversation) => conversation['id']?.toString() == conversationId,
          );
          _conversations.insert(0, {
            'id': conversationId,
            'profile_id': _chatProfileId,
            'title': response['title']?.toString() ?? text,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        _messages.add(
          _ChatMessage(
            text:
                response['reply']?.toString() ?? 'Trợ lý chưa trả về nội dung.',
            isUser: false,
            sentAt: DateTime.now(),
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is AiFallbackException
          ? 'Phản hồi dự phòng (chưa được lưu): ${error.fallbackReply}\n\n${error.message}'
          : 'Không gửi được tin nhắn. $error';
      setState(() {
        if (error is AiFallbackException) {
          _conversationId = error.conversationId;
          _messageController.text = text;
        }
        _messages.add(
          _ChatMessage(text: message, isUser: false, sentAt: DateTime.now()),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSendingChat = false);
        _scrollToBottom();
      }
    }
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
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE1EBE8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: _teal,
                            size: 18,
                          ),
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
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: _ink,
                            size: 18,
                          ),
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
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.health_and_safety_outlined, size: 18),
                    text: 'Đánh giá nguy cơ',
                  ),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    text: 'Trợ lý AI',
                  ),
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
            MainNavigationWrapper(
              selectedIndex: 2,
              onSelected: (index) {
                if (index == 0) Navigator.pop(context);
                if (index == 1 || index == 3) {
                  _showMessage(index == 1 ? 'Nhật ký' : 'Thiết bị');
                }
              },
              onQuickAdd: _openQuickAdd,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuickAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(member: _selectedMember),
      ),
    );
    if (saved == true && mounted) {
      await _analyzeNow();
    }
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
            TextButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeNow,
              icon: _isAnalyzing
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Phân tích'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: switch (_riskLevel) {
              'HIGH' => const Color(0xFFFCE8E8),
              'MEDIUM' => const Color(0xFFFFF4DF),
              'LOW' => const Color(0xFFE8F5EB),
              'UNKNOWN' => const Color(0xFFFFF7E5),
              _ => const Color(0xFFF0F3F2),
            },
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _riskLevel == 'HIGH'
                    ? Icons.error_outline_rounded
                    : _riskLevel == 'UNKNOWN'
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_rounded,
                color: _riskColor,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _analysisLoaded
                      ? (_riskLevel == 'UNKNOWN'
                            ? 'Chưa đủ dữ liệu sàng lọc'
                            : 'MỨC SÀNG LỌC: ${_riskLabel.toUpperCase()}')
                      : 'CHƯA CÓ ĐÁNH GIÁ',
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_analysisLoaded && _riskLevel == 'UNKNOWN')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chưa đủ dữ liệu sàng lọc để áp dụng các quy tắc nguy cơ. Hãy bổ sung mẫu đo rồi phân tích lại.',
                style: TextStyle(
                  color: Color(0xFF687875),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              for (final recommendation
                  in _riskRecommendations.isEmpty
                      ? const [
                          'Bổ sung ít nhất 3 mẫu nhịp tim.',
                          'Hoặc ghi nhận huyết áp, số bước hay calo trong ngày.',
                        ]
                      : _riskRecommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $recommendation',
                    style: const TextStyle(
                      color: Color(0xFF687875),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          )
        else if (_analysisLoaded)
          Text(
            'Căn cứ demo: nhịp tim >120 bpm (R01); 3 mẫu liên tiếp vượt ngưỡng tạo cảnh báo R02. Có ${_measurementsInPeriod ?? 0} mẫu nhịp tim trong 7 ngày, tổng ${_riskAnalyzedCount ?? 0} mẫu được quy tắc đánh giá.',
            style: const TextStyle(
              color: Color(0xFF687875),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          _analysisLoaded
              ? 'Đã phân tích ${_riskAnalyzedCount ?? 0} chỉ số gần nhất; ${_measurementsInPeriod ?? 0} lần đo nhịp tim trong 7 ngày.'
              : 'Chạy phân tích để tải đánh giá từ dữ liệu của hồ sơ đang chọn.',
          style: const TextStyle(
            color: Color(0xFF687875),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (_riskWarnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final warning in _riskWarnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $warning',
                style: const TextStyle(
                  color: Color(0xFF687875),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
        if (_riskRecommendation != null) ...[
          const SizedBox(height: 4),
          Text(
            _riskRecommendation!,
            style: const TextStyle(
              color: Color(0xFF687875),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
        if (_riskInterpretation != null) ...[
          const SizedBox(height: 8),
          Text(
            'Diễn giải AI: $_riskInterpretation',
            style: const TextStyle(
              color: Color(0xFF315A52),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ] else if (_riskGeneratedBy == 'RULE_ONLY') ...[
          const SizedBox(height: 8),
          const Text(
            'Kết quả này chỉ dựa trên các quy tắc sàng lọc.',
            style: TextStyle(
              color: Color(0xFF687875),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
        if (_analysisError != null) ...[
          const SizedBox(height: 8),
          Text(
            _analysisError!,
            style: const TextStyle(color: Color(0xFFB64B4B), fontSize: 11),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Đây là sàng lọc theo ngưỡng quy tắc đơn giản, không phải chẩn đoán y khoa.',
          style: TextStyle(color: Color(0xFF8A9693), fontSize: 10, height: 1.4),
        ),
      ],
    ),
  );

  Widget _systemWarningCard() {
    final warning = _riskWarnings.firstOrNull;
    final title = !_analysisLoaded
        ? 'Chưa chạy đánh giá nguy cơ'
        : warning ?? 'Không có cảnh báo theo các ngưỡng đã kiểm tra';
    final detail = _analysisLoaded
        ? [
            if (_peakHeartRate != null)
              'Nhịp tim cao nhất trong 7 ngày: $_peakHeartRate bpm lúc ${_timeLabel(_peakHeartRateAt!)}.',
            _riskRecommendation ?? 'Chưa có đề xuất bổ sung từ hệ thống.',
          ].join(' ')
        : 'Chọn “Phân tích” để yêu cầu backend đánh giá hồ sơ này.';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CẢNH BÁO TỪ HỆ THỐNG',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _riskLevel == 'HIGH'
                    ? Icons.warning_rounded
                    : _analysisLoaded
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: _riskLevel == 'HIGH'
                    ? const Color(0xFFD75858)
                    : const Color(0xFF46916A),
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
        const Text(
          'NHẬN ĐỊNH TỪ HỆ THỐNG',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
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
          child: Text(
            _analysisLoaded
                ? (_riskWarnings.isEmpty
                      ? _riskRecommendation ??
                            'Chưa có nhận định bổ sung từ hệ thống.'
                      : _riskWarnings.join(' '))
                : 'Chưa có dữ liệu phân tích. Hãy tải đánh giá nguy cơ cho hồ sơ đang chọn.',
            style: const TextStyle(color: _ink, fontSize: 12, height: 1.55),
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
                'Đây là hệ thống quy tắc sàng lọc nội bộ, chưa kết nối mô hình AI tạo sinh. Thông tin chỉ tham khảo, không thay thế chẩn đoán y tế.',
                style: TextStyle(
                  color: Color(0xFF8A9693),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chatProfileError ??
                          (_isLoadingChatProfile
                              ? 'Đang tải hồ sơ để kết nối trợ lý AI...'
                              : _chatHistoryError ??
                                    (_isLoadingConversations
                                        ? 'Đang tải hội thoại cũ...'
                                        : 'Tin nhắn sẽ được phân tích theo dữ liệu sức khỏe của hồ sơ đang chọn.')),
                      style: TextStyle(
                        color: Color(0xFF687875),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_conversations.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _conversationId,
                decoration: const InputDecoration(
                  labelText: 'Lịch sử hội thoại',
                  isDense: true,
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  for (final conversation in _conversations)
                    if (conversation['id'] != null)
                      DropdownMenuItem(
                        value: conversation['id'].toString(),
                        child: Text(
                          conversation['title']?.toString().isNotEmpty == true
                              ? conversation['title'].toString()
                              : 'Hội thoại',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: _isLoadingConversations
                    ? null
                    : (conversationId) {
                        if (conversationId != null) {
                          _selectConversation(conversationId);
                        }
                      },
              ),
            ],
            const SizedBox(height: 14),
            for (final message in _messages) _messageBubble(message),
            if (_isSendingChat)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _teal,
                    ),
                  ),
                ),
              ),
            if (_messages.length == 1) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Text(
                  'Gợi ý câu hỏi',
                  style: TextStyle(
                    color: Color(0xFF82908D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
                      labelStyle: const TextStyle(
                        color: Color(0xFF327E76),
                        fontSize: 11,
                      ),
                      side: const BorderSide(color: Color(0xFFD6E8E3)),
                      backgroundColor: Colors.white.withValues(alpha: .8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                border: message.isUser
                    ? null
                    : Border.all(color: const Color(0xFFE5ECEA)),
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
            onSubmitted: _isSendingChat ? null : (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Nhập câu hỏi sức khỏe...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
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
          onPressed: _isSendingChat ? null : _sendMessage,
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
