import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/vendor.dart';
import '../models/auth_models.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'package:dio/dio.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<AuthResult> login({
    required String contactNumber,
    required String password,
  }) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        AppConstants.loginEndpoint,
        data: {
          'contactNumber': contactNumber,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.success && response.data != null) {
        final vendorData = response.data!['vendor'];
        final token = response.data!['token'];
        final refreshToken = response
            .data!['refreshToken']; // Extract refresh token if available

        final vendor = Vendor.fromJson(vendorData);

        await _storageService.saveAccessToken(token);
        if (refreshToken != null) {
          await _storageService.saveRefreshToken(refreshToken);
        }
        await _storageService.saveVendorData(vendor);

        // Update FCM token to backend after successful login
        try {
          final notificationService = NotificationService();
          await notificationService.sendFCMTokenIfNeeded();
        } catch (e) {
          if (kDebugMode) {
            ('Error updating FCM token after login: $e');
          }
        }

        return AuthResult(
          success: true,
          vendor: vendor,
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
        error: 'خطأ غير متوقع أثناء تسجيل الدخول: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> signup({
    required String vendorName,
    required String contactNumber,
    required String password,
    required String address,
    required String description,
    required double latitude,
    required double longitude,
    required int neighborhoodId,
    required List<int> categories,
    required File image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'vendorName': vendorName,
        'contactNumber': contactNumber,
        'password': password,
        'address': address,
        'description': description,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'neighborhoodId': neighborhoodId.toString(),
        'categories': categories.join(','),
        'image': await MultipartFile.fromFile(image.path),
      });

      final response = await _apiService.post<Map<String, dynamic>>(
        AppConstants.signupEndpoint,
        data: formData,
      );

      if (response.success && response.data != null) {
        // Extract data from nested structure according to schema
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        final vendorData = dataContainer?['vendor'];
        final token = dataContainer?['token'];
        final refreshToken = dataContainer?[
            'refreshToken']; // Extract refresh token if available

        final vendor = Vendor.fromJson(vendorData);

        await _storageService.saveAccessToken(token);
        if (refreshToken != null) {
          await _storageService.saveRefreshToken(refreshToken);
        }
        await _storageService.saveVendorData(vendor);

        // Update FCM token to backend after successful signup
        try {
          final notificationService = NotificationService();
          await notificationService.sendFCMTokenIfNeeded();
        } catch (e) {
          if (kDebugMode) {
            ('Error updating FCM token after signup: $e');
          }
        }

        return AuthResult(
          success: true,
          vendor: vendor,
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
        error: 'خطأ غير متوقع أثناء إنشاء الحساب: ${e.toString()}',
      );
    }
  }

  Future<bool> logout() async {
    try {
      // await _apiService.post(AppConstants.logoutEndpoint);
      await _storageService.clearAllTokens();
      return true;
    } catch (e) {
      await _storageService.clearAllTokens();
      // Log the error for debugging but don't expose it to user
      if (kDebugMode) {
        ('خطأ غير متوقع أثناء تسجيل الخروج: ${e.toString()}');
      }
      return true;
    }
  }

  // Unlike logout (always "succeeds" locally regardless of the backend
  // call), a failed delete must NOT be reported as success: the vendor
  // account still exists on the backend, and clearing local tokens here
  // would make the user think it was deleted when it wasn't.
  Future<AuthResult> deleteAccount() async {
    try {
      final response = await _apiService.delete(AppConstants.deleteAccountEndpoint);
      if (response.success) {
        await _storageService.clearAllTokens();
        return AuthResult(success: true, message: response.message ?? 'تم حذف الحساب بنجاح');
      }
      return AuthResult(success: false, error: response.error ?? 'تعذر حذف الحساب');
    } catch (e) {
      return AuthResult(success: false, error: 'حدث خطأ أثناء حذف الحساب: ${e.toString()}');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storageService.getAccessToken();
    return token != null;
  }

  Future<Vendor?> getCurrentVendor() async {
    final vendor = await _storageService.getVendorData();
    // If the vendor is locked based on the isLocked field, we might want to handle it specially
    // For now, just return the vendor as is
    return vendor;
  }

  // Re-caches a freshly-fetched vendor (e.g. after getCurrentVendor()
  // returned null because the cached copy was missing/corrupt) so the
  // next app launch can read it locally again instead of hitting the API.
  Future<void> cacheVendor(Vendor vendor) async {
    await _storageService.saveVendorData(vendor);
  }

  Future<String?> getAccessToken() async {
    return await _storageService.getAccessToken();
  }
}
