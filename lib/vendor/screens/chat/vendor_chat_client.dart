import '../../services/api_service.dart';
import '../../../shared/chat/data/chat_api_client.dart';
import '../../../shared/chat/data/chat_repository.dart';
import '../../../shared/chat/data/chat_socket_client.dart';

ChatRepository? _cached;

/// One ChatRepository (and one underlying socket connection) per app
/// session — every vendor-mode chat screen shares this instance rather
/// than each opening its own socket.
ChatRepository buildVendorChatRepository() {
  final cached = _cached;
  if (cached != null) return cached;

  final api = ApiService();

  final apiClient = ChatApiClient(
    getFn: (path, {query}) async {
      final response = await api.get<Map<String, dynamic>>(path, queryParameters: query);
      if (!response.success || response.data == null) {
        throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      }
      // Vendor's ApiResponse already unwraps the top-level "data" envelope.
      return response.data!;
    },
    postFn: (path, {body}) async {
      final response = await api.post<Map<String, dynamic>>(path, data: body);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      return response.data ?? {};
    },
    putFn: (path, {body}) async {
      final response = await api.put<Map<String, dynamic>>(path, data: body);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
      return response.data ?? {};
    },
    deleteFn: (path) async {
      final response = await api.delete(path);
      if (!response.success) throw Exception(response.error ?? response.message ?? 'تعذر إتمام الطلب');
    },
  );

  final socket = ChatSocketClient(baseUrl: api.baseUrl, getToken: () => api.accessToken);
  return _cached = ChatRepository(api: apiClient, socket: socket);
}
