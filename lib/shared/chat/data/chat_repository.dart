import 'dart:async';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_thread.dart';
import 'chat_api_client.dart';
import 'chat_socket_client.dart';

/// Order lifecycle statuses that gate order-scoped chats, mirrored from the
/// backend's shared Order status constants.
class OrderChatTrigger {
  static const String opensOn = 'ACCEPTED_BY_CAPTAIN';
  static const String closesOn = 'DELIVERED';
}

/// Backend REST + Socket.io data layer for the chat feature (Postgres-backed
/// — see backend/src/services/chatService.js). One instance per mode,
/// shared across every chat screen in that mode so the underlying socket
/// connection is opened once per app session, not once per screen.
class ChatRepository {
  ChatRepository({required this.api, required this.socket});

  final ChatApiClient api;
  final ChatSocketClient socket;

  // ── thread lookup / lazy creation ────────────────────────────────────────

  Future<ChatThread> getOrCreateSupportChat(ChatParticipant self) async {
    await socket.ensureConnected();
    final json = await api.post('/chats/support');
    return ChatThread.fromJson(json);
  }

  Future<ChatThread> getOrCreateOrderChat({
    required String orderId,
    required ChatParticipant self,
    required ChatParticipant other,
    required bool isVendorSide,
    String? orderStatus,
  }) async {
    await socket.ensureConnected();
    final json = await api.post('/chats/order', body: {
      'orderId': orderId,
      'isVendorSide': isVendorSide,
      'otherRole': other.role.name,
      'otherId': other.id,
      if (orderStatus != null) 'orderStatus': orderStatus,
    });
    return ChatThread.fromJson(json);
  }

  // ── streams ───────────────────────────────────────────────────────────────

  /// Full message list for a chat, newest first — re-emits on every
  /// new_message socket event (matching the old Firestore snapshot
  /// semantics so chat_screen.dart didn't need to change its StreamBuilder
  /// usage).
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 200}) {
    late StreamController<List<ChatMessage>> controller;
    StreamSubscription? sub;
    final byId = <String, ChatMessage>{};

    void emit() {
      final list = byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
      if (!controller.isClosed) controller.add(list);
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      onListen: () async {
        socket.joinChat(chatId);
        sub = socket.newMessages.listen((data) {
          if (data['chatId'] != chatId) return;
          final message = ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
          byId[message.id] = message;
          emit();
        });
        try {
          final json = await api.get('/chats/$chatId/messages', query: {'limit': limit.toString()});
          final list = (json['messages'] as List).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)));
          for (final m in list) {
            byId[m.id] = m;
          }
          emit();
        } catch (_) {
          // Leave the stream open — a later socket event or retry can still
          // populate it; the UI shows a spinner until the first emit.
        }
      },
      onCancel: () {
        sub?.cancel();
        socket.leaveChat(chatId);
      },
    );
    return controller.stream;
  }

  /// All threads the current user is a participant in, newest activity
  /// first.
  Stream<List<ChatThread>> streamThreadsFor(String participantId) {
    late StreamController<List<ChatThread>> controller;
    StreamSubscription? threadSub;
    StreamSubscription? messageSub;
    final byId = <String, ChatThread>{};

    void emit() {
      final list = byId.values.toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> refresh() async {
      try {
        final json = await api.get('/chats');
        final list = (json['threads'] as List).map((t) => ChatThread.fromJson(Map<String, dynamic>.from(t as Map)));
        byId.clear();
        for (final t in list) {
          byId[t.id] = t;
        }
        emit();
      } catch (_) {}
    }

    controller = StreamController<List<ChatThread>>.broadcast(
      onListen: () async {
        await socket.ensureConnected();
        threadSub = socket.threadUpdates.listen((_) => refresh());
        // A brand-new chat's first message also means a brand-new thread
        // this participant may not have in `byId` yet — cheapest correct
        // fix is just re-fetching the list rather than tracking creation
        // separately.
        messageSub = socket.newMessages.listen((_) => refresh());
        await refresh();
      },
      onCancel: () {
        threadSub?.cancel();
        messageSub?.cancel();
      },
    );
    return controller.stream;
  }

  // ── sending ───────────────────────────────────────────────────────────────

  Future<void> sendTextMessage({
    required String chatId,
    required ChatParticipant sender,
    required String text,
  }) => api.post('/chats/$chatId/messages', body: {'type': 'text', 'text': text});

  Future<void> sendAttachmentMessage({
    required String chatId,
    required ChatParticipant sender,
    required MessageType type,
    required String attachmentKey,
    String? attachmentUrl,
    String? caption,
  }) => api.post('/chats/$chatId/messages', body: {
        'type': messageTypeToString(type),
        if (caption != null) 'text': caption,
        'attachmentKey': attachmentKey,
        'attachmentUrl': attachmentUrl,
      });

  Future<void> sendLocationMessage({
    required String chatId,
    required ChatParticipant sender,
    required double lat,
    required double lng,
  }) => api.post('/chats/$chatId/messages', body: {
        'type': 'location',
        'location': {'lat': lat, 'lng': lng},
      });

  Future<void> sendOrderRefMessage({
    required String chatId,
    required ChatParticipant sender,
    required OrderRef orderRef,
  }) => api.post('/chats/$chatId/messages', body: {
        'type': 'order_ref',
        'orderRef': {
          'orderId': orderRef.orderId,
          'orderNumber': orderRef.orderNumber,
          'statusSnapshot': orderRef.statusSnapshot,
        },
      });

  // ── read receipts / typing ──────────────────────────────────────────────

  /// Marks every message in the chat read up to now for [participantId].
  /// Per-message read state is derived server-side from this timestamp, so
  /// there's no separate "mark these message ids read" call needed anymore.
  Future<void> markThreadRead(String chatId, String participantId) => api.put('/chats/$chatId/read');

  Future<void> softDeleteMessage(String chatId, String messageId) => api.delete('/chats/$chatId/messages/$messageId');
}
