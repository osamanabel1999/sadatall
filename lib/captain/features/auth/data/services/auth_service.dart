import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/app_utils.dart';
import '../models/captain_model.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  Future<Map<String, dynamic>> signup({
    required String userName,
    required String email,
    required String phoneNumber,
    required String password,
    required String nationalId,
    File? photo,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authSignup}');
    final request = http.MultipartRequest('POST', uri);

    // Add headers
    request.headers.addAll(ApiConfig.headers);

    // Add text fields
    request.fields['userName'] = userName;
    request.fields['email'] = email;
    request.fields['phoneNumber'] = phoneNumber;
    request.fields['password'] = password;
    request.fields['nationalId'] = nationalId;

    // Add photo file if provided
    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photo.path,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true) {
        final data = body['data'];
        final result = {
          'captain': CaptainModel.fromJson(data['captain']),
          'token': data['token'],
          'refreshToken': data['refreshToken'],
        };

        // Store tokens securely
        await _storageService.setSecureString(StorageService.keyAuthToken, result['token']);
        await _storageService.setSecureString(StorageService.keyRefreshToken, result['refreshToken']);

        // Set tokens in ApiClient
        _apiClient.setAuthToken(result['token']);
        _apiClient.setRefreshToken(result['refreshToken']);

        return result;
      } else {
        // ApiException (not a bare Exception) — AppUtils.getLocalizedErrorMessage
        // only preserves the real message for this type; a plain Exception
        // fell through to its fully generic fallback string.
        throw ApiException(
          message: body['error'] ?? body['message'] ?? 'Registration failed',
          statusCode: response.statusCode,
          errorCode: body['errorCode']?.toString(),
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: AppUtils.getLocalizedErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authLogin,
      body: {
        'email': email,
        'password': password,
      },
      fromJson: (data) => {
        'captain': CaptainModel.fromJson(data['captain']),
        'token': data['token'],
        'refreshToken': data['refreshToken'],
      },
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      // Store tokens securely
      await _storageService.setSecureString(StorageService.keyAuthToken, data['token']);
      await _storageService.setSecureString(StorageService.keyRefreshToken, data['refreshToken']);

      // Set tokens in ApiClient
      _apiClient.setAuthToken(data['token']);
      _apiClient.setRefreshToken(data['refreshToken']);

      return data;
    } else {
      throw ApiException(message: response.error ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    // Clear tokens from secure storage
    await _storageService.deleteSecureString(StorageService.keyAuthToken);
    await _storageService.deleteSecureString(StorageService.keyRefreshToken);

    // Clear tokens from ApiClient
    _apiClient.clearAuthToken();
  }

  // Unlike logout (always "succeeds" locally regardless of the backend
  // call), a failed delete must NOT proceed with local cleanup: the
  // account still exists on the backend, and clearing local tokens here
  // would make the captain think it was deleted when it wasn't.
  Future<void> deleteAccount() async {
    await _apiClient.delete(ApiConfig.deleteAccount);
    await _storageService.deleteSecureString(StorageService.keyAuthToken);
    await _storageService.deleteSecureString(StorageService.keyRefreshToken);
    _apiClient.clearAuthToken();
  }
}
