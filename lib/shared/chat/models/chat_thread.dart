import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { userAdmin, userCaptain, vendorCaptain, vendorAdmin }

const Map<ChatType, String> _chatTypeStrings = {
  ChatType.userAdmin: 'user_admin',
  ChatType.userCaptain: 'user_captain',
  ChatType.vendorCaptain: 'vendor_captain',
  ChatType.vendorAdmin: 'vendor_admin',
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

String chatStatusToString(ChatStatus status) {
  switch (status) {
    case ChatStatus.readOnly:
      return 'read_only';
    case ChatStatus.closed:
      return 'closed';
    case ChatStatus.open:
      return 'open';
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

  factory ChatLastMessage.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ChatLastMessage(text: '', type: 'text', senderId: '');
    }
    return ChatLastMessage(
      text: map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      senderId: map['senderId'] as String? ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'type': type,
        'senderId': senderId,
        'sentAt': sentAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(sentAt!),
      };
}

/// Mirrors a `chats/{chatId}` Firestore document.
class ChatThread {
  final String id;
  final ChatType type;
  final String tenantId;
  final String? orderId;
  final List<String> participantIds;
  final ChatStatus status;
  final ChatLastMessage lastMessage;
  final Map<String, int> unreadCount;
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

  int unreadFor(String participantId) => unreadCount[participantId] ?? 0;

  factory ChatThread.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatThread(
      id: doc.id,
      type: chatTypeFromString(data['type'] as String? ?? 'user_admin'),
      tenantId: data['tenantId'] as String? ?? 'SADAT',
      orderId: data['orderId'] as String?,
      participantIds: List<String>.from(data['participantIds'] as List? ?? const []),
      status: chatStatusFromString(data['status'] as String? ?? 'open'),
      lastMessage: ChatLastMessage.fromMap(data['lastMessage'] as Map<String, dynamic>?),
      unreadCount: Map<String, int>.from(data['unreadCount'] as Map? ?? const {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
