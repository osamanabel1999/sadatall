import 'package:flutter/material.dart';
import '../data/chat_repository.dart';
import '../models/chat_thread.dart';

/// Inbox of a participant's chat threads, newest activity first. Used where
/// a mode can have more than one active/past chat at once (e.g. a captain's
/// order-scoped chats across several deliveries).
class ChatListScreen extends StatelessWidget {
  final ChatRepository repository;
  final String participantId;
  final String title;
  final Color accentColor;
  final void Function(BuildContext context, ChatThread thread) onOpenThread;
  final String Function(ChatThread thread) threadTitleBuilder;

  const ChatListScreen({
    super.key,
    required this.repository,
    required this.participantId,
    required this.title,
    required this.accentColor,
    required this.onOpenThread,
    required this.threadTitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: accentColor, foregroundColor: Colors.white),
      body: StreamBuilder<List<ChatThread>>(
        stream: repository.streamThreadsFor(participantId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final threads = snapshot.data!;
          if (threads.isEmpty) {
            return const Center(child: Text('لا توجد محادثات بعد', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final unread = thread.unreadCount;
              return ListTile(
                leading: CircleAvatar(backgroundColor: accentColor.withOpacity(0.15), child: Icon(Icons.chat_bubble, color: accentColor)),
                title: Text(threadTitleBuilder(thread)),
                subtitle: Text(
                  thread.lastMessage.text.isEmpty ? 'لا توجد رسائل بعد' : thread.lastMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? CircleAvatar(radius: 11, backgroundColor: accentColor, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)))
                    : (thread.status != ChatStatus.open ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) : null),
                onTap: () => onOpenThread(context, thread),
              );
            },
          );
        },
      ),
    );
  }
}
