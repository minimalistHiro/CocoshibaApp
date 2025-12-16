class UserChatThread {
  const UserChatThread({
    required this.id,
    required this.userName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.updatedAt,
  });

  final String id;
  final String userName;
  final String avatarUrl;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? updatedAt;
}

class UserChatMessage {
  const UserChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final DateTime? createdAt;
}
