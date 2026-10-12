/// Immutable tax invoice models matching order snapshots (SRS PAY-04).
class InvoiceItemModel {
  final String id;
  final String name;
  final String? description;
  final String unitPrice;
  final bool isVeg;
  final int quantity;
  final String lineTotal;
  final String? itemInstructions;

  InvoiceItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.unitPrice,
    required this.isVeg,
    required this.quantity,
    required this.lineTotal,
    this.itemInstructions,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      unitPrice: json['unitPrice'] as String? ?? '0.00',
      isVeg: json['isVeg'] as bool? ?? false,
      quantity: json['quantity'] as int? ?? 1,
      lineTotal: json['lineTotal'] as String? ?? '0.00',
      itemInstructions: json['itemInstructions'] as String?,
    );
  }
}

class InvoiceRecordModel {
  final String id;
  final String orderId;
  final String invoiceNumber;
  final String customerId;
  final String restaurantId;
  final DateTime issuedAt;
  final String subtotal;
  final String deliveryFee;
  final String taxAmount;
  final String discountAmount;
  final String totalAmount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddress;

  InvoiceRecordModel({
    required this.id,
    required this.orderId,
    required this.invoiceNumber,
    required this.customerId,
    required this.restaurantId,
    required this.issuedAt,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddress,
  });

  factory InvoiceRecordModel.fromJson(Map<String, dynamic> json) {
    return InvoiceRecordModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      customerId: json['customerId'] as String,
      restaurantId: json['restaurantId'] as String,
      issuedAt: json['issuedAt'] != null
          ? DateTime.parse(json['issuedAt'].toString())
          : DateTime.now(),
      subtotal: json['subtotal'] as String? ?? '0.00',
      deliveryFee: json['deliveryFee'] as String? ?? '0.00',
      taxAmount: json['taxAmount'] as String? ?? '0.00',
      discountAmount: json['discountAmount'] as String? ?? '0.00',
      totalAmount: json['totalAmount'] as String? ?? '0.00',
      currency: json['currency'] as String? ?? 'INR',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH_ON_DELIVERY',
      paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
      recipientName: json['recipientName'] as String? ?? '',
      recipientPhone: json['recipientPhone'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
    );
  }
}

class InvoiceDetailModel {
  final InvoiceRecordModel invoice;
  final Map<String, dynamic> order;
  final Map<String, dynamic> restaurant;
  final Map<String, dynamic> customer;
  final List<InvoiceItemModel> items;
  final Map<String, dynamic> breakdown;
  final Map<String, dynamic> payment;

  InvoiceDetailModel({
    required this.invoice,
    required this.order,
    required this.restaurant,
    required this.customer,
    required this.items,
    required this.breakdown,
    required this.payment,
  });

  factory InvoiceDetailModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return InvoiceDetailModel(
      invoice: InvoiceRecordModel.fromJson(json['invoice'] as Map<String, dynamic>),
      order: json['order'] as Map<String, dynamic>? ?? {},
      restaurant: json['restaurant'] as Map<String, dynamic>? ?? {},
      customer: json['customer'] as Map<String, dynamic>? ?? {},
      items: itemsList,
      breakdown: json['breakdown'] as Map<String, dynamic>? ?? {},
      payment: json['payment'] as Map<String, dynamic>? ?? {},
    );
  }
}

