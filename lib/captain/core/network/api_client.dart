import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:jwt_decode/jwt_decode.dart';
import '../config/api_config.dart';
import '../errors/api_exception.dart';
import 'api_response.dart';
import '../services/storage_service.dart';
import '../utils/app_utils.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  final StorageService _storageService = StorageService();
  String? _authToken;
  String? _refreshToken;
  Future<void>? _refreshFuture;

  // Unlike the Dio-based user/vendor clients (which set connectTimeout /
  // receiveTimeout), plain package:http requests never time out on their
  // own — a hanging connection would just hang forever instead of
  // surfacing a clear "connection timed out" message.
  static const Duration _requestTimeout = Duration(seconds: 20);

  void setAuthToken(String token) {
    _authToken = token;
  }

  void setRefreshToken(String refreshToken) {
    _refreshToken = refreshToken;
  }

  void clearAuthToken() {
    _authToken = null;
    _refreshToken = null;
    _refreshFuture = null;
  }

  /// Initialize tokens from secure storage
  /// This should be called when the app starts to load stored tokens
  Future<void> initializeTokensFromStorage() async {
    try {
      _authToken = await _storageService.getSecureString(StorageService.keyAuthToken);
      _refreshToken = await _storageService.getSecureString(StorageService.keyRefreshToken);
    } catch (e) {
      // If there's an error reading tokens, clear them
      clearAuthToken();
    }
  }

  /// Check if user has valid tokens (for background services)
  bool hasValidTokens() {
    return _authToken != null && _refreshToken != null;
  }

  /// Checks if the token is expired or will expire in the next 30 seconds
  bool _isTokenExpired(String token) {
    try {
      final payload = Jwt.parseJwt(token);
      final exp = payload['exp'];
      if (exp == null) return true;

      final expTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Add a 30 second buffer to ensure token doesn't expire during request
      final buffer = Duration(seconds: 30);
      return DateTime.now().add(buffer).isAfter(expTime);
    } catch (e) {
      // If we can't parse the token, assume it's expired
      return true;
    }
  }

  /// Refreshes the access token using the refresh token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw ApiException(message: 'No refresh token available');
    }

    try {
      final response = await _client
          .post(
            _buildUri(ApiConfig.refreshTokenEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'refreshToken': _refreshToken,
              'type': 'captain',
            }),
          )
          .timeout(_requestTimeout);

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        final newToken = data['token'] as String;
        final newRefreshToken = data['refreshToken'] as String;

        // Persist both tokens to secure storage before updating in-memory
        // state, and do it in parallel to minimize the window in which the
        // app could be killed after the server has already rotated the
        // refresh token but before this device has saved the new one
        // (which would otherwise desync the client from the server and
        // force a full re-login even though the session was never
        // explicitly ended).
        await Future.wait([
          _storageService.setSecureString(StorageService.keyAuthToken, newToken),
          _storageService.setSecureString(StorageService.keyRefreshToken, newRefreshToken),
        ]);

        _authToken = newToken;
        _refreshToken = newRefreshToken;
      } else {
        // Only logout if it's an authentication error (401, 403)
        if (response.statusCode == 401 || response.statusCode == 403) {
          await _logoutUser();
        }
        throw ApiException(
          message: body['error'] ?? body['message'] ?? 'Failed to refresh token',
          statusCode: response.statusCode,
          errorCode: body['errorCode']?.toString(),
        );
      }
    } catch (e) {
      // Only logout on explicit authentication failures (401, 403)
      // Do NOT logout on network errors, timeouts, or other exceptions
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        await _logoutUser();
        rethrow;
      }

      // For all other errors (network, timeout, etc.), just rethrow without logging out
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
      }
    }
  }

  /// Logs out the user by clearing tokens and storage
  Future<void> _logoutUser() async {
    // Clear tokens from memory
    clearAuthToken();
    
    // Clear tokens from secure storage
    await _storageService.deleteSecureString(StorageService.keyAuthToken);
    await _storageService.deleteSecureString(StorageService.keyRefreshToken);
  }

  /// Ensures token is valid before making a request
  /// Handles concurrent requests by reusing the same refresh future
  Future<void> _ensureValidToken() async {
    if (_authToken != null && _isTokenExpired(_authToken!)) {
      if (_refreshToken != null) {
        // If refresh is already in progress, wait for it
        if (_refreshFuture != null) {
          await _refreshFuture;
          return;
        }

        // Start the refresh process
        _refreshFuture = _refreshAccessToken();
        try {
          await _refreshFuture;
        } finally {
          _refreshFuture = null;
        }
      } else {
        // If no refresh token, logout the user
        await _logoutUser();
        throw ApiException(message: 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى');
      }
    }
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      await _ensureValidToken();
      final uri = _buildUri(endpoint, queryParams);
      final response = await _client
          .get(uri, headers: _getHeaders())
          .timeout(_requestTimeout);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      await _ensureValidToken();
      final uri = _buildUri(endpoint);
      final response = await _client
          .post(
            uri,
            headers: _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_requestTimeout);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      await _ensureValidToken();
      final uri = _buildUri(endpoint);
      final response = await _client
          .put(
            uri,
            headers: _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_requestTimeout);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      await _ensureValidToken();
      final uri = _buildUri(endpoint);
      final response = await _client
          .delete(uri, headers: _getHeaders())
          .timeout(_requestTimeout);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final url = '${ApiConfig.baseUrl}$endpoint';
    return Uri.parse(url).replace(queryParameters: queryParams);
  }

  Map<String, String> _getHeaders() {
    return _authToken != null
        ? ApiConfig.getAuthHeaders(_authToken!)
        : ApiConfig.headers;
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJson,
  ) {
    final statusCode = response.statusCode;
    final body = jsonDecode(response.body);

    if (statusCode >= 200 && statusCode < 300) {
      return ApiResponse.fromJson(body, fromJson);
    } else {
      throw ApiException(
        message: body['error'] ?? body['message'] ?? 'Unknown error occurred',
        statusCode: statusCode,
        errorCode: body['errorCode']?.toString(),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}