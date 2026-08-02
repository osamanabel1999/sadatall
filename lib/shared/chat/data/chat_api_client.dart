/// Thin injection seam so the shared chat module never has to know which
/// mode's network stack (Dio-based ApiService for user/vendor, raw
/// http-based ApiClient for captain) it's running on top of — each mode's
/// wrapper supplies these four callbacks bound to its own already-working
/// base-URL resolution and auth-header interceptors (see e.g.
/// lib/user/screens/chat/user_chat_client.dart).
///
/// Every callback returns the already-unwrapped `data` field of the
/// backend's `{success, data, message}` envelope, and throws on any
/// non-success response (so callers can just await and catch).
class ChatApiClient {
  final Future<Map<String, dynamic>> Function(String path, {Map<String, dynamic>? query}) getFn;
  final Future<Map<String, dynamic>> Function(String path, {dynamic body}) postFn;
  final Future<Map<String, dynamic>> Function(String path, {dynamic body}) putFn;
  final Future<void> Function(String path) deleteFn;

  const ChatApiClient({
    required this.getFn,
    required this.postFn,
    required this.putFn,
    required this.deleteFn,
  });

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => getFn(path, query: query);
  Future<Map<String, dynamic>> post(String path, {dynamic body}) => postFn(path, body: body);
  Future<Map<String, dynamic>> put(String path, {dynamic body}) => putFn(path, body: body);
  Future<void> delete(String path) => deleteFn(path);
}
