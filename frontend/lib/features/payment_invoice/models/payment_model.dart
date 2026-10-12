/// Authoritative payment record and audit timeline models (SRS PAY-01..03, PAY-05).
class PaymentModel {
  final String id;
  final String orderId;
  final String paymentMethod;
  final String paymentStatus;
  final String amount;
  final String currency;
  final DateTime? collectedAt;
  final String? collectedByUserId;
  final String? transactionReference;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amount,
    required this.currency,
    this.collectedAt,
    this.collectedByUserId,
    this.transactionReference,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => paymentStatus == 'PAID';
  bool get isPending => paymentStatus == 'PENDING';
  bool get isFailed => paymentStatus == 'FAILED';
  bool get isRefunded => paymentStatus == 'REFUNDED';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH_ON_DELIVERY',
      paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
      amount: json['amount'] as String? ?? '0.00',
      currency: json['currency'] as String? ?? 'INR',
      collectedAt: json['collectedAt'] != null
          ? DateTime.tryParse(json['collectedAt'].toString())
          : null,
      collectedByUserId: json['collectedByUserId'] as String?,
      transactionReference: json['transactionReference'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }
}

class PaymentEventModel {
  final String id;
  final String paymentId;
  final String? fromStatus;
  final String toStatus;
  final String? actorUserId;
  final String? actorRole;
  final String? transactionReference;
  final String? note;
  final DateTime createdAt;

  PaymentEventModel({
    required this.id,
    required this.paymentId,
    this.fromStatus,
    required this.toStatus,
    this.actorUserId,
    this.actorRole,
    this.transactionReference,
    this.note,
    required this.createdAt,
  });

  factory PaymentEventModel.fromJson(Map<String, dynamic> json) {
    return PaymentEventModel(
      id: json['id'] as String,
      paymentId: json['paymentId'] as String,
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String? ?? '',
      actorUserId: json['actorUserId'] as String?,
      actorRole: json['actorRole'] as String?,
      transactionReference: json['transactionReference'] as String?,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}

class PaymentDetailResponse {
  final PaymentModel payment;
  final List<PaymentEventModel> events;

  PaymentDetailResponse({
    required this.payment,
    required this.events,
  });

  factory PaymentDetailResponse.fromJson(Map<String, dynamic> json) {
    final eventsList = (json['events'] as List<dynamic>? ?? [])
        .map((e) => PaymentEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaymentDetailResponse(
      payment: PaymentModel.fromJson(json['payment'] as Map<String, dynamic>),
      events: eventsList,
    );
  }
}

