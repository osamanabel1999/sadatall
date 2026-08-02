import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'user_chat_attachment_uploader.dart';
import 'user_chat_client.dart';

/// user<->captain order-scoped chat. Opens once a captain is assigned
/// (order.captain != null) and becomes read-only once the order is
/// DELIVERED — the backend syncs the thread's status to [orderStatus] as
/// part of getOrCreateOrderChat, so it reflects the order's current state
/// even if no earlier call caught the transition.
class OrderChatScreen extends StatelessWidget {
  final String orderId;
  final String captainId;
  final String captainName;
  final String orderStatus;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.captainId,
    required this.captainName,
    required this.orderStatus,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    final self = ChatParticipant(role: ChatRole.user, id: user.id, displayName: user.userName);
    final other = ChatParticipant(role: ChatRole.captain, id: captainId, displayName: captainName);
    final repo = buildUserChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateOrderChat(
        orderId: orderId,
        self: self,
        other: other,
        isVendorSide: false,
        orderStatus: orderStatus,
      ),
      self: self,
      otherParticipantId: other.participantId,
      title: captainName,
      accentColor: AppTheme.primaryColor,
      attachmentService: buildUserChatAttachmentService(),
      getCurrentLocation: () async {
        final result = await LocationService().getCurrentLocation();
        if (!result.success || result.latitude == null || result.longitude == null) return null;
        return (lat: result.latitude!, lng: result.longitude!);
      },
    );
  }
}
