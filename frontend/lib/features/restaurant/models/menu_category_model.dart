/// Represents a menu category for grouping items (SRS REST-3).
class MenuCategoryModel {
  final String id;
  final String restaurantId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int? itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuCategoryModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) {
    return MenuCategoryModel(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      name: json['name'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      itemCount: json['itemCount'] as int?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'sortOrder': sortOrder,
      'isActive': isActive,
      if (itemCount != null) 'itemCount': itemCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MenuCategoryModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    int? sortOrder,
    bool? isActive,
    int? itemCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuCategoryModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

