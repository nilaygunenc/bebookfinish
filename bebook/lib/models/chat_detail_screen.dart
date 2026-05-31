import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'chat_message.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final int receiverId;
  final String receiverName;
  final String? receiverImage;
  final String bookTitle;
  final int bookId;
  final int myId;
  final String myName;

  const ChatDetailScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverImage,
    required this.bookTitle,
    required this.bookId,
    required this.myId,
    required this.myName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _timer;

  late AnimationController _sendBtnController;

  @override
  void initState() {
    super.initState();
    _sendBtnController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _markAllAsRead();
    _markDelivered();
    _fetchMessages(scrollToBottom: true);

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages();
    });

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty) {
        _sendBtnController.forward();
      } else {
        _sendBtnController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendBtnController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    await ApiService.markMessagesAsRead(
        widget.myId, widget.receiverId, widget.bookId);
  }

  Future<void> _markDelivered() async {
    try {
      await http
          .put(Uri.parse(
              "${ApiService.baseUrl}/mark_as_delivered/${widget.myId}"))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool scrollToBottom = false}) async {
    try {
      final response = await http
          .get(Uri.parse(
            "${ApiService.baseUrl}/messages/${widget.myId}/${widget.receiverId}/${widget.bookId}",
          ))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);

        final hasUnread = decoded.any((m) =>
            m['receiver_id'] == widget.myId && m['is_read'] == false);
        if (hasUnread) _markAllAsRead();

        if (mounted) {
          // Sadece mesaj sayısı veya içerik değiştiyse setState çağır
          final newMessages =
              decoded.map((m) => ChatMessage.fromJson(m)).toList();
          final changed = newMessages.length != messages.length ||
              (newMessages.isNotEmpty &&
                  messages.isNotEmpty &&
                  (newMessages.last.messageText != messages.last.messageText ||
                      newMessages.last.isRead != messages.last.isRead ||
                      newMessages.last.isDelivered !=
                          messages.last.isDelivered));

          if (changed || _isLoading) {
            setState(() {
              messages = newMessages;
              _isLoading = false;
            });
            if (scrollToBottom) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();

    final tempMsg = ChatMessage(
      id: null,
      senderId: widget.myId,
      receiverId: widget.receiverId,
      bookId: widget.bookId,
      messageText: text,
      createdAt: DateTime.now(),
      isRead: false,
      isDelivered: false,
    );

    setState(() {
      messages.add(tempMsg);
      _messageController.clear();
      _isSending = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/messages/send"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender_id": widget.myId,
          "receiver_id": widget.receiverId,
          "book_id": widget.bookId,
          "message_text": text,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchMessages();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildTick(ChatMessage msg) {
    final IconData icon =
        (msg.isRead || msg.isDelivered) ? Icons.done_all : Icons.done;
    final Color color = msg.isRead
        ? const Color(0xFF00FF88)
        : msg.isDelivered
            ? Colors.white
            : Colors.white38;
    return Icon(icon, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppTheme.primaryIndigo, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.shadowPrimary,
            ),
            child: ClipOval(
              child: (widget.receiverImage != null &&
                      widget.receiverImage!.isNotEmpty)
                  ? Image.network(
                      "${ApiService.baseUrl}/${widget.receiverImage!.replaceAll(r'\', '/')}",
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarText(widget.receiverName),
                    )
                  : _avatarText(widget.receiverName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.neutralBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 11, color: AppTheme.accentOrange),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        widget.bookTitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryIndigo.withOpacity(0.1),
                AppTheme.accentOrange.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarText(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: AppTheme.primaryIndigo.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              "Henüz mesaj yok",
              style: AppTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.neutralBlack,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "İlk mesajı sen gönder! 👋",
              style: AppTheme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final bool isMe = msg.senderId == widget.myId;

        // Tarih ayırıcı
        final showDate = index == 0 ||
            !_isSameDay(messages[index - 1].createdAt, msg.createdAt);

        return Column(
          children: [
            if (showDate) _buildDateDivider(msg.createdAt),
            _buildMessageBubble(msg, isMe),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = "Bugün";
    } else if (_isSameDay(
        date, now.subtract(const Duration(days: 1)))) {
      label = "Dün";
    } else {
      label =
          "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: AppTheme.neutralMedium, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.shadowSM,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.neutralDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
              child: Divider(color: AppTheme.neutralMedium, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Karşı taraf avatarı
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: ClipOval(
                child: (widget.receiverImage != null &&
                        widget.receiverImage!.isNotEmpty)
                    ? Image.network(
                        "${ApiService.baseUrl}${widget.receiverImage!.startsWith('/') ? widget.receiverImage! : '/${widget.receiverImage!}'}",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarText(widget.receiverName),
                      )
                    : _avatarText(widget.receiverName),
              ),
            ),
          ],

          // Mesaj balonu
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe ? AppTheme.primaryGradient : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? AppTheme.primaryIndigo.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.messageText,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.neutralBlack,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white60
                              : AppTheme.neutralDark,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildTick(msg),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Kendi avatarım
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Mesaj alanı
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.neutralLight,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryIndigo.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.neutralBlack),
                    decoration: InputDecoration(
                      hintText: "Mesaj yaz...",
                      hintStyle: TextStyle(
                          color: AppTheme.neutralDark, fontSize: 15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Gönder butonu
              AnimatedBuilder(
                animation: _sendBtnController,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.shadowPrimary,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
