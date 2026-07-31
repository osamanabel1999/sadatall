import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_thread.dart';

/// Order lifecycle statuses that gate order-scoped chats, mirrored from the
/// backend's shared Order status constants (see e.g.
/// lib/vendor/models/order.dart, lib/captain/features/orders/data/models/order_model.dart).
class OrderChatTrigger {
  static const String opensOn = 'ACCEPTED_BY_CAPTAIN';
  static const String closesOn = 'DELIVERED';
}

/// Firestore-backed data layer for the whole chat feature. Shared by every
/// mode (user/vendor/captain) and every chat type (support / order-scoped).
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messagesOf(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// All three Flutter modes hardcode this same tenant id today
  /// (AppConstants.tenantId = 'SADAT' in user/vendor; captain has no
  /// multi-tenant concept yet). Stored on each chat doc so the backend's
  /// FCM dispatcher can look up the right tenant-scoped actor.
  static const String defaultTenantId = 'SADAT';

  // ── chatId builders ──────────────────────────────────────────────────────

  static String supportChatId(ChatParticipant participant) {
    switch (participant.role) {
      case ChatRole.user:
        return 'support_user_${participant.id}';
      case ChatRole.vendor:
        return 'support_vendor_${participant.id}';
      default:
        throw ArgumentError('Only user/vendor have support chats');
    }
  }

  static String orderChatId(String orderId, {required bool isVendorSide}) {
    return isVendorSide ? 'order_${orderId}_vendor_captain' : 'order_${orderId}_user_captain';
  }

  // ── thread lookup / lazy creation ────────────────────────────────────────

  Future<ChatThread> getOrCreateSupportChat(ChatParticipant self) async {
    final chatId = supportChatId(self);
    final type = self.role == ChatRole.user ? ChatType.userAdmin : ChatType.vendorAdmin;
    final adminParticipantId = ChatParticipant.admin().participantId;
    return _getOrCreate(
      chatId: chatId,
      type: type,
      orderId: null,
      participantIds: [self.participantId, adminParticipantId],
      initialStatus: ChatStatus.open,
    );
  }

  Future<ChatThread> getOrCreateOrderChat({
    required String orderId,
    required ChatParticipant self,
    required ChatParticipant other,
    required bool isVendorSide,
  }) async {
    final chatId = orderChatId(orderId, isVendorSide: isVendorSide);
    final type = isVendorSide ? ChatType.vendorCaptain : ChatType.userCaptain;
    return _getOrCreate(
      chatId: chatId,
      type: type,
      orderId: orderId,
      participantIds: [self.participantId, other.participantId],
      initialStatus: ChatStatus.open,
    );
  }

  Future<ChatThread> _getOrCreate({
    required String chatId,
    required ChatType type,
    required String? orderId,
    required List<String> participantIds,
    required ChatStatus initialStatus,
  }) async {
    final ref = _chats.doc(chatId);
    final snap = await ref.get();
    if (snap.exists) {
      return ChatThread.fromSnapshot(snap);
    }
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'type': chatTypeToString(type),
      'tenantId': defaultTenantId,
      'orderId': orderId,
      'participantIds': participantIds,
      'status': chatStatusToString(initialStatus),
      'lastMessage': {'text': '', 'type': 'text', 'senderId': '', 'sentAt': now},
      'unreadCount': {for (final id in participantIds) id: 0},
      'createdAt': now,
      'updatedAt': now,
    });
    final created = await ref.get();
    return ChatThread.fromSnapshot(created);
  }

  /// Flips an order-scoped chat's status when the order transitions, e.g.
  /// read-only once the order is DELIVERED. Safe to call even if the chat
  /// doesn't exist yet (no-op) — chats are created lazily on first message.
  Future<void> syncChatStatusToOrderStatus(String orderId, String orderStatus) async {
    ChatStatus? next;
    if (orderStatus == OrderChatTrigger.closesOn) {
      next = ChatStatus.readOnly;
    } else if (orderStatus == OrderChatTrigger.opensOn) {
      next = ChatStatus.open;
    }
    if (next == null) return;

    for (final chatId in [
      orderChatId(orderId, isVendorSide: false),
      orderChatId(orderId, isVendorSide: true),
    ]) {
      final ref = _chats.doc(chatId);
      final snap = await ref.get();
      if (!snap.exists) continue;
      await ref.update({'status': chatStatusToString(next), 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  // ── streams ───────────────────────────────────────────────────────────────

  Stream<ChatThread?> streamChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((s) => s.exists ? ChatThread.fromSnapshot(s) : null);
  }

  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 200}) {
    return _messagesOf(chatId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map(ChatMessage.fromSnapshot).toList());
  }

  /// All threads a participant is in, newest activity first — powers a
  /// chat-list / inbox screen.
  Stream<List<ChatThread>> streamThreadsFor(String participantId) {
    return _chats
        .where('participantIds', arrayContains: participantId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(ChatThread.fromSnapshot).toList());
  }

  // ── sending ───────────────────────────────────────────────────────────────

  Future<void> sendTextMessage({
    required String chatId,
    required ChatParticipant sender,
    required String text,
  }) => _sendMessage(chatId: chatId, sender: sender, type: MessageType.text, text: text, previewText: text);

  Future<void> sendAttachmentMessage({
    required String chatId,
    required ChatParticipant sender,
    required MessageType type,
    required String attachmentKey,
    String? attachmentUrl,
    String? caption,
  }) {
    const previewByType = {
      MessageType.image: '📷 صورة',
      MessageType.voice: '🎤 رسالة صوتية',
      MessageType.file: '📄 ملف',
      MessageType.video: '🎬 فيديو',
    };
    return _sendMessage(
      chatId: chatId,
      sender: sender,
      type: type,
      text: caption,
      attachmentKey: attachmentKey,
      attachmentUrl: attachmentUrl,
      previewText: previewByType[type] ?? 'مرفق',
    );
  }

  Future<void> sendLocationMessage({
    required String chatId,
    required ChatParticipant sender,
    required double lat,
    required double lng,
  }) => _sendMessage(
        chatId: chatId,
        sender: sender,
        type: MessageType.location,
        location: ChatLocation(lat: lat, lng: lng),
        previewText: '📍 موقع',
      );

  Future<void> sendOrderRefMessage({
    required String chatId,
    required ChatParticipant sender,
    required OrderRef orderRef,
  }) => _sendMessage(
        chatId: chatId,
        sender: sender,
        type: MessageType.orderRef,
        orderRef: orderRef,
        previewText: '🧾 طلب #${orderRef.orderNumber}',
      );

  Future<void> _sendMessage({
    required String chatId,
    required ChatParticipant sender,
    required MessageType type,
    required String previewText,
    String? text,
    String? attachmentKey,
    String? attachmentUrl,
    ChatLocation? location,
    OrderRef? orderRef,
  }) async {
    final chatRef = _chats.doc(chatId);
    final now = FieldValue.serverTimestamp();

    final messageData = <String, dynamic>{
      'senderId': sender.participantId,
      'senderRole': sender.role.name,
      'type': messageTypeToString(type),
      'text': text,
      'attachmentKey': attachmentKey,
      'attachmentUrl': attachmentUrl,
      'location': location?.toMap(),
      'orderRef': orderRef?.toMap(),
      'sentAt': now,
      'readBy': [sender.participantId],
      'isDeleted': false,
    };

    final batch = _db.batch();
    batch.set(_messagesOf(chatId).doc(), messageData);

    final chatSnap = await chatRef.get();
    final participantIds = List<String>.from(chatSnap.data()?['participantIds'] as List? ?? const []);
    final unread = Map<String, dynamic>.from(chatSnap.data()?['unreadCount'] as Map? ?? const {});
    for (final id in participantIds) {
      if (id == sender.participantId) continue;
      unread[id] = ((unread[id] as int?) ?? 0) + 1;
    }

    batch.update(chatRef, {
      'lastMessage': {
        'text': text ?? previewText,
        'type': messageTypeToString(type),
        'senderId': sender.participantId,
        'sentAt': now,
      },
      'unreadCount': unread,
      'updatedAt': now,
    });

    await batch.commit();
  }

  // ── read receipts / typing ──────────────────────────────────────────────

  Future<void> markThreadRead(String chatId, String participantId) async {
    await _chats.doc(chatId).update({'unreadCount.$participantId': 0});
  }

  Future<void> markMessagesRead({
    required String chatId,
    required String participantId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.update(_messagesOf(chatId).doc(id), {
        'readBy': FieldValue.arrayUnion([participantId]),
      });
    }
    await batch.commit();
  }

  Future<void> softDeleteMessage(String chatId, String messageId) async {
    await _messagesOf(chatId).doc(messageId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }
}
