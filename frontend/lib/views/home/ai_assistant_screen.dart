import 'dart:convert';

import 'package:flutter/material.dart';
import 'main_navigation_wrapper.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ai_service.dart';
import 'package:frontend/services/risk_message_mapper.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
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
  static const _teal = AppColors.primary;
  static const _ink = AppColors.textPrimary;
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
    _selectedMember = widget.initialMember;
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
    final requestProfileId = _chatProfileId;
    if (requestProfileId == null) {
      _showMessage('Hồ sơ đang xem chưa sẵn sàng.');
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });
    try {
      final risk = await _aiApiService.assessRisk(profileId: requestProfileId);
      final allMeasurements = await ApiService.fetchHealthMeasurements(
        profileId: requestProfileId,
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
      recent.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      final peakMeasurement = recent.isEmpty
          ? null
          : recent.reduce((a, b) => a.heartRate >= b.heartRate ? a : b);
      if (!mounted || requestProfileId != _chatProfileId) return;
      setState(() {
        _analysisLoaded = true;
        _measurementsInPeriod = recent.length;
        _peakHeartRate = peakMeasurement?.heartRate;
        _peakHeartRateAt = peakMeasurement?.measuredAt;
        _riskLevel = risk.riskLevel;
        _riskAnalyzedCount = risk.analyzedCount;
        _riskWarnings = risk.warnings;
        _riskRecommendations = risk.recommendations;
        _riskRecommendation = risk.recommendation;
        _riskInterpretation = risk.interpretation == null
            ? null
            : _assistantDisplayText(risk.interpretation!);
        _riskGeneratedBy = risk.generatedBy;
        _isAnalyzing = false;
      });
      _showMessage('Đã phân tích ${_riskAnalyzedCount ?? 0} chỉ số gần nhất.');
    } catch (error) {
      if (!mounted || requestProfileId != _chatProfileId) return;
      setState(() {
        _analysisError = error.toString().contains('403')
            ? 'Bạn không có quyền xem đánh giá của hồ sơ này.'
            : 'Không thể tải đánh giá nguy cơ. Hãy kiểm tra kết nối và thử lại.';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _selectMember(String profileId) async {
    final selection = ProfileSelectionScope.of(context);
    final profile = selection.profiles
        .where((item) => item['id']?.toString() == profileId)
        .firstOrNull;
    if (profile == null || profileId == _chatProfileId) return;

    _profileSelectionChanged = true;
    _conversationLoadRequest++;
    setState(() {
      _selectedMember = profileDisplayName(profile);
      _chatProfileId = null;
      _conversationId = null;
      _conversations = [];
      _chatHistoryError = null;
      _analysisLoaded = false;
      _analysisError = null;
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
      _isSendingChat = false;
      _isAnalyzing = false;
      _messages
        ..clear()
        ..add(_welcomeMessage());
    });
    selection.selectProfileId(profileId);
    await _loadChatProfile();
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
      final selection = ProfileSelectionScope.of(context);
      selection.setProfiles(profiles);
      final requestedProfileId = !_profileSelectionChanged
          ? widget.initialProfileId ?? selection.selectedProfileId
          : selection.selectedProfileId;
      final profile =
          profiles
              .where((item) => item['id']?.toString() == requestedProfileId)
              .firstOrNull ??
          profiles.where(isCurrentUserProfile).firstOrNull;
      if (profile == null || profile['id'] == null) {
        throw Exception(
          'Không tìm thấy hồ sơ đang chọn. Vui lòng tải lại danh sách hồ sơ.',
        );
      }
      if (!mounted || requestId != _profileLoadRequest) return;
      final selectedProfileId = profile['id'].toString();
      selection.selectProfileId(selectedProfileId);
      _selectedMember = profileDisplayName(profile);
      setState(() => _chatProfileId = selectedProfileId);
      await _loadConversationHistory(selectedProfileId);
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
        _conversations = List.of(conversations);
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
    final content = json['content']?.toString() ?? '';
    return _ChatMessage(
      text: role == 'USER' ? content : _assistantDisplayText(content),
      isUser: role == 'USER',
      sentAt: sentAt?.toLocal() ?? DateTime.now(),
    );
  }

  String _assistantDisplayText(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Trợ lý chưa trả về nội dung.';
    if (!value.startsWith('{') && !value.startsWith('[')) return raw;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['reply', 'answer', 'message', 'content', 'text']) {
          final text = decoded[key];
          if (text is String && text.trim().isNotEmpty) return text.trim();
        }
      }
    } on FormatException {
      // Avoid showing malformed provider payloads as raw data.
    }
    return 'Trợ lý chưa thể hiển thị phản hồi này. Vui lòng thử lại.';
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
    final requestProfileId = _chatProfileId!;
    final requestConversationId = _conversationId;
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
        profileId: requestProfileId,
        message: text,
        conversationId: requestConversationId,
      );
      if (!mounted || _chatProfileId != requestProfileId) return;
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
            text: _assistantDisplayText(response['reply']?.toString() ?? ''),
            isUser: false,
            sentAt: DateTime.now(),
          ),
        );
      });
    } catch (error) {
      if (!mounted || _chatProfileId != requestProfileId) return;
      final message = error is AiFallbackException
          ? 'Phản hồi dự phòng (chưa được lưu): ${_assistantDisplayText(error.fallbackReply)}\n\n${error.message}'
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
      if (mounted && _chatProfileId == requestProfileId) {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Trợ lý AI & Đánh giá nguy cơ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  0,
                  AppSpacing.x4,
                  AppSpacing.x2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    onSelected: _selectMember,
                    itemBuilder: (context) => [
                      for (final profile in ProfileSelectionScope.of(
                        context,
                      ).profiles)
                        PopupMenuItem(
                          value: profile['id']?.toString() ?? '',
                          child: Text(profileDisplayName(profile)),
                        ),
                    ],
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 330),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: AppSpacing.x2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: _teal,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Flexible(
                            child: Text(
                              'Đang xem: $_selectedMember',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x1),
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
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: _teal,
                indicatorWeight: 3,
                labelStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
    final profileId = _chatProfileId;
    if (profileId == null) {
      _showMessage('Hồ sơ đang xem chưa sẵn sàng.');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuickAddScreen(
          member: _selectedMember,
          profileId: profileId,
        ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      children: [
        _riskOverviewCard(),
        const SizedBox(height: AppSpacing.x3),
        _systemWarningCard(),
        const SizedBox(height: AppSpacing.x3),
        _aiInsightCard(),
        const SizedBox(height: AppSpacing.x4),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: _isAnalyzing ? 'Đang phân tích...' : 'Phân tích ngay',
            icon: Icons.refresh_rounded,
            isLoading: _isAnalyzing,
            onPressed: _isAnalyzing ? null : _analyzeNow,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
      ],
    ),
  );

  Widget _riskOverviewCard() => AppCard(
    padding: const EdgeInsets.all(AppSpacing.x4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Tổng quan rủi ro sức khỏe'),
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
        const SizedBox(height: AppSpacing.x4),
        Text(
          'Kết quả áp dụng cho hồ sơ đang xem, dựa trên nhật ký sức khỏe. '
          'Dữ liệu nhập thủ công là nguồn chính; Wear OS chỉ bổ sung khi có.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Các quy tắc hiện sàng lọc nhịp tim, bước chân, calo, huyết áp, '
          'giấc ngủ và thân nhiệt trong 7 ngày gần nhất.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.x3),
        StatusBadge(
          label: _analysisLoaded
              ? (_riskLevel == 'UNKNOWN'
                    ? 'Chưa đủ dữ liệu sàng lọc'
                    : 'Mức sàng lọc: $_riskLabel')
              : 'Chưa có đánh giá',
          tone: switch (_riskLevel) {
            'HIGH' => StatusTone.danger,
            'MEDIUM' || 'UNKNOWN' => StatusTone.warning,
            'LOW' => StatusTone.success,
            _ => StatusTone.neutral,
          },
          icon: _riskLevel == 'HIGH'
              ? Icons.error_outline_rounded
              : _riskLevel == 'UNKNOWN'
              ? Icons.help_outline_rounded
              : Icons.check_circle_rounded,
        ),
        const SizedBox(height: AppSpacing.x3),
        if (_analysisLoaded && _riskLevel == 'UNKNOWN')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chưa đủ dữ liệu sàng lọc để áp dụng các quy tắc nguy cơ. Hãy bổ sung mẫu đo rồi phân tích lại.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.x2),
              for (final recommendation
                  in _riskRecommendations.isEmpty
                      ? const [
                          'Bổ sung ít nhất 3 mẫu nhịp tim.',
                          'Hoặc nhập tổng số bước chân hoặc calo của ngày cần đánh giá.',
                        ]
                      : _riskRecommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                  child: Text(
                    '• ${RiskMessageMapper.toUserMessage(recommendation)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          )
        else if (_analysisLoaded)
          Text(
            'Các ngưỡng gồm nhịp tim, bước chân, calo, huyết áp, giấc ngủ và thân nhiệt. Có ${_measurementsInPeriod ?? 0} mẫu nhịp tim trong 7 ngày; tổng ${_riskAnalyzedCount ?? 0} chỉ số được đánh giá.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          _analysisLoaded
              ? 'Đã phân tích ${_riskAnalyzedCount ?? 0} chỉ số gần nhất; ${_measurementsInPeriod ?? 0} lần đo nhịp tim trong 7 ngày.'
              : 'Chạy phân tích để tải đánh giá từ dữ liệu của hồ sơ đang chọn.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_riskWarnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2),
          for (final warning in _riskWarnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x1),
              child: Text(
                '• ${RiskMessageMapper.toUserMessage(warning)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        if (_riskRecommendation != null) ...[
          const SizedBox(height: 4),
          Text(
            _riskRecommendation!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_riskInterpretation != null) ...[
          const SizedBox(height: AppSpacing.x2),
          const Text('Diễn giải AI:'),
          const SizedBox(height: AppSpacing.x1),
          _MarkdownMessage(
            _assistantDisplayText(_riskInterpretation!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ] else if (_riskGeneratedBy == 'RULE_ONLY') ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Kết quả này chỉ dựa trên các quy tắc sàng lọc.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_analysisError != null) ...[
          const SizedBox(height: AppSpacing.x2),
          ErrorState(message: _analysisError!),
        ],
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Đây là sàng lọc theo ngưỡng quy tắc đơn giản, không phải chẩn đoán y khoa.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _systemWarningCard() {
    final rawWarning = _riskWarnings.firstOrNull;
    final warning = rawWarning == null
        ? null
        : RiskMessageMapper.toUserMessage(rawWarning);
    final title = !_analysisLoaded
        ? 'Chưa chạy đánh giá nguy cơ'
        : warning ?? 'Không có cảnh báo theo các ngưỡng đã kiểm tra';
    final detail = _analysisLoaded
        ? [
            if (_peakHeartRate != null)
              'Nhịp tim cao nhất trong 7 ngày: $_peakHeartRate bpm${_peakHeartRateAt == null ? '' : ' lúc ${_timeLabel(_peakHeartRateAt!)}'}.',
            _riskRecommendation ?? 'Chưa có đề xuất bổ sung từ hệ thống.',
          ].join(' ')
        : 'Chọn “Phân tích” để yêu cầu backend đánh giá hồ sơ này.';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Cảnh báo từ hệ thống'),
          const SizedBox(height: AppSpacing.x3),
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
                    ? AppColors.danger
                    : AppColors.success,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.x1),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiInsightCard() => AppCard(
    padding: const EdgeInsets.all(AppSpacing.x4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Nhận định từ hệ thống'),
        const SizedBox(height: AppSpacing.x3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: const Border(left: BorderSide(color: _teal, width: 3)),
          ),
          child: Text(
            _analysisLoaded
                ? (_riskWarnings.isEmpty
                      ? _riskRecommendation ??
                            'Chưa có nhận định bổ sung từ hệ thống.'
                      : _riskWarnings
                            .map(RiskMessageMapper.toUserMessage)
                            .join(' '))
                : 'Chưa có dữ liệu phân tích. Hãy tải đánh giá nguy cơ cho hồ sơ đang chọn.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary, size: 15),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Đây là hệ thống quy tắc sàng lọc nội bộ, chưa kết nối mô hình AI tạo sinh. Thông tin chỉ tham khảo, không thay thế chẩn đoán y tế.',
                style: Theme.of(context).textTheme.bodySmall,
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.x3),
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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (_conversations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              DropdownButtonFormField<String>(
                initialValue: _conversationId,
                decoration: const InputDecoration(
                  labelText: 'Lịch sử hội thoại',
                  isDense: true,
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.surface,
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
            const SizedBox(height: AppSpacing.x3),
            for (final message in _messages) _messageBubble(message),
            if (_isSendingChat)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.x3),
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
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Text(
                  'Gợi ý câu hỏi',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              for (final question in _quickQuestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      onPressed: () => _sendMessage(question),
                      label: Text(question),
                      labelStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.primary),
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.surface.withValues(alpha: .8),
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
    final color = message.isUser ? _teal : AppColors.surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            const CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.auto_awesome, color: _teal, size: 15),
            ),
            const SizedBox(width: AppSpacing.x2),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x3,
              ),
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
                    : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MarkdownMessage(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.isUser ? AppColors.surface : _ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _timeLabel(message.sentAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: message.isUser
                            ? AppColors.surface.withValues(alpha: .82)
                            : AppColors.textSecondary,
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
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.x3,
      vertical: AppSpacing.x2,
    ),
    decoration: const BoxDecoration(
      color: AppColors.background,
      border: Border(top: BorderSide(color: AppColors.border)),
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
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border),
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
            foregroundColor: AppColors.surface,
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

/// Renders the small, common Markdown subset used in assistant replies.
/// Keeping this local avoids a new package dependency while preserving line
/// breaks, headings, bullet lists, bold text, and inline code.
class _MarkdownMessage extends StatelessWidget {
  const _MarkdownMessage(this.markdown, {required this.style});

  final String markdown;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(
        Text.rich(
          _inlineSpan(paragraph.join(' '), style),
          style: style,
        ),
      );
      paragraph.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line.trim());
      if (heading != null) {
        flushParagraph();
        final headingStyle = style?.copyWith(
          fontSize: (style?.fontSize ?? 14) +
              (heading.group(1)!.length == 1 ? 3 : 1),
          fontWeight: FontWeight.w700,
        );
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              _inlineSpan(heading.group(2)!, headingStyle),
              style: headingStyle,
            ),
          ),
        );
        continue;
      }
      final bullet = RegExp(r'^\s*[-*+]\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(
                  child: Text.rich(
                    _inlineSpan(bullet.group(1)!, style),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      paragraph.add(line.trim());
    }
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 4),
          blocks[index],
        ],
      ],
    );
  }

  static TextSpan _inlineSpan(String text, TextStyle? baseStyle) {
    final spans = <TextSpan>[];
    final matcher = RegExp(r'(\*\*|__)(.+?)\1|`([^`]+)`').allMatches(text);
    var offset = 0;
    for (final match in matcher) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: baseStyle?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppColors.background,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      }
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}
