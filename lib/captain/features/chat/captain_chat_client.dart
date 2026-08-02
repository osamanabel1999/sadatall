import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';
import '../../../shared/chat/data/chat_api_client.dart';
import '../../../shared/chat/data/chat_repository.dart';
import '../../../shared/chat/data/chat_socket_client.dart';

ChatRepository? _cached;

/// One ChatRepository (and one underlying socket connection) per app
/// session — every captain-mode chat screen shares this instance rather
/// than each opening its own socket.
ChatRepository buildCaptainChatRepository() {
  final cached = _cached;
  if (cached != null) return cached;

  final apiClient = ApiClient();
  final storage = StorageService();

  final chatApi = ChatApiClient(
    getFn: (path, {query}) async {
      final response = await apiClient.get<Map<String, dynamic>>(
        path,
        queryParams: query?.map((k, v) => MapEntry(k, v.toString())),
      );
      if (!response.success || response.data == null) throw Exception(response.error ?? 'تعذر إتمام الطلب');
      return response.data!;
    },
    postFn: (path, {body}) async {
      final response = await apiClient.post<Map<String, dynamic>>(
        path,
        body: body is Map<String, dynamic> ? body : null,
      );
      if (!response.success) throw Exception(response.error ?? 'تعذر إتمام الطلب');
      return response.data ?? {};
    },
    putFn: (path, {body}) async {
      final response = await apiClient.put<Map<String, dynamic>>(
        path,
        body: body is Map<String, dynamic> ? body : null,
      );
      if (!response.success) throw Exception(response.error ?? 'تعذر إتمام الطلب');
      return response.data ?? {};
    },
    deleteFn: (path) async {
      final response = await apiClient.delete(path);
      if (!response.success) throw Exception(response.error ?? 'تعذر إتمام الطلب');
    },
  );

  final socket = ChatSocketClient(
    baseUrl: ApiConfig.baseUrl,
    getToken: () => storage.getSecureString(StorageService.keyAuthToken),
  );
  return _cached = ChatRepository(api: chatApi, socket: socket);
}
