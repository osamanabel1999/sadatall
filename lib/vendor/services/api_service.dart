import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../navigator_key.dart';

import 'storage_service.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  final StorageService _storageService = StorageService();

  /// Currently resolved API base URL — used by the chat feature to derive
  /// the Socket.io connection URL (same host, no /api suffix).
  String get baseUrl => _dio.options.baseUrl;

  Future<String?> get accessToken => _storageService.getAccessToken();

  void initialize() {
    // Initialize with default URL first
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
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
    //       requestHeader: false, // Hide headers to reduce clutter
    //       requestBody: true,
    //       responseHeader: false, // Hide headers to reduce clutter
    //       responseBody: true,
    //       error: true,
    //       log: (obj) {
    //         // Custom logging that focuses on requests and responses
    //         String logMessage = obj.toString();
    //         if (logMessage.contains('<--') || logMessage.contains('-->')) {
    //           // This is a request/response log line
    //         } else if (logMessage.contains('DioException') ||
    //             logMessage.contains('ERROR')) {
    //           // This is an error log
    //         }
    //         // Ignore other log lines that are too verbose
    //       },
    //     ),
    //   );
    // }

    _setupInterceptors();
  }

  // Method to update the base URL after fetching from Firestore
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (kDebugMode) {
            ('REQUEST[${options.method}] => URL: ${options.uri}');
            ('Headers: ${options.headers}');
            if (options.queryParameters.isNotEmpty) {
              ('Query: ${options.queryParameters}');
            }
            if (options.data is FormData) {
              ('Data: FormData with ${(options.data as FormData).fields.length} fields and ${(options.data as FormData).files.length} files');
              for (var field in (options.data as FormData).fields) {
                ('Field: ${field.key} = ${field.value}');
              }
              for (var file in (options.data as FormData).files) {
                ('File: ${file.key} = ${file.value.filename}');
              }
            } else {
              ('Data: ${options.data}');
            }
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            ('RESPONSE[${response.statusCode}] => URL: ${response.requestOptions.uri}');
            ('Data: ${response.data}');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            ('ERROR[${error.response?.statusCode}] => URL: ${error.requestOptions.uri}');
            ('Message: ${error.message}');
            ('Data: ${error.response?.data}');
          }

          // Handle 401 Unauthorized errors
          if (error.response?.statusCode == 401) {
            // Check if the error response contains the word "locked"
            bool isVendorLocked = false;
            String? errorMessage;

            if (error.response?.data is Map<String, dynamic>) {
              final responseData = error.response!.data as Map<String, dynamic>;
              errorMessage =
                  responseData['error']?.toString() ??
                  responseData['message']?.toString();

              // Check for vendor locked indicators in the error message
              if (errorMessage != null) {
                final lowerError = errorMessage.toLowerCase();
                if (lowerError.contains('locked') ||
                    lowerError.contains('مغلق')) {
                  isVendorLocked = true;
                }
              }
            }

            // If vendor is locked, show message and navigate to login
            if (isVendorLocked) {
              await _storageService.clearAllTokens();
              if (kDebugMode) {
                ('Vendor is locked, showing management unlock message...');
              }

              // Show message that management should unlock the vendor
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (navigatorKey.currentContext != null) {
                  showDialog(
                    context: navigatorKey.currentContext!,
                    builder: (context) => AlertDialog(
                      title: const Text('الحساب مغلق'),
                      content: const Text(
                        'الحساب مغلق الآن، يرجى الاتصال بالادارة لفتح الحساب',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Navigate to login page after showing the message
                            navigatorKey.currentState?.pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          },
                          child: const Text('موافق'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // If context is not available, just navigate to login
                  navigatorKey.currentState?.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              });

              handler.next(error);
              return;
            }

            // For non-locked 401 errors, continue with regular refresh token flow
            final authService = AuthService();
            final isLoggedIn = await authService.isLoggedIn();

            // Check if this is a refresh token request itself
            bool isRefreshTokenRequest =
                error.requestOptions.path == AppConstants.refreshTokenEndpoint;

            if (isRefreshTokenRequest) {
              // If the refresh token request itself returned 401,
              // clear all tokens and navigate to login page
              await _storageService.clearAllTokens();
              if (kDebugMode) {
                ('Refresh token endpoint returned 401, redirecting to login...');
              }

              // Navigate to login page using the global navigator key
              // Using WidgetsBinding to ensure the navigator is ready
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              });

              handler.next(error);
              return;
            }

            // Only attempt refresh for non-refresh-token requests if user is logged in
            if (isLoggedIn) {
              final refreshed = await _refreshToken();
              if (refreshed) {
                // Get the new token and retry the original request
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

                  // Check again if the response indicates vendor is locked after refresh
                  if (response.data is Map<String, dynamic>) {
                    final responseData = response.data as Map<String, dynamic>;
                    String? responseMessage =
                        responseData['error']?.toString() ??
                        responseData['message']?.toString();

                    if (responseMessage != null) {
                      final lowerResponse = responseMessage.toLowerCase();
                      if (lowerResponse.contains('locked') ||
                          lowerResponse.contains('مغلق')) {
                        await _storageService.clearAllTokens();
                        if (kDebugMode) {
                          ('Response after refresh indicates vendor locked');
                        }

                        // Show message that management should unlock the vendor
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (navigatorKey.currentContext != null) {
                            showDialog(
                              context: navigatorKey.currentContext!,
                              builder: (context) => AlertDialog(
                                title: const Text('الحساب مغلق'),
                                content: const Text(
                                  'الحساب مغلق الآن، يرجى الاتصال بالادارة لفتح الحساب',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      // Navigate to login page after showing the message
                                      navigatorKey.currentState
                                          ?.pushNamedAndRemoveUntil(
                                            '/login',
                                            (route) => false,
                                          );
                                    },
                                    child: const Text('موافق'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // If context is not available, just navigate to login
                            navigatorKey.currentState?.pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        });

                        handler.next(error);
                        return;
                      }
                    }
                  }

                  handler.resolve(response);
                  return;
                } catch (retryError) {
                  // Check if the retry error indicates the vendor is locked
                  String? retryErrorMessage;
                  if (retryError is DioException &&
                      retryError.response?.data is Map<String, dynamic>) {
                    final responseData =
                        retryError.response!.data as Map<String, dynamic>;
                    retryErrorMessage =
                        responseData['error']?.toString() ??
                        responseData['message']?.toString();
                  }

                  // If retry also indicates vendor is locked
                  if (retryErrorMessage != null) {
                    final lowerError = retryErrorMessage.toLowerCase();
                    if (lowerError.contains('locked') ||
                        lowerError.contains('مغلق')) {
                      await _storageService.clearAllTokens();
                      if (kDebugMode) {
                        ('Retry failed with vendor locked error');
                      }

                      // Show message that management should unlock the vendor
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (navigatorKey.currentContext != null) {
                          showDialog(
                            context: navigatorKey.currentContext!,
                            builder: (context) => AlertDialog(
                              title: const Text('الحساب مغلق'),
                              content: const Text(
                                'الحساب مغلق الآن، يرجى الاتصال بالادارة لفتح الحساب',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    // Navigate to login page after showing the message
                                    navigatorKey.currentState
                                        ?.pushNamedAndRemoveUntil(
                                          '/login',
                                          (route) => false,
                                        );
                                  },
                                  child: const Text('موافق'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // If context is not available, just navigate to login
                          navigatorKey.currentState?.pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      });

                      handler.next(error);
                      return;
                    }
                  }

                  // If retry fails but not due to vendor being locked, surface
                  // the retry's own error (its real backend message) rather
                  // than falling through to the original pre-refresh error.
                  if (kDebugMode) {
                    ('Retry failed: $retryError');
                  }
                  if (retryError is DioException) {
                    handler.next(retryError);
                    return;
                  }
                }
              } else {
                // If refresh failed, clear tokens and navigate to login page
                await _storageService.clearAllTokens();
                if (kDebugMode) {
                  ('Token refresh failed, redirecting to login...');
                }

                // Navigate to login page using the global navigator key
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  navigatorKey.currentState?.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                });
              }
            } else {
              // User not logged in, clear any existing tokens
              await _storageService.clearAllTokens();
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

      final response = await _dio.post(
        AppConstants.refreshTokenEndpoint,
        data: {'refreshToken': refreshToken, 'type': 'vendor'},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newAccessToken = response.data['data']['token'];
        final newRefreshToken = response.data['data']['refreshToken'];

        await _storageService.saveAccessToken(newAccessToken);
        await _storageService.saveRefreshToken(newRefreshToken);

        return true;
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // Refresh token is invalid/expired - clear all tokens and force logout
        if (kDebugMode) {
          ('Refresh token invalid/expired, clearing all tokens');
        }
        await _storageService.clearAllTokens();
        return false;
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        ('Token refresh failed: $e');
      }

      // Check if it's a network error or token expired error
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        // Refresh token is invalid/expired - clear all tokens and force logout
        if (kDebugMode) {
          ('Refresh token invalid/expired (DioException), clearing all tokens');
        }
        await _storageService.clearAllTokens();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        ('Token refresh failed: $e');
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
      // Check if the response indicates failure with an error
      if (responseData['success'] == false) {
        return ApiResponse(
          success: false,
          data: responseData['data'],
          message: responseData['message'],
          error: responseData['error'],
          errorCode: responseData['errorCode']?.toString(),
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: responseData['success'] ?? true,
          data: responseData['data'],
          message: responseData['message'],
          statusCode: response.statusCode,
        );
      }
    }

    return ApiResponse(
      success: response.statusCode! >= 200 && response.statusCode! < 300,
      data: responseData,
      statusCode: response.statusCode,
    );
  }

  factory ApiResponse.fromError(DioException error) {
    String errorMessage = 'خطأ غير متوقع';
    String? errorCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'انتهات مهلة الاتصال';
    } else if (error.type == DioExceptionType.connectionError) {
      errorMessage = 'خطأ في الاتصال بالشبكة';
    } else if (error.response?.data is Map<String, dynamic>) {
      final responseData = error.response!.data as Map<String, dynamic>;
      // Check for both 'message' and 'error' fields in the response
      errorMessage =
          responseData['error'] ?? responseData['message'] ?? errorMessage;
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
    return ApiResponse(success: false, error: 'خطأ غير متوقع');
  }
}
