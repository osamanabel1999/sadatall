import 'dart:io';

/// Uploads a chat attachment and returns its storage key + a resolved URL.
/// Each mode wires this to its own network stack (captain's ApiClient,
/// vendor/user's Dio-based ApiService) so the shared chat module never has
/// to import a specific mode's services.
typedef ChatAttachmentUploader = Future<ChatUploadResult?> Function({
  required File file,
  required String chatId,
});

class ChatUploadResult {
  final String key;
  final String url;
  const ChatUploadResult({required this.key, required this.url});
}

/// Thin wrapper so chat screens depend on one small interface instead of
/// a raw function type.
class ChatAttachmentService {
  final ChatAttachmentUploader _upload;
  const ChatAttachmentService(this._upload);

  Future<ChatUploadResult?> upload({required File file, required String chatId}) {
    return _upload(file: file, chatId: chatId);
  }
}
