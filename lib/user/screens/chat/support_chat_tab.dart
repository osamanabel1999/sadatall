import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/user_order_service.dart';
import '../orders/order_details_screen.dart';
import '../../../shared/chat/models/chat_message.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'user_chat_attachment_uploader.dart';
import 'user_chat_client.dart';

/// user<->admin support chat — one persistent thread, always open. Wired as
/// a bottom-nav tab in lib/user/screens/main_screen.dart.
class SupportChatTab extends StatelessWidget {
  const SupportChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول للوصول إلى الدعم', style: TextStyle(color: Colors.grey))),
      );
    }

    final self = ChatParticipant(role: ChatRole.user, id: user.id, displayName: user.userName);
    final repo = buildUserChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateSupportChat(self),
      self: self,
      otherParticipantId: ChatParticipant.admin().participantId,
      title: 'الدعم',
      accentColor: AppTheme.primaryColor,
      attachmentService: buildUserChatAttachmentService(),
      getCurrentLocation: () async {
        final result = await LocationService().getCurrentLocation();
        if (!result.success || result.latitude == null || result.longitude == null) return null;
        return (lat: result.latitude!, lng: result.longitude!);
      },
      onOrderRefTap: (OrderRef ref) => _openOrder(context, ref.orderId),
    );
  }

  Future<void> _openOrder(BuildContext context, String orderId) async {
    final response = await UserOrderService().getOrderById(orderId);
    if (response.success && response.data != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: response.data!),
      ));
    }
  }
}
