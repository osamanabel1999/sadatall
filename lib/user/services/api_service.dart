import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../core/config/api_config.dart';
import 'storage_service.dart';
import 'package:sadat_delivery_merged/main.dart' show navigatorKey;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  final StorageService _storageService = StorageService();
  String? _currentBaseUrl; // Store the current base URL

  /// Currently resolved API base URL — used by the chat feature to derive
  /// the Socket.io connection URL (same host, no /api suffix).
  String get baseUrl => _dio.options.baseUrl;

  Future<String?> get accessToken => _storageService.getAccessToken();

  void initialize() {
    _initializeInternal();
  }

  /// Async initialization that ensures the base URL is loaded from storage
  Future<void> initializeAsync() async {
    await _initializeInternalAsync();
  }

  /// Asynchronous internal initialization that reloads base URL from storage
  Future<void> _initializeInternalAsync() async {
    // Get the base URL directly from storage for initial setup
    final baseUrl = await _getCurrentBaseUrlFromStorage();
    _currentBaseUrl = baseUrl; // Store it for reference
    debugPrint('🌐 [ApiService] baseUrl = $baseUrl');

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectionTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Tenant-ID': AppConstants.tenantId,
        },
      ),
    );

    // if (kDebugMode) {
    //   _dio.interceptors.add(
    //     LogInterceptor(
    //       request: true,
    //       requestHeader: true,
    //       requestBody: true,
    //       responseHeader: true,
    //       responseBody: true,
    //       error: true,
    //       log: (obj) => debugPrint(obj.toString(), wrapWidth: 2048),
    //     ),
    //   );
    // }

    _setupInterceptors();
  }

  void _initializeInternal() {
    // For sync initialization, we'll try to get a current URL with fallback
    // The most recent one is stored in _currentBaseUrl, otherwise get from config manager
    final baseUrl = _currentBaseUrl ?? _getBaseUrl();

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectionTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Tenant-ID': AppConstants.tenantId,
        },
      ),
    );

    // if (kDebugMode) {
    //   _dio.interceptors.add(
    //     LogInterceptor(
    //       request: true,
    //       requestHeader: true,
    //       requestBody: true,
    //       responseHeader: true,
    //       responseBody: true,
    //       error: true,
    //       log: (obj) => debug(obj.toString(), wrapWidth: 2048),
    //     ),
    //   );
    // }

    _setupInterceptors();
  }

  /// Gets the current base URL, trying to use the dynamic one if available
  String _getBaseUrl() {
    try {
      return ApiConfigManager().getBaseUrl();
    } catch (e) {
      // If ApiConfigManager is not initialized yet, fall back to default
      return AppConstants.baseUrl;
    }
  }

  /// Reinitializes the API service with the updated base URL
  void reinitialize() {
    _initializeInternal();
  }

  /// Gets the current base URL directly from storage
  Future<String> _getCurrentBaseUrlFromStorage() async {
    try {
      // Use the ApiConfigManager's async method that gets directly from storage
      return await ApiConfigManager().getBaseUrlAsync();
    } catch (e) {
      // If everything fails, fall back to default
      return AppConstants.baseUrl;
    }
  }

  /// Reloads the base URL from local storage and reinitializes if changed
  Future<void> reloadBaseUrlFromStorage() async {
    await ApiConfigManager().reloadBaseUrlFromStorage();
    // Reinitialize to use the potentially updated base URL
    _initializeInternal();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Get the current base URL from storage
          final currentBaseUrl = await _getCurrentBaseUrlFromStorage();

          // Update our stored reference
          _currentBaseUrl = currentBaseUrl;

          // Only update the options if the base URL has actually changed
          if (currentBaseUrl != _dio.options.baseUrl ||
              currentBaseUrl != options.baseUrl) {
            // Update the base URL for this request if it has changed
            options.baseUrl = currentBaseUrl;
          }

          final token = await _storageService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          //  the request with token information
          // if (kDebugMode) {
          //   ('=== REQUEST ===');
          //   ('Method: ${options.method}');
          //   ('URL: ${options.uri}');
          //   ('Headers: ${options.headers}');
          //   if (options.queryParameters.isNotEmpty) {
          //     ('Query: ${options.queryParameters}');
          //   }
          //   if (options.data is FormData) {
          //     (
          //         'Data: FormData with ${(options.data as FormData).fields.length} fields and ${(options.data as FormData).files.length} files');
          //     for (var field in (options.data as FormData).fields) {
          //       ('Field: ${field.key} = ${field.value}');
          //     }
          //     for (var file in (options.data as FormData).files) {
          //       ('File: ${file.key} = ${file.value.filename}');
          //     }
          //   } else {
          //     ('Data: ${options.data}');
          //   }
          //   ('================');
          // }

          handler.next(options);
        },
        onResponse: (response, handler) {
          //  the response
          if (kDebugMode) {
            // ('=== RESPONSE ===');
            // ('Method: ${response.requestOptions.method}');
            // ('URL: ${response.requestOptions.path}');
            // ('Status Code: ${response.statusCode}');
            // ('Headers: ${response.headers}');
            // ('Data: ${response.data}');
            // ('================');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          //  the error
          if (kDebugMode) {
            // ('=== ERROR ===');
            // ('Method: ${error.requestOptions.method}');
            // ('URL: ${error.requestOptions.path}');
            // ('Status Code: ${error.response?.statusCode}');
            // ('Message: ${error.message}');
            // ('Data: ${error.response?.data}');
            // ('================');
          }

          if (error.response?.statusCode == 401) {
            // Check if this is a refresh token request itself to avoid infinite loop
            if (error.requestOptions.path.contains(
              AppConstants.refreshTokenEndpoint,
            )) {
              // If the refresh token endpoint itself returns 401, clear tokens and navigate to login immediately
              await _storageService.clearAllTokens();

              // if (kDebugMode) {
              //   (
              //       '=== REFRESH TOKEN ENDPOINT FAILED - REDIRECTING TO LOGIN ===');
              //   ('Method: ${error.requestOptions.method}');
              //   ('URL: ${error.requestOptions.path}');
              //   ('================');
              // }

              // Navigate to login screen
              if (navigatorKey.currentContext != null) {
                Navigator.of(
                  navigatorKey.currentContext!,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
              return;
            }

            final refreshed = await _refreshToken();
            if (refreshed) {
              final newToken = await _storageService.getAccessToken();
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';

              try {
                final response = await _dio.request(
                  error.requestOptions.path,
                  options: Options(
                    method: error.requestOptions.method,
                    headers: error.requestOptions.headers,
                  ),
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                );

                // Check if the retry response is still unauthorized
                if (response.statusCode == 401) {
                  // If still unauthorized after refresh, clear tokens and navigate to login
                  await _storageService.clearAllTokens();

                  // if (kDebugMode) {
                  //   (
                  //       '=== RETRY STILL UNAUTHORIZED - REDIRECTING TO LOGIN ===');
                  //   ('Method: ${response.requestOptions.method}');
                  //   ('URL: ${response.requestOptions.path}');
                  //   ('Status Code: ${response.statusCode}');
                  //   ('================');
                  // }

                  // Navigate to login screen
                  if (navigatorKey.currentContext != null) {
                    Navigator.of(
                      navigatorKey.currentContext!,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                  return;
                }

                // //  the retry response
                // if (kDebugMode) {
                //   ('=== RETRY RESPONSE (after token refresh) ===');
                //   ('Method: ${response.requestOptions.method}');
                //   ('URL: ${response.requestOptions.path}');
                //   ('Status Code: ${response.statusCode}');
                //   ('Headers: ${response.headers}');
                //   ('Data: ${response.data}');
                //   ('================');
                // }

                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                // Only treat this as an auth failure (and force logout) if the
                // retried request is itself unauthorized. Any other failure
                // (validation, server error, etc.) is a real error from the
                // retried request and must be surfaced to the caller as-is,
                // not swallowed behind a forced logout.
                if (retryError.response?.statusCode == 401) {
                  if (kDebugMode) {
                    ('=== RETRY STILL UNAUTHORIZED - REDIRECTING TO LOGIN ===');
                    ('Method: ${error.requestOptions.method}');
                    ('URL: ${error.requestOptions.path}');
                    ('================');
                  }

                  await _storageService.clearAllTokens();

                  if (navigatorKey.currentContext != null) {
                    Navigator.of(
                      navigatorKey.currentContext!,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                  return;
                }

                handler.next(retryError);
                return;
              }
            } else {
              // If refresh token is invalid, clear all tokens and navigate to login
              await _storageService.clearAllTokens();

              if (kDebugMode) {
                ('=== REFRESH TOKEN INVALID - REDIRECTING TO LOGIN ===');
                ('Method: ${error.requestOptions.method}');
                ('URL: ${error.requestOptions.path}');
                ('================');
              }

              // Navigate to login screen
              if (navigatorKey.currentContext != null) {
                Navigator.of(
                  navigatorKey.currentContext!,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) return false;

      // if (kDebugMode) {
      //   ('=== REFRESH TOKEN REQUEST ===');
      //   ('Method: POST');
      //   ('URL: ${AppConstants.refreshTokenEndpoint}');
      //   ('Data: {type: user, refreshToken: $refreshToken}');
      //   ('================');
      // }

      final response = await _dio.post(
        AppConstants.refreshTokenEndpoint,
        data: {'type': 'user', 'refreshToken': refreshToken},
      );

      // if (kDebugMode) {
      //   ('=== REFRESH TOKEN RESPONSE ===');
      //   ('Method: POST');
      //   ('URL: ${AppConstants.refreshTokenEndpoint}');
      //   ('Status Code: ${response.statusCode}');
      //   ('Data: ${response.data}');
      //   ('================');
      // }

      if (response.statusCode == 200) {
        final newAccessToken =
            response.data['data']?['accessToken'] ??
            response.data['data']?['token'];
        final newRefreshToken = response.data['data']?['refreshToken'];

        if (newAccessToken != null) {
          await _storageService.saveAccessToken(newAccessToken.toString());
        }
        if (newRefreshToken != null) {
          await _storageService.saveRefreshToken(newRefreshToken.toString());
        }

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        ('=== REFRESH TOKEN ERROR ===');
        ('Method: POST');
        ('URL: ${AppConstants.refreshTokenEndpoint}');
        ('Error: $e');
        ('================');
        debugPrint('Token refresh failed: $e');
      }
    }
    return false;
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint, {
    required File file,
    required String fieldName,
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = FormData();

      // Add file
      formData.files.add(
        MapEntry(fieldName, await MultipartFile.fromFile(file.path)),
      );

      // Add other data
      if (data != null) {
        data.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }

      final response = await _dio.post(
        endpoint,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<dynamic>> getAnnouncements({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/announcements/public',
        queryParameters: {'page': page.toString(), 'limit': '20', 'audience': 'user'},
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<dynamic>> getPromoAds() async {
    try {
      final response = await _dio.get('/promo-ads/public');
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }

  Future<ApiResponse<dynamic>> updateFCMToken(String token) async {
    try {
      final response = await _dio.put(
        AppConstants.fcmTokenEndpoint,
        data: {'fcmToken': token},
      );
      return ApiResponse.fromResponse(response);
    } on DioException catch (e) {
      return ApiResponse.fromError(e);
    } catch (e) {
      return ApiResponse.fromException(e);
    }
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final String? errorCode;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.errorCode,
    this.statusCode,
  });

  factory ApiResponse.fromResponse(Response response) {
    final responseData = response.data;

    if (responseData is Map<String, dynamic>) {
      return ApiResponse(
        success: responseData['success'] ?? true,
        data: responseData['data'],
        message: responseData['message'],
        errorCode: responseData['errorCode']?.toString(),
        statusCode: response.statusCode,
      );
    }

    return ApiResponse(
      success: response.statusCode! >= 200 && response.statusCode! < 300,
      data: responseData,
      statusCode: response.statusCode,
    );
  }

  factory ApiResponse.fromError(DioException error) {
    String errorMessage =
        'حدث خطأ غير متوقع ' + '(DioException): ${error.message}';
    String? errorCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'انتهت مهلة الاتصال';
    } else if (error.type == DioExceptionType.connectionError) {
      errorMessage = 'خطأ في الاتصال بالشبكة';
    } else if (error.response?.data is Map<String, dynamic>) {
      final responseData = error.response!.data as Map<String, dynamic>;
      // Try 'error' first (validation failures), then 'message', then fallback
      final details = responseData['details'];
      if (details is List && details.isNotEmpty) {
        errorMessage = details
            .map((d) => d['msg']?.toString() ?? '')
            .where((m) => m.isNotEmpty)
            .join('\n');
      } else {
        errorMessage =
            responseData['error']?.toString() ??
            responseData['message']?.toString() ??
            errorMessage;
      }
      errorCode = responseData['errorCode']?.toString();
    }

    return ApiResponse(
      success: false,
      error: errorMessage,
      errorCode: errorCode,
      statusCode: error.response?.statusCode,
    );
  }

  factory ApiResponse.fromException(dynamic exception) {
    return ApiResponse(
      success: false,
      error: 'حدث خطأ غير متوقع: ${exception.toString()}',
    );
  }
}
