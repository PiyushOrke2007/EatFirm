import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../services/cart_order_api_service.dart';

/// Exception thrown when adding an item from a different restaurant,
/// requiring explicit customer replacement confirmation.
class DifferentRestaurantConflictException implements Exception {
  final String existingRestaurantName;
  final String newRestaurantId;
  final String menuItemId;
  final int quantity;
  final String? itemInstructions;

  DifferentRestaurantConflictException({
    required this.existingRestaurantName,
    required this.newRestaurantId,
    required this.menuItemId,
    required this.quantity,
    this.itemInstructions,
  });
}

/// State provider for Cart and Order workflows across the application.
class CartOrderProvider extends ChangeNotifier {
  final CartOrderApiService apiService;

  CartModel? _cart;
  bool _isLoadingCart = false;
  String? _cartError;

  List<OrderModel> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;

  OrderModel? _currentOrder;
  bool _isLoadingOrderDetail = false;
  String? _orderDetailError;

  bool _isPlacingOrder = false;
  String? _placeOrderError;

  bool _isCancellingOrder = false;

  CartOrderProvider({required this.apiService});

  CartModel? get cart => _cart;
  bool get isLoadingCart => _isLoadingCart;
  String? get cartError => _cartError;
  bool get hasCartItems => _cart != null && _cart!.items.isNotEmpty;
  int get totalItemCount => _cart?.itemCount ?? 0;

  List<OrderModel> get orders => _orders;
  bool get isLoadingOrders => _isLoadingOrders;
  String? get ordersError => _ordersError;

  OrderModel? get currentOrder => _currentOrder;
  bool get isLoadingOrderDetail => _isLoadingOrderDetail;
  String? get orderDetailError => _orderDetailError;

  bool get isPlacingOrder => _isPlacingOrder;
  String? get placeOrderError => _placeOrderError;
  bool get isCancellingOrder => _isCancellingOrder;

  /// Loads the active cart from the backend.
  Future<void> loadCart() async {
    _isLoadingCart = true;
    _cartError = null;
    notifyListeners();

    try {
      _cart = await apiService.getCart();
    } catch (e) {
      _cartError = e.toString();
    } finally {
      _isLoadingCart = false;
      notifyListeners();
    }
  }

  /// Adds a dish to the shopping cart.
  /// If the cart contains items from a different restaurant, throws
  /// [DifferentRestaurantConflictException] so the UI can prompt the user.
  Future<void> addToCart({
    required String restaurantId,
    required String menuItemId,
    required int quantity,
    String? itemInstructions,
    bool replaceCart = false,
  }) async {
    _cartError = null;
    notifyListeners();

    try {
      _cart = await apiService.addToCart(
        restaurantId: restaurantId,
        menuItemId: menuItemId,
        quantity: quantity,
        itemInstructions: itemInstructions,
        replaceCart: replaceCart,
      );
      notifyListeners();
    } on ApiException catch (e) {
      if (e.code == 'DIFFERENT_RESTAURANT_CONFLICT') {
        throw DifferentRestaurantConflictException(
          existingRestaurantName: _cart?.restaurantName ?? 'another restaurant',
          newRestaurantId: restaurantId,
          menuItemId: menuItemId,
          quantity: quantity,
          itemInstructions: itemInstructions,
        );
      }
      _cartError = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _cartError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates quantity of an item in the cart.
  Future<void> updateItemQuantity(String cartItemId, int newQuantity) async {
    try {
      _cart = await apiService.updateCartItem(
        cartItemId: cartItemId,
        quantity: newQuantity,
      );
      notifyListeners();
    } catch (e) {
      _cartError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Removes an item from the cart.
  Future<void> removeItem(String cartItemId) async {
    try {
      _cart = await apiService.removeCartItem(cartItemId);
      notifyListeners();
    } catch (e) {
      _cartError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates chef instructions for the whole order (CART-2).
  Future<void> updateSpecialInstructions(String notes) async {
    try {
      _cart = await apiService.updateCartInstructions(notes);
      notifyListeners();
    } catch (e) {
      _cartError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clears the entire cart.
  Future<void> clearCart() async {
    try {
      await apiService.clearCart();
      _cart = null;
      notifyListeners();
    } catch (e) {
      _cartError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Helper to generate a unique client idempotency key.
  String generateIdempotencyKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'idemp-$timestamp-$random';
  }

  /// Places an order from the active cart.
  Future<OrderModel> placeOrder({
    required String deliveryAddress,
    required String customerPhone,
    required String customerName,
    String? specialInstructions,
    bool isScheduled = false,
    DateTime? scheduledFor,
    required String idempotencyKey,
  }) async {
    _isPlacingOrder = true;
    _placeOrderError = null;
    notifyListeners();

    try {
      final order = await apiService.placeOrder(
        deliveryAddress: deliveryAddress,
        customerPhone: customerPhone,
        customerName: customerName,
        specialInstructions: specialInstructions,
        isScheduled: isScheduled,
        scheduledFor: scheduledFor,
        idempotencyKey: idempotencyKey,
      );

      // Cart is cleared upon successful order placement
      _cart = null;
      _currentOrder = order;

      // Prepend to orders list
      _orders.insert(0, order);

      return order;
    } on ApiException catch (e) {
      _placeOrderError = e.message;
      rethrow;
    } catch (e) {
      _placeOrderError = e.toString();
      rethrow;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  /// Loads orders history for the current user.
  Future<void> loadOrders() async {
    _isLoadingOrders = true;
    _ordersError = null;
    notifyListeners();

    try {
      _orders = await apiService.listOrders();
    } catch (e) {
      _ordersError = e.toString();
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Fetches details for a single order by ID.
  Future<void> loadOrderDetail(String orderId) async {
    _isLoadingOrderDetail = true;
    _orderDetailError = null;
    notifyListeners();

    try {
      _currentOrder = await apiService.getOrder(orderId);
    } catch (e) {
      _orderDetailError = e.toString();
    } finally {
      _isLoadingOrderDetail = false;
      notifyListeners();
    }
  }

  /// Cancels an order with specified reason (ORD-08, Section 6, NFR-14, NFR-16).
  Future<OrderModel> cancelOrder(String orderId, String reason) async {
    _isCancellingOrder = true;
    notifyListeners();

    try {
      final updated = await apiService.cancelOrder(
        orderId: orderId,
        reason: reason,
      );

      _currentOrder = updated;

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = updated;
      }

      return updated;
    } catch (e) {
      rethrow;
    } finally {
      _isCancellingOrder = false;
      notifyListeners();
    }
  }
}

