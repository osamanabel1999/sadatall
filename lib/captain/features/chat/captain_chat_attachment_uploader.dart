import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../../shared/chat/data/chat_attachment_service.dart';

ChatAttachmentService buildCaptainChatAttachmentService() {
  final storage = StorageService();
  return ChatAttachmentService(({required File file, required String chatId}) async {
    final token = await storage.getSecureString(StorageService.keyAuthToken);
    if (token == null) {
      throw Exception('لا يمكن رفع المرفق: لم يتم تسجيل الدخول');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/chat-uploads');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(ApiConfig.getAuthHeaders(token));
    request.fields['chatId'] = chatId;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || body['success'] != true || body['data'] == null) {
      throw Exception(body['error'] ?? body['message'] ?? 'رفع المرفق فشل (${response.statusCode})');
    }
    final data = body['data'] as Map<String, dynamic>;
    if (data['key'] == null || data['url'] == null) {
      throw Exception('استجابة رفع المرفق غير مكتملة');
    }
    return ChatUploadResult(key: data['key'] as String, url: data['url'] as String);
  });
}
