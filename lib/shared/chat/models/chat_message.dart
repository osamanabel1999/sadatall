import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory ChatLocation.fromMap(Map<String, dynamic> map) =>
      ChatLocation(lat: (map['lat'] as num).toDouble(), lng: (map['lng'] as num).toDouble());

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
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

  factory OrderRef.fromMap(Map<String, dynamic> map) => OrderRef(
        orderId: map['orderId'] as String? ?? '',
        orderNumber: map['orderNumber'] as String? ?? '',
        statusSnapshot: map['statusSnapshot'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'statusSnapshot': statusSnapshot,
      };
}

/// Mirrors a `chats/{chatId}/messages/{messageId}` Firestore document.
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

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final locationMap = data['location'] as Map<String, dynamic>?;
    final orderRefMap = data['orderRef'] as Map<String, dynamic>?;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderRole: chatRoleFromString(data['senderRole'] as String? ?? 'user'),
      type: messageTypeFromString(data['type'] as String? ?? 'text'),
      text: data['text'] as String?,
      attachmentKey: data['attachmentKey'] as String?,
      attachmentUrl: data['attachmentUrl'] as String?,
      location: locationMap == null ? null : ChatLocation.fromMap(locationMap),
      orderRef: orderRefMap == null ? null : OrderRef.fromMap(orderRefMap),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}
