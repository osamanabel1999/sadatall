import 'package:flutter/material.dart';
import '../../presence/presence_service.dart';

class PresenceDot extends StatelessWidget {
  final PresenceService presence;
  final String participantId;

  const PresenceDot({super.key, required this.presence, required this.participantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: presence.presenceOf(participantId),
      builder: (context, snapshot) {
        final online = snapshot.data?.online ?? false;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: online ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
      },
    );
  }
}

String presenceLabel(({bool online, DateTime? lastActiveAt}) data) {
  if (data.online) return 'متصل الآن';
  final last = data.lastActiveAt;
  if (last == null) return '';
  final diff = DateTime.now().difference(last);
  if (diff.inMinutes < 1) return 'آخر ظهور الآن';
  if (diff.inMinutes < 60) return 'آخر ظهور منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'آخر ظهور منذ ${diff.inHours} س';
  return 'آخر ظهور منذ ${diff.inDays} يوم';
}
