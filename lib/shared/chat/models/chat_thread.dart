enum ChatType { userAdmin, userCaptain, vendorCaptain, vendorAdmin, captainAdmin }

const Map<ChatType, String> _chatTypeStrings = {
  ChatType.userAdmin: 'user_admin',
  ChatType.userCaptain: 'user_captain',
  ChatType.vendorCaptain: 'vendor_captain',
  ChatType.vendorAdmin: 'vendor_admin',
  ChatType.captainAdmin: 'captain_admin',
};

String chatTypeToString(ChatType type) => _chatTypeStrings[type]!;

ChatType chatTypeFromString(String value) {
  return _chatTypeStrings.entries
      .firstWhere((e) => e.value == value, orElse: () => const MapEntry(ChatType.userAdmin, 'user_admin'))
      .key;
}

enum ChatStatus { open, readOnly, closed }

ChatStatus chatStatusFromString(String value) {
  switch (value) {
    case 'read_only':
      return ChatStatus.readOnly;
    case 'closed':
      return ChatStatus.closed;
    default:
      return ChatStatus.open;
  }
}

class ChatLastMessage {
  final String text;
  final String type;
  final String senderId;
  final DateTime? sentAt;

  const ChatLastMessage({
    required this.text,
    required this.type,
    required this.senderId,
    this.sentAt,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatLastMessage(text: '', type: 'text', senderId: '');
    }
    return ChatLastMessage(
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      senderId: json['sender_id'] as String? ?? '',
      sentAt: json['sent_at'] == null ? null : DateTime.parse(json['sent_at'] as String),
    );
  }
}

/// Mirrors a `chats/{chatId}` row from the backend's REST API
/// (GET/POST /api/chats/...).
class ChatThread {
  final String id;
  final ChatType type;
  final String tenantId;
  final String? orderId;
  final List<String> participantIds;
  final ChatStatus status;
  final ChatLastMessage lastMessage;
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatThread({
    required this.id,
    required this.type,
    required this.tenantId,
    required this.participantIds,
    required this.status,
    required this.lastMessage,
    required this.unreadCount,
    this.orderId,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      type: chatTypeFromString(json['type'] as String? ?? 'user_admin'),
      tenantId: json['tenant_id'] as String? ?? 'SADAT',
      orderId: json['order_id'] as String?,
      participantIds: List<String>.from(json['participant_ids'] as List? ?? const []),
      status: chatStatusFromString(json['status'] as String? ?? 'open'),
      lastMessage: ChatLastMessage.fromJson(json['last_message'] as Map<String, dynamic>?),
      unreadCount: json['unread_count'] as int? ?? 0,
      createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
    );
  }

  ChatThread copyWith({ChatStatus? status, int? unreadCount, ChatLastMessage? lastMessage, DateTime? updatedAt}) {
    return ChatThread(
      id: id,
      type: type,
      tenantId: tenantId,
      orderId: orderId,
      participantIds: participantIds,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
