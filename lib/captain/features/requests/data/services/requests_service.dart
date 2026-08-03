import "../../../../core/network/api_client.dart";
import "../../../../core/config/api_config.dart";
import "../../../../core/errors/api_exception.dart";
import "../models/captain_request_model.dart";

class RequestsService {
  final ApiClient _apiClient = ApiClient();

  Future<CaptainRequestModel> submitRequest(String description) async {
    final response = await _apiClient.post(
      ApiConfig.createRequest,
      body: {
        "description": description,
      },
      fromJson: (data) => CaptainRequestModel.fromJson(data),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? "Failed to submit request");
    }
  }

  Future<List<CaptainRequestModel>> getRequests({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, String>{
      "page": page.toString(),
      "limit": limit.toString(),
    };
    
    if (status != null) {
      queryParams["status"] = status;
    }

    final response = await _apiClient.get(
      ApiConfig.getRequests,
      queryParams: queryParams,
      fromJson: (data) => (data["requests"] as List)
          .map((request) => CaptainRequestModel.fromJson(request))
          .toList(),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw ApiException(message: response.error ?? "Failed to fetch requests");
    }
  }

  Future<void> deleteRequest(String requestId) async {
    final endpoint = "${ApiConfig.getRequests}/$requestId";
    
    final response = await _apiClient.delete(endpoint);

    if (!response.success) {
      throw ApiException(message: response.error ?? "Failed to delete request");
    }
  }
}
