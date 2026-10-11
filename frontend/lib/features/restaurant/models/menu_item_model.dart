/// Represents a menu item with pricing, availability, and tags (SRS REST-3, REST-4, REST-5, REST-6, NFR-12).
class MenuItemModel {
  final String id;
  final String restaurantId;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final String price; // In INR format e.g. "250.00"
  final bool isVeg;
  final String? imageUrl;
  final bool isAvailable;
  final String? availableFrom; // HH:MM
  final String? availableUntil; // HH:MM
  final bool isSpecialOffer;
  final String? offerPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuItemModel({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    required this.isVeg,
    this.imageUrl,
    required this.isAvailable,
    this.availableFrom,
    this.availableUntil,
    required this.isSpecialOffer,
    this.offerPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  double get parsedPrice => double.tryParse(price) ?? 0.0;
  double get parsedOfferPrice =>
      offerPrice != null ? (double.tryParse(offerPrice!) ?? 0.0) : 0.0;
  double get effectivePrice =>
      (isSpecialOffer && offerPrice != null) ? parsedOfferPrice : parsedPrice;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: json['price']?.toString() ?? '0.00',
      isVeg: json['isVeg'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      availableFrom: json['availableFrom'] as String?,
      availableUntil: json['availableUntil'] as String?,
      isSpecialOffer: json['isSpecialOffer'] as bool? ?? false,
      offerPrice: json['offerPrice']?.toString(),
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
      'categoryId': categoryId,
      if (categoryName != null) 'categoryName': categoryName,
      'name': name,
      'description': description,
      'price': price,
      'isVeg': isVeg,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'availableFrom': availableFrom,
      'availableUntil': availableUntil,
      'isSpecialOffer': isSpecialOffer,
      'offerPrice': offerPrice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? restaurantId,
    String? categoryId,
    String? categoryName,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isVeg: isVeg ?? this.isVeg,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      isSpecialOffer: isSpecialOffer ?? this.isSpecialOffer,
      offerPrice: offerPrice ?? this.offerPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
