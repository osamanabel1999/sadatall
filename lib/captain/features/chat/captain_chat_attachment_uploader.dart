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
    if (token == null) return null;

    final uri = Uri.parse('${ApiConfig.baseUrl}/chat-uploads');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(ApiConfig.getAuthHeaders(token));
    request.fields['chatId'] = chatId;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final body = jsonDecode(response.body);
    if (body['success'] != true || body['data'] == null) return null;
    final data = body['data'] as Map<String, dynamic>;
    return ChatUploadResult(key: data['key'] as String, url: data['url'] as String);
  });
}
