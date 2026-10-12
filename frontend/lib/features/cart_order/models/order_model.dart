/// Status of order fulfillment per SRS ORDER-1..5 and Section 6.
enum OrderFulfillmentStatus {
  placed,
  confirmed,
  preparing,
  outForDelivery,
  delivered,
  cancelled;

  static OrderFulfillmentStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CONFIRMED':
        return OrderFulfillmentStatus.confirmed;
      case 'PREPARING':
        return OrderFulfillmentStatus.preparing;
      case 'OUT_FOR_DELIVERY':
        return OrderFulfillmentStatus.outForDelivery;
      case 'DELIVERED':
        return OrderFulfillmentStatus.delivered;
      case 'CANCELLED':
        return OrderFulfillmentStatus.cancelled;
      case 'PLACED':
      default:
        return OrderFulfillmentStatus.placed;
    }
  }

  String get toApiString {
    switch (this) {
      case OrderFulfillmentStatus.confirmed:
        return 'CONFIRMED';
      case OrderFulfillmentStatus.preparing:
        return 'PREPARING';
      case OrderFulfillmentStatus.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case OrderFulfillmentStatus.delivered:
        return 'DELIVERED';
      case OrderFulfillmentStatus.cancelled:
        return 'CANCELLED';
      case OrderFulfillmentStatus.placed:
        return 'PLACED';
    }
  }

  String get displayLabel {
    switch (this) {
      case OrderFulfillmentStatus.placed:
        return 'Order Placed';
      case OrderFulfillmentStatus.confirmed:
        return 'Confirmed';
      case OrderFulfillmentStatus.preparing:
        return 'Preparing Food';
      case OrderFulfillmentStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderFulfillmentStatus.delivered:
        return 'Delivered';
      case OrderFulfillmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isCancellable =>
      this == OrderFulfillmentStatus.placed || this == OrderFulfillmentStatus.confirmed;
}

/// Status of payment.
enum OrderPaymentStatus {
  pending,
  paid,
  refunded,
  failed;

  static OrderPaymentStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PAID':
        return OrderPaymentStatus.paid;
      case 'REFUNDED':
        return OrderPaymentStatus.refunded;
      case 'FAILED':
        return OrderPaymentStatus.failed;
      case 'PENDING':
      default:
        return OrderPaymentStatus.pending;
    }
  }
}

/// Immutable line item snapshot preserved at order placement time (ORD-05, NFR-12).
class OrderItemModel {
  final String id;
  final String orderId;
  final String? menuItemId;
  final String itemName;
  final String? itemDescription;
  final String unitPrice;
  final bool isVeg;
  final int quantity;
  final String lineTotal;
  final String? itemInstructions;
  final DateTime? createdAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.menuItemId,
    required this.itemName,
    this.itemDescription,
    required this.unitPrice,
    required this.isVeg,
    required this.quantity,
    required this.lineTotal,
    this.itemInstructions,
    this.createdAt,
  });

  double get unitPriceDouble => double.tryParse(unitPrice) ?? 0.0;
  double get lineTotalDouble => double.tryParse(lineTotal) ?? 0.0;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      menuItemId: json['menuItemId'] as String?,
      itemName: json['itemName'] as String? ?? 'Item',
      itemDescription: json['itemDescription'] as String?,
      unitPrice: json['unitPrice']?.toString() ?? '0.00',
      isVeg: json['isVeg'] as bool? ?? true,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      lineTotal: json['lineTotal']?.toString() ?? '0.00',
      itemInstructions: json['itemInstructions'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Status timeline event entry.
class OrderStatusEventModel {
  final String id;
  final String orderId;
  final String? fromStatus;
  final String toStatus;
  final String? actorRole;
  final String? note;
  final DateTime? createdAt;

  const OrderStatusEventModel({
    required this.id,
    required this.orderId,
    this.fromStatus,
    required this.toStatus,
    this.actorRole,
    this.note,
    this.createdAt,
  });

  factory OrderStatusEventModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusEventModel(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String? ?? 'PLACED',
      actorRole: json['actorRole'] as String?,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Full authoritative Order model.
class OrderModel {
  final String id;
  final String publicOrderNumber;
  final String customerId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String deliveryAddressSnapshot;
  final String customerPhoneSnapshot;
  final String customerNameSnapshot;
  final String? specialInstructions;
  final bool isScheduled;
  final DateTime? scheduledFor;
  final String subtotal;
  final String deliveryFee;
  final String taxAmount;
  final String discountAmount;
  final String totalAmount;
  final OrderFulfillmentStatus fulfillmentStatus;
  final OrderPaymentStatus paymentStatus;
  final String paymentMethod;
  final String? idempotencyKey;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final List<OrderItemModel> items;
  final List<OrderStatusEventModel> statusTimeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.publicOrderNumber,
    required this.customerId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.deliveryAddressSnapshot,
    required this.customerPhoneSnapshot,
    required this.customerNameSnapshot,
    this.specialInstructions,
    required this.isScheduled,
    this.scheduledFor,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.fulfillmentStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    this.idempotencyKey,
    this.cancellationReason,
    this.cancelledAt,
    required this.items,
    required this.statusTimeline,
    required this.createdAt,
    required this.updatedAt,
  });

  double get subtotalDouble => double.tryParse(subtotal) ?? 0.0;
  double get deliveryFeeDouble => double.tryParse(deliveryFee) ?? 0.0;
  double get taxAmountDouble => double.tryParse(taxAmount) ?? 0.0;
  double get discountAmountDouble => double.tryParse(discountAmount) ?? 0.0;
  double get totalAmountDouble => double.tryParse(totalAmount) ?? 0.0;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawTimeline = json['statusTimeline'] as List<dynamic>? ?? [];
    final timelineList = rawTimeline
        .map((e) => OrderStatusEventModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return OrderModel(
      id: json['id'] as String? ?? '',
      publicOrderNumber: json['publicOrderNumber'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      restaurantId: json['restaurantId'] as String? ?? '',
      restaurantName: json['restaurantName'] as String? ?? 'Restaurant',
      restaurantAddress: json['restaurantAddress'] as String? ?? '',
      deliveryAddressSnapshot: json['deliveryAddressSnapshot'] as String? ?? '',
      customerPhoneSnapshot: json['customerPhoneSnapshot'] as String? ?? '',
      customerNameSnapshot: json['customerNameSnapshot'] as String? ?? '',
      specialInstructions: json['specialInstructions'] as String?,
      isScheduled: json['isScheduled'] as bool? ?? false,
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'] as String)
          : null,
      subtotal: json['subtotal']?.toString() ?? '0.00',
      deliveryFee: json['deliveryFee']?.toString() ?? '0.00',
      taxAmount: json['taxAmount']?.toString() ?? '0.00',
      discountAmount: json['discountAmount']?.toString() ?? '0.00',
      totalAmount: json['totalAmount']?.toString() ?? '0.00',
      fulfillmentStatus: OrderFulfillmentStatus.fromString(
        json['fulfillmentStatus'] as String?,
      ),
      paymentStatus: OrderPaymentStatus.fromString(
        json['paymentStatus'] as String?,
      ),
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH_ON_DELIVERY',
      idempotencyKey: json['idempotencyKey'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      items: itemsList,
      statusTimeline: timelineList,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

