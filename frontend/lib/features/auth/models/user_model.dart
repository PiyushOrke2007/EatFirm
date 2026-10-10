enum UserRole {
  customer,
  restaurantAdmin,
  deliveryPartner,
  systemAdmin;

  static UserRole fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'RESTAURANT_ADMIN':
        return UserRole.restaurantAdmin;
      case 'DELIVERY_PARTNER':
        return UserRole.deliveryPartner;
      case 'SYSTEM_ADMIN':
        return UserRole.systemAdmin;
      case 'CUSTOMER':
      default:
        return UserRole.customer;
    }
  }

  String toServerString() {
    switch (this) {
      case UserRole.restaurantAdmin:
        return 'RESTAURANT_ADMIN';
      case UserRole.deliveryPartner:
        return 'DELIVERY_PARTNER';
      case UserRole.systemAdmin:
        return 'SYSTEM_ADMIN';
      case UserRole.customer:
        return 'CUSTOMER';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurantAdmin:
        return 'Restaurant Partner';
      case UserRole.deliveryPartner:
        return 'Delivery Partner';
      case UserRole.systemAdmin:
        return 'System Administrator';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final String accountStatus;
  final bool isVerified;
  final DateTime? termsAcceptedAt;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    required this.accountStatus,
    required this.isVerified,
    this.termsAcceptedAt,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      accountStatus: json['accountStatus'] as String? ?? 'ACTIVE',
      isVerified: json['isVerified'] == true,
      termsAcceptedAt: json['termsAcceptedAt'] != null
          ? DateTime.tryParse(json['termsAcceptedAt'].toString())
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toServerString(),
      'accountStatus': accountStatus,
      'isVerified': isVerified,
      'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? accountStatus,
    bool? isVerified,
    DateTime? termsAcceptedAt,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      isVerified: isVerified ?? this.isVerified,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

