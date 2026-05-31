import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../models/chat_detail_screen.dart';
import '../../services/api_service.dart';
import '../../core/theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  final int myId;
  const ChatListScreen({super.key, required this.myId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> chatList = [];
  bool isLoading = true;
  Timer? _refreshTimer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _markMyMessagesAsDelivered();
    _fetchChatList();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchChatList();
    });
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myId != widget.myId) {
      setState(() => isLoading = true);
      _markMyMessagesAsDelivered();
      _fetchChatList();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _markMyMessagesAsDelivered() async {
    try {
      await http
          .put(Uri.parse(
              "${ApiService.baseUrl}/mark_as_delivered/${widget.myId}"))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _fetchChatList() async {
    try {
      final response = await http
          .get(Uri.parse("${ApiService.baseUrl}/chats/${widget.myId}"))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        final newList = jsonDecode(response.body) as List<dynamic>;
        // Sadece içerik değiştiyse setState çağır
        final changed = newList.length != chatList.length ||
            (newList.isNotEmpty &&
                chatList.isNotEmpty &&
                (newList.first['receiver_id'] != chatList.first['receiver_id'] ||
                    newList.first['last_message'] !=
                        chatList.first['last_message'] ||
                    newList.first['unread_count'] !=
                        chatList.first['unread_count']));

        if (changed || isLoading) {
          setState(() {
            chatList = newList;
            isLoading = false;
          });
          _animController.forward(from: 0);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteChat(int otherId, int bookId) async {
    try {
      final response = await http.delete(Uri.parse(
        "${ApiService.baseUrl}/chats/delete?my_id=${widget.myId}&other_id=$otherId&book_id=$bookId",
      ));
      if (response.statusCode == 200) {
        _fetchChatList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Sohbet silindi"),
              backgroundColor: AppTheme.primaryIndigo,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myId == 0) return _buildLoginPrompt();

    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Stack(
        children: [
          // Arka plan gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF3F0FF),
                    Color(0xFFFFF5F0),
                    Color(0xFFF5F5F7),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryIndigo))
                      : chatList.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchChatList,
                              color: AppTheme.primaryIndigo,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 24),
                                  itemCount: chatList.length,
                                  itemBuilder: (context, index) {
                                    return _buildChatCard(
                                        chatList[index], index);
                                  },
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Başlık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mesajlarım",
                  style: AppTheme.textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (chatList.isNotEmpty)
                  Text(
                    "${chatList.length} sohbet",
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutralDark,
                    ),
                  ),
              ],
            ),
          ),
          // Yenile butonu
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => isLoading = true);
              _fetchChatList();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.shadowSM,
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.primaryIndigo, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard(dynamic chat, int index) {
    final int unreadCount = chat['unread_count'] ?? 0;
    final String? profileImage = chat['profile_image'];
    final String receiverName =
        (chat['receiver_name'] ?? "Bilinmeyen Kullanıcı").toString();
    final String lastMessage =
        chat['last_message'] ?? "Henüz mesaj yok...";
    final bool hasUnread = unreadCount > 0;

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _fadeAnim.value)),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: hasUnread
              ? Border.all(
                  color: AppTheme.primaryIndigo.withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: hasUnread
                  ? AppTheme.primaryIndigo.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    receiverId: chat['receiver_id'],
                    receiverName: receiverName,
                    receiverImage: profileImage,
                    bookTitle: chat['book_title'] ?? '',
                    bookId: chat['book_id'],
                    myId: widget.myId,
                    myName: "Ben",
                  ),
                ),
              );
              _fetchChatList();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  _buildAvatar(profileImage, receiverName, hasUnread),
                  const SizedBox(width: 14),

                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                receiverName,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.neutralBlack,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? "99+"
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Kitap etiketi
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_rounded,
                                      size: 10,
                                      color: AppTheme.accentOrange),
                                  const SizedBox(width: 3),
                                  Text(
                                    chat['book_title'] ?? '',
                                    style: TextStyle(
                                      color: AppTheme.accentOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Son mesaj
                        Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? AppTheme.neutralBlack
                                : AppTheme.neutralDark,
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Sil butonu
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showDeleteDialog(chat);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          color: AppTheme.errorRed, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
      String? profileImage, String name, bool hasUnread) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasUnread ? AppTheme.primaryGradient : null,
            color: hasUnread ? null : AppTheme.neutralMedium,
            boxShadow: hasUnread ? AppTheme.shadowPrimary : null,
          ),
          child: ClipOval(
            child: profileImage != null && profileImage.isNotEmpty
                ? Image.network(
                    "${ApiService.baseUrl}/${profileImage.replaceAll('\\', '/')}",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarText(name, hasUnread),
                  )
                : _avatarText(name, hasUnread),
          ),
        ),
        // Online göstergesi (okunmamış varsa)
        if (hasUnread)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppTheme.successGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarText(String name, bool hasUnread) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: hasUnread ? Colors.white : AppTheme.neutralDark,
        ),
      ),
    );
  }

  void _showDeleteDialog(dynamic chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sohbeti Sil",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Bu sohbeti silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("İptal",
                style: TextStyle(color: AppTheme.neutralDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              deleteChat(chat['receiver_id'], chat['book_id']);
            },
            child: const Text("Sil",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.shadowPrimary,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 60, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text(
                "Giriş Yapmalısınız",
                style: AppTheme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Mesajlarınızı görmek için lütfen önce hesabınıza giriş yapın.",
                textAlign: TextAlign.center,
                style: AppTheme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Ana Sayfaya Dön",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 60, color: AppTheme.primaryIndigo.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            "Henüz bir mesajın yok",
            style: AppTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.neutralBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Bir kitap ilanından satıcıya\nmesaj gönderebilirsin.",
            textAlign: TextAlign.center,
            style: AppTheme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
