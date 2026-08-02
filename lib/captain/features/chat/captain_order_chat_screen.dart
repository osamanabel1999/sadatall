import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/location_service.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'captain_chat_attachment_uploader.dart';
import 'captain_chat_client.dart';

/// captain-side of an order-scoped chat, with the counterpart being either
/// the customer (user) or the vendor for that order.
class CaptainOrderChatScreen extends ConsumerWidget {
  final String orderId;
  final String otherId;
  final String otherName;
  final bool isVendor;
  final String orderStatus;

  const CaptainOrderChatScreen({
    super.key,
    required this.orderId,
    required this.otherId,
    required this.otherName,
    required this.isVendor,
    required this.orderStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captain = ref.read(authStateProvider).captain;
    if (captain == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    final self = ChatParticipant(role: ChatRole.captain, id: captain.id, displayName: captain.userName);
    final other = ChatParticipant(
      role: isVendor ? ChatRole.vendor : ChatRole.user,
      id: otherId,
      displayName: otherName,
    );
    final repo = buildCaptainChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateOrderChat(
        orderId: orderId,
        self: self,
        other: other,
        isVendorSide: isVendor,
        orderStatus: orderStatus,
      ),
      self: self,
      otherParticipantId: other.participantId,
      title: otherName,
      accentColor: AppColors.primary,
      attachmentService: buildCaptainChatAttachmentService(),
      getCurrentLocation: () async {
        try {
          final position = await LocationService().getCurrentLocation();
          return (lat: position.latitude, lng: position.longitude);
        } catch (_) {
          return null;
        }
      },
    );
  }
}
