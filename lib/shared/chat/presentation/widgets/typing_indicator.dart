import 'package:flutter/material.dart';
import '../../presence/presence_service.dart';

class TypingIndicator extends StatelessWidget {
  final PresenceService presence;
  final String otherParticipantId;
  final String chatId;

  const TypingIndicator({
    super.key,
    required this.presence,
    required this.otherParticipantId,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: presence.otherIsTyping(otherParticipantId, chatId),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('يكتب الآن...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}
