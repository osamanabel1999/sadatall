import '../../services/api_service.dart';
import '../../../shared/chat/data/chat_api_client.dart';
import '../../../shared/chat/data/chat_repository.dart';
import '../../../shared/chat/data/chat_socket_client.dart';

ChatRepository? _cached;

Map<String, dynamic> _unwrap(Map<String, dynamic> body) =>
    body.containsKey('data') ? body['data'] as Map<String, dynamic> : body;

/// One ChatRepository (and one underlying socket connection) per app
/// session — every user-mode chat screen shares this instance rather than
/// each opening its own socket.
ChatRepository buildUserChatRepository() {
  final cached = _cached;
  if (cached != null) return cached;

  final api = ApiService();

  final apiClient = ChatApiClient(
    getFn: (path, {query}) async {
      final response = await api.get<Map<String, dynamic>>(path, queryParameters: query);
      if (!response.success || response.data == null) {
        throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      }
      return _unwrap(response.data!);
    },
    postFn: (path, {body}) async {
      final response = await api.post<Map<String, dynamic>>(path, data: body);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      return response.data == null ? {} : _unwrap(response.data!);
    },
    putFn: (path, {body}) async {
      final response = await api.put<Map<String, dynamic>>(path, data: body);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      return response.data == null ? {} : _unwrap(response.data!);
    },
    deleteFn: (path) async {
      final response = await api.delete(path);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
    },
  );

  final socket = ChatSocketClient(baseUrl: api.baseUrl, getToken: () => api.accessToken);
  return _cached = ChatRepository(api: apiClient, socket: socket);
}
