import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/widgets/widgets.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);
  static const _quickQuestions = [
    'Tôi nên theo dõi chỉ số nào mỗi ngày?',
    'Làm sao để ngủ tốt hơn?',
    'Đi bộ bao lâu là phù hợp?',
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Xin chào! Mình có thể giúp bạn tìm hiểu các chỉ số sức khỏe. Bạn muốn hỏi điều gì?',
      isUser: false,
      sentAt: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Trợ lý AI & Dự báo',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Quay lại',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'BẢN XEM TRƯỚC',
                style: TextStyle(
                  color: Color(0xFF966A22),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              _riskCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F4F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: _teal, size: 19),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Trò chuyện với trợ lý sức khỏe',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.circle, color: Color(0xFFB68A42), size: 8),
                  const SizedBox(width: 5),
                  const Text(
                    'Demo',
                    style: TextStyle(color: Color(0xFF8F7650), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final message in _messages) _messageBubble(message),
              if (_messages.length == 1) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        onPressed: () => _sendMessage(question),
                        label: Text(question),
                        labelStyle: const TextStyle(
                          color: Color(0xFF327E76),
                          fontSize: 12,
                        ),
                        side: const BorderSide(color: Color(0xFFD6E8E3)),
                        backgroundColor: Colors.white.withValues(alpha: .78),
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _messageComposer(),
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
        onPressed: () => _showMessage('Ghi nhận chỉ số sẽ sớm được bổ sung.'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _riskCard() => GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.monitor_heart_outlined, color: _teal),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Đánh giá nguy cơ sức khỏe',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'THẤP*',
                    style: TextStyle(
                      color: Color(0xFF348250),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Nguy cơ tim mạch',
              style: TextStyle(color: Color(0xFF71817E), fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const LinearProgressIndicator(
                value: .28,
                minHeight: 7,
                backgroundColor: Color(0xFFEAF0EE),
                valueColor: AlwaysStoppedAnimation(Color(0xFF58A875)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '*Mức “Thấp” chỉ là dữ liệu minh họa cho giao diện. Ứng dụng chưa kết nối AI Model nên chưa có đánh giá nguy cơ cá nhân.',
              style: TextStyle(
                color: Color(0xFF82908D),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      );

  Widget _messageBubble(_ChatMessage message) {
    final color = message.isUser ? const Color(0xFF168B83) : Colors.white;
    final textColor = message.isUser ? Colors.white : _ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D18343A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.4,
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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
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
