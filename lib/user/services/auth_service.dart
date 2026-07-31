import 'dart:async';
import '../models/user.dart';
import '../models/auth_models.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../shared/chat/data/chat_auth_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        AppConstants.userLoginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        final userData = dataContainer?['user'];
        final token = dataContainer?['token'] ?? dataContainer?['access_token'];
        final refreshToken = dataContainer?['refreshToken'];

        final user = User.fromJson(userData);

        await _storageService.saveAccessToken(token);
        if (refreshToken != null) {
          await _storageService.saveRefreshToken(refreshToken);
        }
        await _storageService.saveUserData(user);

        // Send FCM token to backend after successful login
        try {
          final notificationService = NotificationService();
          final fcmToken = await notificationService.getToken();
          if (fcmToken != null) {
            await notificationService.sendTokenToBackend(fcmToken);
          }
        } catch (e) {
          if (kDebugMode) {
            ('Error sending FCM token after login: $e');
          }
        }

        unawaited(_signInToChat());

        return AuthResult(
          success: true,
          user: user,
          message: response.message ?? 'تم تسجيل الدخول بنجاح',
        );
      } else {
        return AuthResult(
          success: false,
          error: response.error ?? 'فشل تسجيل الدخول',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> signup({
    required String userName,
    required String email,
    required String phoneNumber,
    required String password,
    required String address,
    required String neighborhoodId,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        AppConstants.userSignupEndpoint,
        data: {
          'userName': userName,
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
          'address': address,
          'neighborhoodId': int.parse(neighborhoodId),
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        final userData = dataContainer?['user'];
        final token = dataContainer?['token'] ?? dataContainer?['access_token'];
        final refreshToken = dataContainer?['refreshToken'];

        final user = User.fromJson(userData);

        await _storageService.saveAccessToken(token);
        if (refreshToken != null) {
          await _storageService.saveRefreshToken(refreshToken);
        }
        await _storageService.saveUserData(user);

        // Send FCM token to backend after successful signup
        try {
          final notificationService = NotificationService();
          final fcmToken = await notificationService.getToken();
          if (fcmToken != null) {
            await notificationService.sendTokenToBackend(fcmToken);
          }
        } catch (e) {
          if (kDebugMode) {
            ('Error sending FCM token after signup: $e');
          }
        }

        unawaited(_signInToChat());

        return AuthResult(
          success: true,
          user: user,
          message: response.message ?? 'تم إنشاء الحساب بنجاح',
        );
      } else {
        return AuthResult(
          success: false,
          error: response.error ?? 'فشل إنشاء الحساب',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'حدث خطأ أثناء إنشاء الحساب: ${e.toString()}',
      );
    }
  }

  Future<bool> logout() async {
    try {
      await _apiService.post(AppConstants.logoutEndpoint);
      await _storageService.clearAllTokens();
      await ChatAuthService.signOut();
      return true;
    } catch (e) {
      await _storageService.clearAllTokens();
      await ChatAuthService.signOut();
      return true;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _apiService.delete(AppConstants.deleteAccountEndpoint);
      await _storageService.clearAllTokens();
      return true;
    } catch (e) {
      await _storageService.clearAllTokens();
      return true;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null || token.isEmpty) return false;

      // Check if we have user data as well
      final user = await _storageService.getUserData();
      return user != null;
    } catch (e) {
      // On error, assume not logged in
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    return await _storageService.getAccessToken();
  }

  Future<User?> getCurrentUser() async {
    return await _storageService.getUserData();
  }

  /// Signs into Firebase Auth via a backend-minted custom token so
  /// Firestore security rules can trust request.auth.uid for the chat
  /// feature. Best-effort — chat just won't work if this fails, everything
  /// else keeps working normally.
  Future<void> _signInToChat() async {
    try {
      await ChatAuthService.signIn(() async {
        final response = await _apiService.post<Map<String, dynamic>>('/auth/firebase-token');
        if (response.success && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>?;
          return data?['customToken'] as String?;
        }
        return null;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Chat Firebase sign-in failed: $e');
    }
  }
}
