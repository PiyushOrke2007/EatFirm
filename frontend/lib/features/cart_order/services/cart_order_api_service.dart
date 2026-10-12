import '../../../core/network/api_client.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';

/// Service interfacing with EatFirm REST backend for shopping cart and orders.
class CartOrderApiService {
  final ApiClient apiClient;

  CartOrderApiService({required this.apiClient});

  // --- Cart Operations ---

  /// Fetches the authenticated user's current shopping cart.
  Future<CartModel?> getCart() async {
    final response = await apiClient.get<dynamic>(
      '/cart',
      fromJson: (data) => data,
    );
    if (response.data == null) return null;
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Adds a dish to the active cart with single-restaurant conflict handling.
  Future<CartModel> addToCart({
    required String restaurantId,
    required String menuItemId,
    required int quantity,
    String? itemInstructions,
    bool? replaceCart,
  }) async {
    final body = <String, dynamic>{
      'restaurantId': restaurantId,
      'menuItemId': menuItemId,
      'quantity': quantity,
      if (itemInstructions != null && itemInstructions.isNotEmpty)
        'itemInstructions': itemInstructions,
      'replaceCart': ?replaceCart,
    };

    final response = await apiClient.post<dynamic>(
      '/cart/items',
      body: body,
      fromJson: (data) => data,
    );

    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates quantity or chef instructions for an item.
  Future<CartModel?> updateCartItem({
    required String cartItemId,
    required int quantity,
    String? itemInstructions,
  }) async {
    final body = <String, dynamic>{
      'quantity': quantity,
      'itemInstructions': ?itemInstructions,
    };

    final response = await apiClient.patch<dynamic>(
      '/cart/items/$cartItemId',
      body: body,
      fromJson: (data) => data,
    );

    if (response.data == null) return null;
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Removes a line item from the cart.
  Future<CartModel?> removeCartItem(String cartItemId) async {
    final response = await apiClient.delete<dynamic>(
      '/cart/items/$cartItemId',
      fromJson: (data) => data,
    );

    if (response.data == null) return null;
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates overall chef cooking instructions for the cart (SRS CART-2).
  Future<CartModel> updateCartInstructions(String instructions) async {
    final response = await apiClient.patch<dynamic>(
      '/cart/instructions',
      body: {'specialInstructions': instructions},
      fromJson: (data) => data,
    );

    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Clears the active shopping cart entirely.
  Future<void> clearCart() async {
    await apiClient.delete<dynamic>('/cart');
  }

  // --- Order Operations ---

  /// Places an order from the active cart with idempotency protection (ORD-04).
  Future<OrderModel> placeOrder({
    required String deliveryAddress,
    required String customerPhone,
    required String customerName,
    String? specialInstructions,
    bool? isScheduled,
    DateTime? scheduledFor,
    required String idempotencyKey,
    String paymentMethod = 'CASH_ON_DELIVERY',
  }) async {
    final body = <String, dynamic>{
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'customerName': customerName,
      if (specialInstructions != null && specialInstructions.isNotEmpty)
        'specialInstructions': specialInstructions,
      'isScheduled': ?isScheduled,
      if (scheduledFor != null) 'scheduledFor': scheduledFor.toUtc().toIso8601String(),
      'idempotencyKey': idempotencyKey,
      'paymentMethod': paymentMethod,
    };

    final response = await apiClient.post<dynamic>(
      '/orders',
      body: body,
      fromJson: (data) => data,
    );

    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches order history for current customer.
  Future<List<OrderModel>> listOrders({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': limit,
      'offset': offset,
    };

    final response = await apiClient.get<dynamic>(
      '/orders',
      queryParameters: params,
      fromJson: (data) => data,
    );

    final rawList = response.data as List<dynamic>? ?? [];
    return rawList
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retrieves full order details, line items, and timeline by ID.
  Future<OrderModel> getOrder(String orderId) async {
    final response = await apiClient.get<dynamic>(
      '/orders/$orderId',
      fromJson: (data) => data,
    );

    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Cancels an order in eligible lifecycle state (SRS ORD-08, Section 6, NFR-14, NFR-16).
  Future<OrderModel> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    final response = await apiClient.post<dynamic>(
      '/orders/$orderId/cancel',
      body: {'reason': reason},
      fromJson: (data) => data,
    );

    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }
}
