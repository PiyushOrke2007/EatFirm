import '../../../core/network/api_client.dart';
import '../../restaurant/models/restaurant_model.dart';
import '../models/browse_filter_model.dart';
import '../models/search_suggestion_model.dart';
import '../models/customer_menu_model.dart';

class BrowseResult {
  final List<RestaurantModel> restaurants;
  final int total;
  final int page;
  final int totalPages;

  const BrowseResult({
    required this.restaurants,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

/// Service handling public discovery, search, comparison, and customer menu APIs (SRS Section 4.3).
class BrowseApiService {
  final ApiClient apiClient;

  BrowseApiService({required this.apiClient});

  /// BROWSE-1 & BROWSE-2: Live restaurant discovery with multi-attribute filtering & sorting.
  Future<BrowseResult> browseRestaurants(BrowseFilterModel filters) async {
    final response = await apiClient.get(
      '/restaurants',
      queryParameters: filters.toQueryParams(),
    );

    if (response.data is! Map) {
      return const BrowseResult(restaurants: [], total: 0, page: 1, totalPages: 0);
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['restaurants'] as List? ?? [];
    final restaurants = rawList
        .map((r) => RestaurantModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    return BrowseResult(
      restaurants: restaurants,
      total: (data['total'] as num?)?.toInt() ?? restaurants.length,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  /// SRS NFR-4: Sub-2s search suggestions for auto-complete.
  Future<List<SearchSuggestionModel>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    final response = await apiClient.get(
      '/restaurants/search/suggestions',
      queryParameters: {'q': query.trim()},
    );

    if (response.data is! Map) return [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['suggestions'] as List? ?? [];

    return rawList
        .map((s) => SearchSuggestionModel.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
  }

  /// Retrieves public restaurant details.
  Future<RestaurantModel> getRestaurantDetails(String id) async {
    final response = await apiClient.get('/restaurants/$id');
    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final restData = data['restaurant'];
    if (restData is! Map) {
      throw Exception('Missing restaurant data in server response');
    }
    return RestaurantModel.fromJson(Map<String, dynamic>.from(restData));
  }

  /// BROWSE-3 & NFR-12: Retrieves public customer menu with categories and veg filter.
  Future<CustomerMenuResponse> getCustomerRestaurantMenu(
    String restaurantId, {
    String? categoryId,
    bool? isVeg,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['categoryId'] = categoryId;
    }
    if (isVeg != null) {
      queryParams['isVeg'] = isVeg.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await apiClient.get(
      '/restaurants/$restaurantId/menu',
      queryParameters: queryParams,
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    return CustomerMenuResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}

