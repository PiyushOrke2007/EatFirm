import 'operating_hours_model.dart';

enum RestaurantApprovalStatus {
  pendingApproval('PENDING_APPROVAL', 'Pending Approval'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected');

  final String value;
  final String label;

  const RestaurantApprovalStatus(this.value, this.label);

  static RestaurantApprovalStatus fromString(String? val) {
    switch (val) {
      case 'APPROVED':
        return RestaurantApprovalStatus.approved;
      case 'REJECTED':
        return RestaurantApprovalStatus.rejected;
      case 'PENDING_APPROVAL':
      default:
        return RestaurantApprovalStatus.pendingApproval;
    }
  }
}

/// Represents the authoritative Restaurant Profile (SRS REST-1, REST-2, Section 6).
class RestaurantModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String address;
  final String phone;
  final String cuisineType;
  final String foodLicenseNumber;
  final String? imageUrl;
  final RestaurantApprovalStatus approvalStatus;
  final String? rejectionReason;
  final bool isOpen;
  final double? latitude;
  final double? longitude;
  final double? averageRating;
  final int ratingCount;
  final int estimatedDeliveryMins;
  final String priceTier;
  final double? distanceKm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OperatingHoursModel> operatingHours;

  const RestaurantModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.address,
    required this.phone,
    required this.cuisineType,
    required this.foodLicenseNumber,
    this.imageUrl,
    required this.approvalStatus,
    this.rejectionReason,
    required this.isOpen,
    this.latitude,
    this.longitude,
    this.averageRating,
    this.ratingCount = 0,
    this.estimatedDeliveryMins = 30,
    this.priceTier = '₹₹',
    this.distanceKm,
    required this.createdAt,
    required this.updatedAt,
    this.operatingHours = const [],
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? json['owner_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      address: (json['address'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      cuisineType:
          (json['cuisineType'] ?? json['cuisine_type'] ?? '').toString(),
      foodLicenseNumber:
          (json['foodLicenseNumber'] ?? json['food_license_number'] ?? '')
              .toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      approvalStatus: RestaurantApprovalStatus.fromString(
        (json['approvalStatus'] ?? json['approval_status'])?.toString(),
      ),
      rejectionReason:
          (json['rejectionReason'] ?? json['rejection_reason'])?.toString(),
      isOpen: json['isOpen'] as bool? ?? json['is_open'] as bool? ?? true,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      averageRating: json['averageRating'] != null
          ? double.tryParse(json['averageRating'].toString())
          : (json['average_rating'] != null
              ? double.tryParse(json['average_rating'].toString())
              : null),
      ratingCount: int.tryParse(
            (json['ratingCount'] ?? json['rating_count'] ?? 0).toString(),
          ) ??
          0,
      estimatedDeliveryMins: int.tryParse(
            (json['estimatedDeliveryMins'] ??
                    json['estimated_delivery_mins'] ??
                    30)
                .toString(),
          ) ??
          30,
      priceTier:
          (json['priceTier'] ?? json['price_tier'] ?? '₹₹').toString(),
      distanceKm: json['distanceKm'] != null
          ? double.tryParse(json['distanceKm'].toString())
          : (json['distance_km'] != null
              ? double.tryParse(json['distance_km'].toString())
              : null),
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updatedAt']?.toString() ??
                json['updated_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      operatingHours: (json['operatingHours'] ?? json['operating_hours']) is List
          ? ((json['operatingHours'] ?? json['operating_hours']) as List)
              .map(
                (h) => OperatingHoursModel.fromJson(
                  Map<String, dynamic>.from(h as Map),
                ),
              )
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'cuisineType': cuisineType,
      'foodLicenseNumber': foodLicenseNumber,
      'imageUrl': imageUrl,
      'approvalStatus': approvalStatus.value,
      'rejectionReason': rejectionReason,
      'isOpen': isOpen,
      'latitude': latitude,
      'longitude': longitude,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'estimatedDeliveryMins': estimatedDeliveryMins,
      'priceTier': priceTier,
      'distanceKm': distanceKm,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'operatingHours': operatingHours.map((h) => h.toJson()).toList(),
    };
  }

  RestaurantModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? address,
    String? phone,
    String? cuisineType,
    String? foodLicenseNumber,
    String? imageUrl,
    RestaurantApprovalStatus? approvalStatus,
    String? rejectionReason,
    bool? isOpen,
    double? latitude,
    double? longitude,
    double? averageRating,
    int? ratingCount,
    int? estimatedDeliveryMins,
    String? priceTier,
    double? distanceKm,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OperatingHoursModel>? operatingHours,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      cuisineType: cuisineType ?? this.cuisineType,
      foodLicenseNumber: foodLicenseNumber ?? this.foodLicenseNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isOpen: isOpen ?? this.isOpen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      estimatedDeliveryMins:
          estimatedDeliveryMins ?? this.estimatedDeliveryMins,
      priceTier: priceTier ?? this.priceTier,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      operatingHours: operatingHours ?? this.operatingHours,
    );
  }
}
