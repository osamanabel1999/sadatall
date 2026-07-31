import 'dart:io';
import '../../services/api_service.dart';
import '../../../shared/chat/data/chat_attachment_service.dart';

ChatAttachmentService buildUserChatAttachmentService() {
  final api = ApiService();
  return ChatAttachmentService(({required File file, required String chatId}) async {
    final response = await api.uploadFile<Map<String, dynamic>>(
      '/chat-uploads',
      file: file,
      fieldName: 'file',
      data: {'chatId': chatId},
    );
    if (!response.success || response.data == null) return null;
    final body = response.data!;
    final data = body.containsKey('data') ? body['data'] as Map<String, dynamic>? : body;
    if (data == null) return null;
    return ChatUploadResult(key: data['key'] as String, url: data['url'] as String);
  });
}
