import 'dart:async';
import '../data/chat_socket_client.dart';

/// Presence/typing over the shared Socket.io connection — "online" is
/// simply "has an active socket connection" (tracked server-side), so
/// unlike the old Firestore heartbeat-doc approach there's nothing to
/// write here, only to listen to.
class PresenceService {
  PresenceService(this._socket);

  final ChatSocketClient _socket;
  Timer? _typingDebounce;
  String? _typingChatId;

  /// Call on every composer text change; debounced so it doesn't emit on
  /// every keystroke.
  void setTyping(String chatId) {
    if (_typingDebounce != null && _typingChatId == chatId) return;
    _typingChatId = chatId;
    _socket.emitTyping(chatId);
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _typingDebounce = null;
    });
  }

  /// True while [otherParticipantId] is typing in [chatId] — auto-clears
  /// ~3s after the last "typing" event since the server doesn't send an
  /// explicit "stopped typing" event.
  Stream<bool> otherIsTyping(String otherParticipantId, String chatId) {
    late StreamController<bool> controller;
    StreamSubscription? sub;
    Timer? clearTimer;

    controller = StreamController<bool>.broadcast(
      onListen: () {
        controller.add(false);
        sub = _socket.typingEvents.listen((data) {
          if (data['chatId'] != chatId || data['participantId'] != otherParticipantId) return;
          controller.add(true);
          clearTimer?.cancel();
          clearTimer = Timer(const Duration(seconds: 3), () {
            if (!controller.isClosed) controller.add(false);
          });
        });
      },
      onCancel: () {
        sub?.cancel();
        clearTimer?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<({bool online, DateTime? lastActiveAt})> presenceOf(String participantId) {
    late StreamController<({bool online, DateTime? lastActiveAt})> controller;
    StreamSubscription? sub;

    controller = StreamController.broadcast(
      onListen: () {
        // No initial snapshot endpoint — starts "unknown"/offline until the
        // first presence event for this participant arrives.
        controller.add((online: false, lastActiveAt: null));
        sub = _socket.presenceEvents.listen((data) {
          if (data['participantId'] != participantId) return;
          controller.add((online: data['online'] == true, lastActiveAt: DateTime.now()));
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}
