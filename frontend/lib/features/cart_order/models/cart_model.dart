/// Data model for an individual dish inside the shopping cart.
class CartItemModel {
  final String id;
  final String cartId;
  final String menuItemId;
  final int quantity;
  final String? itemInstructions;
  final String name;
  final String? description;
  final String price;
  final String effectivePrice;
  final bool isVeg;
  final bool isAvailable;
  final String? imageUrl;
  final String lineTotal;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.menuItemId,
    required this.quantity,
    this.itemInstructions,
    required this.name,
    this.description,
    required this.price,
    required this.effectivePrice,
    required this.isVeg,
    required this.isAvailable,
    this.imageUrl,
    required this.lineTotal,
  });

  double get effectivePriceDouble => double.tryParse(effectivePrice) ?? 0.0;
  double get lineTotalDouble => double.tryParse(lineTotal) ?? 0.0;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String? ?? '',
      cartId: json['cartId'] as String? ?? '',
      menuItemId: json['menuItemId'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      itemInstructions: json['itemInstructions'] as String?,
      name: json['name'] as String? ?? 'Unnamed item',
      description: json['description'] as String?,
      price: json['price']?.toString() ?? '0.00',
      effectivePrice: json['effectivePrice']?.toString() ?? '0.00',
      isVeg: json['isVeg'] as bool? ?? true,
      isAvailable: json['isAvailable'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
      lineTotal: json['lineTotal']?.toString() ?? '0.00',
    );
  }
}

/// Data model representing the active single-restaurant shopping cart.
class CartModel {
  final String id;
  final String customerId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String? specialInstructions;
  final List<CartItemModel> items;
  final int itemCount;
  final String subtotal;
  final String deliveryFee;
  final String taxAmount;
  final String discountAmount;
  final String totalAmount;

  const CartModel({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    this.specialInstructions,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
  });

  double get subtotalDouble => double.tryParse(subtotal) ?? 0.0;
  double get deliveryFeeDouble => double.tryParse(deliveryFee) ?? 0.0;
  double get taxAmountDouble => double.tryParse(taxAmount) ?? 0.0;
  double get discountAmountDouble => double.tryParse(discountAmount) ?? 0.0;
  double get totalAmountDouble => double.tryParse(totalAmount) ?? 0.0;

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return CartModel(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      restaurantId: json['restaurantId'] as String? ?? '',
      restaurantName: json['restaurantName'] as String? ?? 'Restaurant',
      restaurantAddress: json['restaurantAddress'] as String? ?? '',
      specialInstructions: json['specialInstructions'] as String?,
      items: itemsList,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? itemsList.length,
      subtotal: json['subtotal']?.toString() ?? '0.00',
      deliveryFee: json['deliveryFee']?.toString() ?? '0.00',
      taxAmount: json['taxAmount']?.toString() ?? '0.00',
      discountAmount: json['discountAmount']?.toString() ?? '0.00',
      totalAmount: json['totalAmount']?.toString() ?? '0.00',
    );
  }
}

