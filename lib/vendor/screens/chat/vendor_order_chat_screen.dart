import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'vendor_chat_attachment_uploader.dart';
import 'vendor_chat_client.dart';

const Color _vendorAccent = Color(0xFFFFC107);

/// vendor<->captain order-scoped chat.
class VendorOrderChatScreen extends StatelessWidget {
  final String orderId;
  final String captainId;
  final String captainName;
  final String orderStatus;

  const VendorOrderChatScreen({
    super.key,
    required this.orderId,
    required this.captainId,
    required this.captainName,
    required this.orderStatus,
  });

  @override
  Widget build(BuildContext context) {
    final vendor = context.read<AuthProvider>().currentVendor;
    if (vendor == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    final self = ChatParticipant(role: ChatRole.vendor, id: vendor.id, displayName: vendor.vendorName);
    final other = ChatParticipant(role: ChatRole.captain, id: captainId, displayName: captainName);
    final repo = buildVendorChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateOrderChat(
        orderId: orderId,
        self: self,
        other: other,
        isVendorSide: true,
        orderStatus: orderStatus,
      ),
      self: self,
      otherParticipantId: other.participantId,
      title: captainName,
      accentColor: _vendorAccent,
      attachmentService: buildVendorChatAttachmentService(),
      getCurrentLocation: () async {
        final result = await LocationService().getCurrentLocation();
        if (!result.success || result.latitude == null || result.longitude == null) return null;
        return (lat: result.latitude!, lng: result.longitude!);
      },
    );
  }
}
