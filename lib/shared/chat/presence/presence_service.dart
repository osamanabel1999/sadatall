import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Firestore-only presence approximation: a heartbeat doc updated every ~20s
/// while foregrounded, plus a typing flag debounced on composer input.
/// This is not a true `onDisconnect` presence system (that needs Realtime
/// Database) — "online" reads as "seen in the last ~45s", which is good
/// enough for the spec's "متصل الآن/آخر ظهور" requirement.
class PresenceService with WidgetsBindingObserver {
  PresenceService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  Timer? _heartbeat;
  String? _participantId;
  Timer? _typingDebounce;
  String? _typingChatId;

  DocumentReference<Map<String, dynamic>> _doc(String participantId) =>
      _db.collection('presence').doc(participantId);

  void start(String participantId) {
    _participantId = participantId;
    WidgetsBinding.instance.addObserver(this);
    _beat();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) => _beat());
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _typingDebounce?.cancel();
    final id = _participantId;
    if (id != null) {
      _doc(id).set({'online': false, 'lastActiveAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  }

  void _beat() {
    final id = _participantId;
    if (id == null) return;
    _doc(id).set({'online': true, 'lastActiveAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final id = _participantId;
    if (id == null) return;
    final online = state == AppLifecycleState.resumed;
    _doc(id).set({'online': online, 'lastActiveAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Call on every composer text change; debounces writes and auto-clears
  /// after 4s of no typing.
  void setTyping(String chatId) {
    final id = _participantId;
    if (id == null) return;
    _typingChatId = chatId;
    _typingDebounce?.cancel();
    _doc(id).set({'typingInChatId': chatId}, SetOptions(merge: true));
    _typingDebounce = Timer(const Duration(seconds: 4), clearTyping);
  }

  void clearTyping() {
    final id = _participantId;
    if (id == null || _typingChatId == null) return;
    _doc(id).set({'typingInChatId': null}, SetOptions(merge: true));
    _typingChatId = null;
  }

  Stream<bool> otherIsTyping(String otherParticipantId, String chatId) {
    return _doc(otherParticipantId).snapshots().map((s) => s.data()?['typingInChatId'] == chatId);
  }

  Stream<({bool online, DateTime? lastActiveAt})> presenceOf(String participantId) {
    return _doc(participantId).snapshots().map((s) {
      final data = s.data();
      final ts = data?['lastActiveAt'] as Timestamp?;
      final lastActiveAt = ts?.toDate();
      final online = data?['online'] == true &&
          lastActiveAt != null &&
          DateTime.now().difference(lastActiveAt) < const Duration(seconds: 45);
      return (online: online, lastActiveAt: lastActiveAt);
    });
  }
}
