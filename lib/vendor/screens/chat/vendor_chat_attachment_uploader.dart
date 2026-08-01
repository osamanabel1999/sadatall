import 'dart:io';
import '../../services/api_service.dart';
import '../../../shared/chat/data/chat_attachment_service.dart';

ChatAttachmentService buildVendorChatAttachmentService() {
  final api = ApiService();
  return ChatAttachmentService(({required File file, required String chatId}) async {
    final response = await api.uploadFile<Map<String, dynamic>>(
      '/chat-uploads',
      file: file,
      fieldName: 'file',
      data: {'chatId': chatId},
    );
    // Vendor's ApiResponse already unwraps the top-level "data" envelope.
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'رفع المرفق فشل بدون سبب معروف');
    }
    final data = response.data!;
    if (data['key'] == null || data['url'] == null) {
      throw Exception('استجابة رفع المرفق غير مكتملة');
    }
    return ChatUploadResult(key: data['key'] as String, url: data['url'] as String);
  });
}
