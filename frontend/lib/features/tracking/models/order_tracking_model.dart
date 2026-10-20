import '../../cart_order/models/order_model.dart';

/// Real-time GPS Telemetry Model for Delivery Partner location (SRS TRACK-04).
class TrackingLocationModel {
  final String id;
  final String orderId;
  final String deliveryPartnerId;
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final double? speedMetersPerSec;
  final double? accuracyMeters;
  final DateTime recordedAt;

  const TrackingLocationModel({
    required this.id,
    required this.orderId,
    required this.deliveryPartnerId,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedMetersPerSec,
    this.accuracyMeters,
    required this.recordedAt,
  });

  factory TrackingLocationModel.fromJson(Map<String, dynamic> json) {
    return TrackingLocationModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      deliveryPartnerId: json['deliveryPartnerId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      headingDegrees: json['headingDegrees'] != null
          ? (json['headingDegrees'] as num).toDouble()
          : null,
      speedMetersPerSec: json['speedMetersPerSec'] != null
          ? (json['speedMetersPerSec'] as num).toDouble()
          : null,
      accuracyMeters: json['accuracyMeters'] != null
          ? (json['accuracyMeters'] as num).toDouble()
          : null,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'deliveryPartnerId': deliveryPartnerId,
        'latitude': latitude,
        'longitude': longitude,
        'headingDegrees': headingDegrees,
        'speedMetersPerSec': speedMetersPerSec,
        'accuracyMeters': accuracyMeters,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

/// Delivery Partner information associated with order tracking (SRS TRACK-01, TRACK-04).
class TrackingDeliveryPartnerModel {
  final String id;
  final String name;
  final String phone;

  const TrackingDeliveryPartnerModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory TrackingDeliveryPartnerModel.fromJson(Map<String, dynamic> json) {
    return TrackingDeliveryPartnerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };
}

/// Authoritative Order Tracking and Progress Model (SRS TRACK-1..4).
class OrderTrackingModel {
  final String orderId;
  final String publicOrderNumber;
  final OrderFulfillmentStatus fulfillmentStatus;
  final String paymentStatus;
  final String restaurantName;
  final String deliveryAddress;
  final String customerName;
  final String customerPhone;
  final String totalAmount;
  final bool isScheduled;
  final DateTime? scheduledFor;
  final List<OrderStatusEventModel> statusTimeline;
  final TrackingLocationModel? latestLocation;
  final TrackingDeliveryPartnerModel? assignedDeliveryPartner;
  final DateTime lastFetchedAt;

  const OrderTrackingModel({
    required this.orderId,
    required this.publicOrderNumber,
    required this.fulfillmentStatus,
    required this.paymentStatus,
    required this.restaurantName,
    required this.deliveryAddress,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    required this.isScheduled,
    this.scheduledFor,
    required this.statusTimeline,
    this.latestLocation,
    this.assignedDeliveryPartner,
    required this.lastFetchedAt,
  });

  bool get isDelivered => fulfillmentStatus == OrderFulfillmentStatus.delivered;
  bool get isCancelled => fulfillmentStatus == OrderFulfillmentStatus.cancelled;
  bool get isOutForDelivery => fulfillmentStatus == OrderFulfillmentStatus.outForDelivery;

  factory OrderTrackingModel.fromJson(Map<String, dynamic> json) {
    final timelineList = (json['statusTimeline'] as List<dynamic>? ?? [])
        .map((item) => OrderStatusEventModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return OrderTrackingModel(
      orderId: json['orderId'] as String,
      publicOrderNumber: json['publicOrderNumber'] as String? ?? 'ORD',
      fulfillmentStatus: OrderFulfillmentStatus.fromString(
        json['fulfillmentStatus'] as String?,
      ),
      paymentStatus: json['paymentStatus'] as String? ?? 'PENDING',
      restaurantName: json['restaurantName'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      totalAmount: json['totalAmount'] as String? ?? '0.00',
      isScheduled: json['isScheduled'] as bool? ?? false,
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'] as String)
          : null,
      statusTimeline: timelineList,
      latestLocation: json['latestLocation'] != null
          ? TrackingLocationModel.fromJson(
              json['latestLocation'] as Map<String, dynamic>,
            )
          : null,
      assignedDeliveryPartner: json['assignedDeliveryPartner'] != null
          ? TrackingDeliveryPartnerModel.fromJson(
              json['assignedDeliveryPartner'] as Map<String, dynamic>,
            )
          : null,
      lastFetchedAt: DateTime.now(),
    );
  }
}

