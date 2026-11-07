import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiMessage> _messages = [
    AiMessage(
      text: "Xin chào Bảo! Tôi là Trợ lý Sức khỏe AI của bạn. Tôi có thể giúp gì cho các chỉ số và nhật ký sức khỏe hôm nay của bạn?",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  bool _isLoading = false;

  // 1. Quản lý danh sách gợi ý động (Dynamic Quick Prompts) ban đầu
  List<String> _currentPrompts = [
    "Đánh giá huyết áp của tôi",
    "Chỉ số đường huyết có ổn không?",
    "Lời khuyên cải thiện giấc ngủ",
    "Tôi nên ăn gì để giảm cân?",
  ];

  // 2. Hàm chuẩn hóa tiếng Việt (Xóa dấu, chuyển về chữ thường) để bắt từ khóa chuẩn xác
  String _normalizeText(String input) {
    String text = input.toLowerCase();
    text = text.replaceAll(RegExp(r'[àáảãạăắằẳẵặâấầẩẫậ]'), 'a');
    text = text.replaceAll(RegExp(r'[èéẻẽẹêếềểễệ]'), 'e');
    text = text.replaceAll(RegExp(r'[ìíỉĩị]'), 'i');
    text = text.replaceAll(RegExp(r'[òóỏõọôốồổỗộơớờởỡợ]'), 'o');
    text = text.replaceAll(RegExp(r'[ùúủũụưứừửữự]'), 'u');
    text = text.replaceAll(RegExp(r'[ỳýỷỹỵ]'), 'y');
    text = text.replaceAll(RegExp(r'[đ]'), 'd');
    text = text.replaceAll(RegExp(r'[^\w\s]'), ''); // Xóa ký tự đặc biệt
    return text.trim();
  }

  // 3. Bộ định nghĩa Intent & Phản hồi thông minh dựa trên Rule-based nâng cao
  String _getRuleBasedResponse(String rawInput, List<String> nextPromptsRef) {
    String query = _normalizeText(rawInput);

    // Intent 1: Huyết áp
    if (query.contains("huyet ap") || query.contains("ap luc")) {
      nextPromptsRef.addAll(["Cách giảm huyết áp", "Theo dõi huyết áp khi nào?"]);
      return "Dựa trên dữ liệu hồ sơ gần đây, huyết áp của bạn đang dao động ở mức ổn định (khoảng 120/80 mmHg). Hãy duy trì thói quen đo vào buổi sáng lúc đói nhé.";
    }
    // Intent 2: Đường huyết
    else if (query.contains("duong huyet") || query.contains("tieu duong") || query.contains("duong")) {
      nextPromptsRef.addAll(["Thực phẩm giảm đường", "Triệu chứng đường huyết cao"]);
      return "Chỉ số đường huyết của bạn ghi nhận trong giới hạn bình thường. Bạn nên hạn chế đồ ngọt vào buổi tối để duy trì mức ổn định này.";
    }
    // Intent 3: Giấc ngủ
    else if (query.contains("ngu") || query.contains("giac ngu") || query.contains("mat ngu")) {
      nextPromptsRef.addAll(["Mẹo ngủ sâu giấc", "Thời gian ngủ phù hợp"]);
      return "Giấc ngủ rất quan trọng cho việc phục hồi cơ thể. Bạn nên cố gắng ngủ đủ 7-8 tiếng mỗi đêm và hạn chế sử dụng thiết bị điện tử trước khi ngủ 30 phút.";
    }
    // Intent 4: Giảm cân / Ăn uống
    else if (query.contains("an gi") || query.contains("giam can") || query.contains("can nang") || query.contains("an")) {
      nextPromptsRef.addAll(["Thực đơn eat clean", "Lượng nước cần uống mỗi ngày"]);
      return "Để quản lý cân nặng hiệu quả, bạn nên ưu tiên thực phẩm giàu protein, nhiều chất xơ, kết hợp uống đủ 2-2.5 lít nước mỗi ngày.";
    }
    // Fallback: Khi không khớp từ khóa nào
    else {
      nextPromptsRef.addAll(["Đánh giá huyết áp của tôi", "Lời khuyên cải thiện giấc ngủ"]);
      return "Mình chưa hiểu rõ ý bạn lắm. Tuy nhiên, hệ thống ghi nhận sức khỏe tổng quát của bạn đang ở trạng thái ổn định. Bạn có muốn kiểm tra các chỉ số cụ thể bên dưới không?";
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        AiMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _currentPrompts.clear(); // Xóa gợi ý cũ khi đang chờ phản hồi
    });

    _controller.clear();
    _scrollToBottom();

    // Giả lập xử lý Rule-based thông minh (Không cần AI ngoài, phản hồi tức thì)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      List<String> dynamicNextPrompts = [];
      String aiReply = _getRuleBasedResponse(text, dynamicNextPrompts);

      setState(() {
        _isLoading = false;
        _messages.add(
          AiMessage(
            text: aiReply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        // Cập nhật bộ gợi ý câu hỏi tiếp theo dựa trên ngữ cảnh vừa trò chuyện
        _currentPrompts = dynamicNextPrompts;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý Sức khỏe AI'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Khu vực hiển thị danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.x4),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Hiệu ứng đang gõ / chờ phản hồi
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    'Hệ thống đang phân tích dữ liệu hồ sơ...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // Danh sách gợi ý câu hỏi nhanh (Dynamic Quick Prompts thay đổi theo ngữ cảnh)
          if (_currentPrompts.isNotEmpty && !_isLoading)
            SizedBox(
              height: AppSpacing.x6 * 2,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
                itemCount: _currentPrompts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x1,
                      vertical: AppSpacing.x2,
                    ),
                    child: ActionChip(
                      label: Text(
                        _currentPrompts[index],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      backgroundColor: AppColors.primarySoft,
                      labelStyle: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.primary),
                      onPressed: () => _sendMessage(_currentPrompts[index]),
                    ),
                  );
                },
              ),
            ),

          // Ô nhập tin nhắn & nút gửi
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Nhập câu hỏi về sức khỏe...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x4,
                        vertical: AppSpacing.x3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                IconButton.filled(
                  tooltip: 'Gửi tin nhắn',
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () => _sendMessage(_controller.text),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.x3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primary : AppColors.surface,
          border: message.isUser ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 5),
            bottomRight: Radius.circular(message.isUser ? 5 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: message.isUser ? AppColors.surface : AppColors.textPrimary,
              ),
        ),
      ),
    );
  }
}