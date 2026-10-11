import '../../../core/network/api_client.dart';
import '../models/restaurant_model.dart';
import '../models/menu_category_model.dart';
import '../models/menu_item_model.dart';
import '../models/operating_hours_model.dart';

/// Service interfacing with EatFirm REST backend for Restaurant and Menu APIs (Module 03).
class RestaurantApiService {
  final ApiClient apiClient;

  RestaurantApiService({required this.apiClient});

  /// Onboard restaurant profile (SRS REST-1, Section 6).
  Future<RestaurantModel> onboardRestaurant({
    required String name,
    String? description,
    required String address,
    required String phone,
    required String cuisineType,
    required String foodLicenseNumber,
    String? imageUrl,
    List<OperatingHoursModel>? operatingHours,
  }) async {
    final response = await apiClient.post(
      '/restaurants/onboard',
      body: {
        'name': name.trim(),
        if (description != null && description.isNotEmpty)
          'description': description.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'cuisineType': cuisineType.trim(),
        'foodLicenseNumber': foodLicenseNumber.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty)
          'imageUrl': imageUrl.trim(),
        if (operatingHours != null)
          'operatingHours': operatingHours.map((h) => h.toJson()).toList(),
      },
    );

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

  /// Retrieves the authenticated Restaurant Admin's primary restaurant.
  Future<RestaurantModel?> getMyRestaurant() async {
    final response = await apiClient.get('/restaurants/mine');
    if (response.data is! Map) return null;
    final data = Map<String, dynamic>.from(response.data as Map);
    final restData = data['restaurant'];
    if (restData == null || restData is! Map) return null;
    return RestaurantModel.fromJson(Map<String, dynamic>.from(restData));
  }

  /// Updates profile details of the owner's restaurant.
  Future<RestaurantModel> updateRestaurantProfile({
    String? name,
    String? description,
    String? address,
    String? phone,
    String? cuisineType,
    String? foodLicenseNumber,
    String? imageUrl,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/mine',
      body: {
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (address != null) 'address': address.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (cuisineType != null) 'cuisineType': cuisineType.trim(),
        if (foodLicenseNumber != null)
          'foodLicenseNumber': foodLicenseNumber.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl.trim(),
      },
    );

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

  /// Toggles open/closed operational status (SRS REST-5).
  Future<RestaurantModel> toggleRestaurantOpen(bool isOpen) async {
    final response = await apiClient.patch(
      '/restaurants/mine/toggle-open',
      body: {'isOpen': isOpen},
    );

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

  /// Updates weekly operating hours schedule.
  Future<List<OperatingHoursModel>> updateOperatingHours(
    List<OperatingHoursModel> operatingHours,
  ) async {
    final response = await apiClient.put(
      '/restaurants/mine/operating-hours',
      body: {
        'operatingHours': operatingHours.map((h) => h.toJson()).toList(),
      },
    );

    if (response.data is! Map) return [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['operatingHours'];
    if (rawList is! List) return [];
    return rawList
        .map(
          (h) => OperatingHoursModel.fromJson(
            Map<String, dynamic>.from(h as Map),
          ),
        )
        .toList();
  }

  /// Fetches categories for the authenticated admin's restaurant (SRS REST-3).
  Future<List<MenuCategoryModel>> getCategories() async {
    final response = await apiClient.get('/restaurants/mine/categories');
    if (response.data is! Map) return [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['categories'];
    if (rawList is! List) return [];
    return rawList
        .map(
          (c) => MenuCategoryModel.fromJson(
            Map<String, dynamic>.from(c as Map),
          ),
        )
        .toList();
  }

  /// Creates a new menu category (SRS REST-3).
  Future<MenuCategoryModel> createCategory(
    String name, {
    int sortOrder = 0,
  }) async {
    final response = await apiClient.post(
      '/restaurants/mine/categories',
      body: {
        'name': name.trim(),
        'sortOrder': sortOrder,
      },
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final catData = data['category'];
    if (catData is! Map) {
      throw Exception('Missing category data in server response');
    }
    return MenuCategoryModel.fromJson(Map<String, dynamic>.from(catData));
  }

  /// Updates a category name, order, or active state.
  Future<MenuCategoryModel> updateCategory(
    String categoryId, {
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/mine/categories/$categoryId',
      body: {
        if (name != null) 'name': name.trim(),
        'sortOrder': ?sortOrder,
        'isActive': ?isActive,
      },
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final catData = data['category'];
    if (catData is! Map) {
      throw Exception('Missing category data in server response');
    }
    return MenuCategoryModel.fromJson(Map<String, dynamic>.from(catData));
  }

  /// Deletes a menu category (must have no items).
  Future<void> deleteCategory(String categoryId) async {
    await apiClient.delete('/restaurants/mine/categories/$categoryId');
  }

  /// Fetches menu items for the restaurant with optional category filter.
  Future<List<MenuItemModel>> getMenuItems({String? categoryId}) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['categoryId'] = categoryId;
    }

    final response = await apiClient.get(
      '/restaurants/mine/menu-items',
      queryParameters: queryParams,
    );

    if (response.data is! Map) return [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['menuItems'];
    if (rawList is! List) return [];
    return rawList
        .map(
          (m) => MenuItemModel.fromJson(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList();
  }

  /// Creates a new menu item (SRS REST-3, REST-5, REST-6, NFR-12).
  Future<MenuItemModel> createMenuItem({
    required String categoryId,
    required String name,
    String? description,
    required String price,
    bool isVeg = true,
    String? imageUrl,
    bool isAvailable = true,
    String? availableFrom,
    String? availableUntil,
    bool isSpecialOffer = false,
    String? offerPrice,
  }) async {
    final response = await apiClient.post(
      '/restaurants/mine/menu-items',
      body: {
        'categoryId': categoryId,
        'name': name.trim(),
        if (description != null && description.isNotEmpty)
          'description': description.trim(),
        'price': price,
        'isVeg': isVeg,
        if (imageUrl != null && imageUrl.isNotEmpty)
          'imageUrl': imageUrl.trim(),
        'isAvailable': isAvailable,
        'availableFrom': availableFrom,
        'availableUntil': availableUntil,
        'isSpecialOffer': isSpecialOffer,
        if (isSpecialOffer && offerPrice != null) 'offerPrice': offerPrice,
      },
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final itemData = data['menuItem'];
    if (itemData is! Map) {
      throw Exception('Missing menu item data in server response');
    }
    return MenuItemModel.fromJson(Map<String, dynamic>.from(itemData));
  }

  /// Updates existing menu item.
  Future<MenuItemModel> updateMenuItem(
    String itemId, {
    String? categoryId,
    String? name,
    String? description,
    String? price,
    bool? isVeg,
    String? imageUrl,
    bool? isAvailable,
    String? availableFrom,
    String? availableUntil,
    bool? isSpecialOffer,
    String? offerPrice,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/mine/menu-items/$itemId',
      body: {
        'categoryId': ?categoryId,
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        'price': ?price,
        'isVeg': ?isVeg,
        if (imageUrl != null) 'imageUrl': imageUrl.trim(),
        'isAvailable': ?isAvailable,
        'availableFrom': availableFrom,
        'availableUntil': availableUntil,
        'isSpecialOffer': ?isSpecialOffer,
        'offerPrice': ?offerPrice,
      },
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final itemData = data['menuItem'];
    if (itemData is! Map) {
      throw Exception('Missing menu item data in server response');
    }
    return MenuItemModel.fromJson(Map<String, dynamic>.from(itemData));
  }

  /// Quick toggle for menu item temporary availability (SRS REST-4).
  Future<MenuItemModel> toggleItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    final response = await apiClient.patch(
      '/restaurants/mine/menu-items/$itemId/toggle-availability',
      body: {'isAvailable': isAvailable},
    );

    if (response.data is! Map) {
      throw Exception('Invalid server response format');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final itemData = data['menuItem'];
    if (itemData is! Map) {
      throw Exception('Missing menu item data in server response');
    }
    return MenuItemModel.fromJson(Map<String, dynamic>.from(itemData));
  }

  /// Deletes a menu item (SRS NFR-14).
  Future<void> deleteMenuItem(String itemId) async {
    await apiClient.delete('/restaurants/mine/menu-items/$itemId');
  }

  // --- SYSTEM ADMINISTRATOR APPROVALS (SRS REST-2) ---

  /// Lists pending restaurant registrations.
  Future<List<RestaurantModel>> listPendingRestaurants() async {
    final response = await apiClient.get('/restaurants/pending');
    if (response.data is! Map) return [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawList = data['restaurants'];
    if (rawList is! List) return [];
    return rawList
        .map(
          (r) => RestaurantModel.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();
  }

  /// Approves a restaurant registration.
  Future<RestaurantModel> approveRestaurant(String restaurantId) async {
    final response = await apiClient.post('/restaurants/$restaurantId/approve');
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

  /// Rejects a restaurant registration with a mandatory reason.
  Future<RestaurantModel> rejectRestaurant(
    String restaurantId,
    String reason,
  ) async {
    final response = await apiClient.post(
      '/restaurants/$restaurantId/reject',
      body: {'reason': reason.trim()},
    );
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
}
