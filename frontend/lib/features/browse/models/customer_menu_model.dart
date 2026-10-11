import '../../restaurant/models/restaurant_model.dart';
import '../../restaurant/models/menu_item_model.dart';

/// Category containing its menu items for customer menu viewing (SRS BROWSE-3).
class MenuCategoryWithItems {
  final String id;
  final String name;
  final int sortOrder;
  final List<MenuItemModel> items;

  const MenuCategoryWithItems({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    required this.items,
  });

  factory MenuCategoryWithItems.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return MenuCategoryWithItems(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
      items: rawItems
          .map((i) => MenuItemModel.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

/// Aggregated response for customer restaurant menu page (SRS BROWSE-3, NFR-12).
class CustomerMenuResponse {
  final RestaurantModel restaurant;
  final List<MenuCategoryWithItems> categories;
  final List<MenuItemModel> menuItems;

  const CustomerMenuResponse({
    required this.restaurant,
    required this.categories,
    required this.menuItems,
  });

  factory CustomerMenuResponse.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List? ?? [];
    final rawItems = json['menuItems'] as List? ?? [];

    return CustomerMenuResponse(
      restaurant: RestaurantModel.fromJson(
        Map<String, dynamic>.from(json['restaurant'] as Map),
      ),
      categories: rawCats
          .map((c) =>
              MenuCategoryWithItems.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      menuItems: rawItems
          .map((i) =>
              MenuItemModel.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

