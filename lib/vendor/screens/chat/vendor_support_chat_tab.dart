import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/order_service.dart';
import '../orders/order_details_screen.dart';
import '../../../shared/chat/data/chat_repository.dart';
import '../../../shared/chat/models/chat_message.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'vendor_chat_attachment_uploader.dart';

const Color _vendorAccent = Color(0xFFFFC107);

/// vendor<->admin support chat — one persistent thread, always open.
class VendorSupportChatTab extends StatelessWidget {
  const VendorSupportChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<AuthProvider>().currentVendor;
    if (vendor == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول للوصول إلى الدعم', style: TextStyle(color: Colors.grey))),
      );
    }

    final self = ChatParticipant(role: ChatRole.vendor, id: vendor.id, displayName: vendor.vendorName);
    final repo = ChatRepository();

    return ChatScreen(
      openThread: () => repo.getOrCreateSupportChat(self),
      self: self,
      otherParticipantId: ChatParticipant.admin().participantId,
      title: 'الدعم',
      accentColor: _vendorAccent,
      attachmentService: buildVendorChatAttachmentService(),
      getCurrentLocation: () async {
        final result = await LocationService().getCurrentLocation();
        if (!result.success || result.latitude == null || result.longitude == null) return null;
        return (lat: result.latitude!, lng: result.longitude!);
      },
      onOrderRefTap: (OrderRef ref) => _openOrder(context, ref.orderId),
    );
  }

  Future<void> _openOrder(BuildContext context, String orderId) async {
    final response = await OrderService().getOrderById(orderId);
    if (response.success && response.data != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: response.data!),
      ));
    }
  }
}
