import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/location_service.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'captain_chat_attachment_uploader.dart';
import 'captain_chat_client.dart';

/// captain<->admin support chat — one persistent thread, always open.
/// Reached from the drawer (see lib/captain/main_navigation.dart) since the
/// bottom nav is already full with the four order-management tabs.
class CaptainSupportChatScreen extends ConsumerWidget {
  const CaptainSupportChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captain = ref.watch(authStateProvider).captain;
    if (captain == null) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));
    }

    final self = ChatParticipant(role: ChatRole.captain, id: captain.id, displayName: captain.userName);
    final repo = buildCaptainChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateSupportChat(self),
      self: self,
      otherParticipantId: ChatParticipant.admin().participantId,
      title: 'الدعم',
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
