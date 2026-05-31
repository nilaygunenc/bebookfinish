class ChatMessage {
  final int? id;
  final int senderId;
  final int receiverId;
  final int bookId;
  final String messageText;
  final DateTime createdAt;
  final bool isRead;
  final bool isDelivered;

  ChatMessage({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.bookId,
    required this.messageText,
    required this.createdAt,
    required this.isRead,
    required this.isDelivered,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender_id'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      bookId: json['book_id'] ?? 0,
      messageText: json['message_text'] ?? "",
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      isDelivered: json['is_delivered'] == true || json['is_delivered'] == 1,
    );
  }

  // Geçici mesajı gerçek mesajla güncellemek için
  ChatMessage copyWith({
    int? id,
    bool? isRead,
    bool? isDelivered,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      receiverId: receiverId,
      bookId: bookId,
      messageText: messageText,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
    );
  }
}
