import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "../../../../core/network/api_client.dart";
import "../../../../core/config/api_config.dart";
import "../../../../core/errors/api_exception.dart";
import "../../../../core/services/storage_service.dart";
import "../../../auth/data/models/captain_model.dart";
import "../models/captain_stats.dart";

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  Future<CaptainModel> getProfile() async {
    final response = await _apiClient.get(
      ApiConfig.captainsProfile,
      fromJson: (data) => CaptainModel.fromJson(data),
    );
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? "Failed to fetch profile");
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data, {File? photo}) async {
    if (photo != null) {
      // Multipart request when photo is included
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.captainsProfile}');
      final request = http.MultipartRequest('PUT', uri);

      final token = await StorageService().getSecureString(StorageService.keyAuthToken);
      if (token != null) {
        request.headers.addAll(ApiConfig.getAuthHeaders(token));
      }
      // Remove Content-Type for multipart (http package sets it automatically)
      request.headers.remove('Content-Type');

      // Add text fields
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add photo file
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300 || body['success'] != true) {
        throw ApiException(
          message: body['error'] ?? "Failed to update profile",
          statusCode: response.statusCode,
        );
      }
    } else {
      // Regular JSON request
      final response = await _apiClient.put(
        ApiConfig.captainsProfile,
        body: data,
      );
      if (!response.success) {
        throw ApiException(message: response.error ?? "Failed to update profile");
      }
    }
  }

  Future<CaptainStats> getStats() async {
    final response = await _apiClient.get(
      ApiConfig.captainsStats,
      fromJson: (data) => CaptainStats.fromJson(data),
    );
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? "Failed to fetch stats");
    }
  }
}
