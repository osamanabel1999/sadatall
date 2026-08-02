import '../constants/app_constants.dart';
import '../models/vendor.dart';
import '../models/menu_item.dart';
import '../models/product_item.dart';
import '../models/category.dart' as models;
import 'api_service.dart';
import 'package:flutter/foundation.dart';

class UserVendorService {
  static final UserVendorService _instance = UserVendorService._internal();
  factory UserVendorService() => _instance;
  UserVendorService._internal();

  final ApiService _apiService = ApiService();

  Future<ApiResponse<List<Vendor>>> getVendors({
    int page = 1,
    int limit = 10,
    String? isOpen,
    String? categoryId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (isOpen != null) {
        queryParameters['isOpen'] = isOpen;
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        queryParameters['category'] = categoryId;
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        AppConstants.vendorsEndpoint,
        queryParameters: queryParameters,
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('vendors')) {
          final vendorsData = dataContainer['vendors'] as List;
          final vendors =
              vendorsData.map((vendor) => Vendor.fromJson(vendor)).toList();

          return ApiResponse<List<Vendor>>(
            success: true,
            data: vendors,
            message: response.message ?? 'تم استرداد قائمة المتاجر بنجاح',
          );
        } else {
          return ApiResponse<List<Vendor>>(
            success: false,
            error: 'بيانات المتاجر غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<List<Vendor>>(
          success: false,
          error: response.error ?? 'فشل في استرداد قائمة المتاجر',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.getVendors error: $e');
      }
      return ApiResponse<List<Vendor>>(
        success: false,
        error: 'حدث خطأ أثناء استرداد قائمة المتاجر: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<Vendor>>> searchVendors({
    required String query,
    int page = 1,
    int limit = 10,
    String? categoryId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'query': query,
        'page': page,
        'limit': limit,
      };

      if (categoryId != null && categoryId.isNotEmpty) {
        queryParameters['category'] = categoryId;
      }

      // Use the vendors endpoint with search query parameter
      final response = await _apiService.get<Map<String, dynamic>>(
        '${AppConstants.vendorsEndpoint}/search',
        queryParameters: queryParameters,
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('vendors')) {
          final vendorsData = dataContainer['vendors'] as List;
          final vendors =
              vendorsData.map((vendor) => Vendor.fromJson(vendor)).toList();

          return ApiResponse<List<Vendor>>(
            success: true,
            data: vendors,
            message: response.message ?? 'تم البحث في المتاجر بنجاح',
          );
        } else {
          return ApiResponse<List<Vendor>>(
            success: false,
            error: 'بيانات المتاجر غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<List<Vendor>>(
          success: false,
          error: response.error ?? 'فشل في البحث في المتاجر',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.searchVendors error: $e');
      }
      return ApiResponse<List<Vendor>>(
        success: false,
        error: 'حدث خطأ أثناء البحث في المتاجر: ${e.toString()}',
      );
    }
  }

  // Fetches a single vendor by id — used e.g. when a home-screen promo ad
  // links directly to a vendor's page rather than an external URL.
  Future<ApiResponse<Vendor>> getVendorById(String vendorId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '${AppConstants.vendorsEndpoint}/$vendorId',
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null) {
          return ApiResponse<Vendor>(
            success: true,
            data: Vendor.fromJson(dataContainer),
            message: response.message ?? 'تم استرداد بيانات المتجر بنجاح',
          );
        }
      }
      return ApiResponse<Vendor>(
        success: false,
        error: response.error ?? 'فشل في استرداد بيانات المتجر',
      );
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.getVendorById error: $e');
      }
      return ApiResponse<Vendor>(
        success: false,
        error: 'حدث خطأ أثناء استرداد بيانات المتجر: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<MenuItem>>> getVendorMenus(
    String vendorId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final response = await _apiService.get<Map<String, dynamic>>(
        '${AppConstants.vendorMenusEndpoint}/$vendorId',
        queryParameters: queryParameters,
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('menus')) {
          final menusData = dataContainer['menus'] as List;
          final menus =
              menusData.map((menu) => MenuItem.fromJson(menu)).toList();

          return ApiResponse<List<MenuItem>>(
            success: true,
            data: menus,
            message: response.message ?? 'تم استرداد قائمة الطعام بنجاح',
          );
        } else {
          return ApiResponse<List<MenuItem>>(
            success: false,
            error: 'بيانات قائمة الطعام غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<List<MenuItem>>(
          success: false,
          error: response.error ?? 'فشل في استرداد قائمة الطعام',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.getVendorMenus error: $e');
      }
      return ApiResponse<List<MenuItem>>(
        success: false,
        error: 'حدث خطأ أثناء استرداد قائمة الطعام: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<ProductItem>>> getVendorItems(
    String vendorId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final response = await _apiService.get<Map<String, dynamic>>(
        '${AppConstants.vendorItemsEndpoint}/$vendorId',
        queryParameters: queryParameters,
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('items')) {
          final itemsData = dataContainer['items'] as List;
          final items =
              itemsData.map((item) => ProductItem.fromJson(item)).toList();

          return ApiResponse<List<ProductItem>>(
            success: true,
            data: items,
            message: response.message ?? 'تم استرداد المنتجات بنجاح',
          );
        } else {
          return ApiResponse<List<ProductItem>>(
            success: false,
            error: 'بيانات المنتجات غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<List<ProductItem>>(
          success: false,
          error: response.error ?? 'فشل في استرداد المنتجات',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.getVendorItems error: $e');
      }
      return ApiResponse<List<ProductItem>>(
        success: false,
        error: 'حدث خطأ أثناء استرداد المنتجات: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<models.Category>>> getCategories() async {
    try {
      (
          '🔵 [Categories API] Calling endpoint: ${AppConstants.categoriesEndpoint}');
      final response = await _apiService.get<Map<String, dynamic>>(
        AppConstants.categoriesEndpoint,
      );

      ('🔵 [Categories API] Response success: ${response.success}');
      ('🔵 [Categories API] Response data: ${response}');

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        ('🔵 [Categories API] Data container: $dataContainer');
        (
            '🔵 [Categories API] Has categories key: ${dataContainer?.containsKey('categories')}');

        if (dataContainer != null && dataContainer.containsKey('categories')) {
          final categoriesData = dataContainer['categories'] as List;
          (
              '🔵 [Categories API] Categories data count: ${categoriesData.length}');
          ('🔵 [Categories API] Categories raw data: $categoriesData');

          final categories = categoriesData
              .map((category) =>
                  models.Category.fromJson(category as Map<String, dynamic>))
              .toList();

          (
              '🔵 [Categories API] Parsed categories count: ${categories.length}');
          for (var category in categories) {
            (
                '🔵 [Categories API] Category: id=${category.id}, name=${category.name}');
          }

          return ApiResponse<List<models.Category>>(
            success: true,
            data: categories,
            message: response.message ?? 'تم استرداد الفئات بنجاح',
          );
        } else {
          (
              '🔴 [Categories API] Categories key not found in data container');
          return ApiResponse<List<models.Category>>(
            success: false,
            error: 'بيانات الفئات غير صحيحة في الرد',
          );
        }
      } else {
        ('🔴 [Categories API] Response failed or data is null');
        return ApiResponse<List<models.Category>>(
          success: false,
          error: response.error ?? 'فشل في استرداد الفئات',
        );
      }
    } catch (e) {
      ('🔴 [Categories API] Exception: $e');
      if (kDebugMode) {
        ('UserVendorService.getCategories error: $e');
      }
      return ApiResponse<List<models.Category>>(
        success: false,
        error: 'حدث خطأ أثناء استرداد الفئات: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<double>> getVendorPricing({
    required String vendorId,
    required String neighborhoodId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'vendorId': vendorId,
      };

      final response = await _apiService.get<Map<String, dynamic>>(
        '/vendor-pricing/$neighborhoodId',
        queryParameters: queryParameters,
      );

      if (response.success && response.data != null) {
        final dataContainer = response.data is Map<String, dynamic> &&
                response.data!.containsKey('data')
            ? response.data!['data'] as Map<String, dynamic>?
            : response.data!;

        if (dataContainer != null && dataContainer.containsKey('price')) {
          final price = dataContainer['price'] is num
              ? (dataContainer['price'] as num).toDouble()
              : double.tryParse(dataContainer['price']?.toString() ?? '0') ??
                  0.0;

          return ApiResponse<double>(
            success: true,
            data: price,
            message: response.message ?? 'تم استرداد سعر التوصيل بنجاح',
          );
        } else {
          return ApiResponse<double>(
            success: false,
            error: 'بيانات السعر غير صحيحة في الرد',
          );
        }
      } else {
        return ApiResponse<double>(
          success: false,
          error: response.error ?? 'فشل في استرداد سعر التوصيل',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        ('UserVendorService.getVendorPricing error: $e');
      }
      return ApiResponse<double>(
        success: false,
        error: 'حدث خطأ أثناء استرداد سعر التوصيل: ${e.toString()}',
      );
    }
  }
}
