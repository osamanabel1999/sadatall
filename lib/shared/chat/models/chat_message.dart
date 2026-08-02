import 'chat_participant.dart';

enum MessageType { text, image, voice, location, orderRef, file, video, system }

const Map<MessageType, String> _messageTypeStrings = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.voice: 'voice',
  MessageType.location: 'location',
  MessageType.orderRef: 'order_ref',
  MessageType.file: 'file',
  MessageType.video: 'video',
  MessageType.system: 'system',
};

String messageTypeToString(MessageType type) => _messageTypeStrings[type]!;

MessageType messageTypeFromString(String value) {
  return _messageTypeStrings.entries
      .firstWhere((e) => e.value == value, orElse: () => const MapEntry(MessageType.text, 'text'))
      .key;
}

class ChatLocation {
  final double lat;
  final double lng;
  const ChatLocation({required this.lat, required this.lng});

  factory ChatLocation.fromJson(Map<String, dynamic> json) =>
      ChatLocation(lat: (json['lat'] as num).toDouble(), lng: (json['lng'] as num).toDouble());

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class OrderRef {
  final String orderId;
  final String orderNumber;
  final String statusSnapshot;

  const OrderRef({
    required this.orderId,
    required this.orderNumber,
    required this.statusSnapshot,
  });

  factory OrderRef.fromJson(Map<String, dynamic> json) => OrderRef(
        orderId: json['order_id'] as String? ?? '',
        orderNumber: json['order_number'] as String? ?? '',
        statusSnapshot: json['status_snapshot'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'statusSnapshot': statusSnapshot,
      };
}

/// Mirrors a `chat_messages` row from the backend's REST API / socket
/// events (GET /api/chats/:chatId/messages, "new_message" socket event).
class ChatMessage {
  final String id;
  final String senderId;
  final ChatRole senderRole;
  final MessageType type;
  final String? text;
  final String? attachmentKey;
  final String? attachmentUrl;
  final ChatLocation? location;
  final OrderRef? orderRef;
  final DateTime? sentAt;
  final List<String> readBy;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.type,
    this.text,
    this.attachmentKey,
    this.attachmentUrl,
    this.location,
    this.orderRef,
    this.sentAt,
    this.readBy = const [],
    this.isDeleted = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'] as Map<String, dynamic>?;
    final orderRefJson = json['order_ref'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      senderRole: chatRoleFromString(json['sender_role'] as String? ?? 'user'),
      type: messageTypeFromString(json['type'] as String? ?? 'text'),
      text: json['text'] as String?,
      attachmentKey: json['attachment_key'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      location: locationJson == null ? null : ChatLocation.fromJson(locationJson),
      orderRef: orderRefJson == null ? null : OrderRef.fromJson(orderRefJson),
      sentAt: json['sent_at'] == null ? null : DateTime.parse(json['sent_at'] as String),
      readBy: List<String>.from(json['read_by'] as List? ?? const []),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}
