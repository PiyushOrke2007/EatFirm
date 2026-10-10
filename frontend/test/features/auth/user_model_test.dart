import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/features/auth/models/user_model.dart';

void main() {
  group('UserModel and UserRole Tests', () {
    test('Parses UserRole from string correctly', () {
      expect(UserRole.fromString('CUSTOMER'), UserRole.customer);
      expect(UserRole.fromString('RESTAURANT_ADMIN'), UserRole.restaurantAdmin);
      expect(UserRole.fromString('DELIVERY_PARTNER'), UserRole.deliveryPartner);
      expect(UserRole.fromString('SYSTEM_ADMIN'), UserRole.systemAdmin);
      expect(UserRole.fromString(null), UserRole.customer);
      expect(UserRole.fromString('unknown'), UserRole.customer);
    });

    test('Converts UserRole to server string and display name', () {
      expect(UserRole.customer.toServerString(), 'CUSTOMER');
      expect(UserRole.restaurantAdmin.toServerString(), 'RESTAURANT_ADMIN');
      expect(UserRole.deliveryPartner.toServerString(), 'DELIVERY_PARTNER');
      expect(UserRole.systemAdmin.toServerString(), 'SYSTEM_ADMIN');

      expect(UserRole.customer.displayName, 'Customer');
      expect(UserRole.restaurantAdmin.displayName, 'Restaurant Partner');
      expect(UserRole.deliveryPartner.displayName, 'Delivery Partner');
      expect(UserRole.systemAdmin.displayName, 'System Administrator');
    });

    test('Serializes and deserializes UserModel from/to JSON', () {
      final json = {
        'id': 'usr-12345',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '9876543210',
        'role': 'CUSTOMER',
        'accountStatus': 'ACTIVE',
        'isVerified': true,
        'termsAcceptedAt': '2026-10-10T12:00:00.000Z',
        'lastLoginAt': '2026-10-10T12:30:00.000Z',
        'createdAt': '2026-10-10T10:00:00.000Z',
        'updatedAt': '2026-10-10T12:30:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'usr-12345');
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@example.com');
      expect(user.phone, '9876543210');
      expect(user.role, UserRole.customer);
      expect(user.accountStatus, 'ACTIVE');
      expect(user.isVerified, true);
      expect(user.termsAcceptedAt, isNotNull);
      expect(user.lastLoginAt, isNotNull);

      final encoded = user.toJson();
      expect(encoded['id'], 'usr-12345');
      expect(encoded['role'], 'CUSTOMER');
      expect(encoded['isVerified'], true);
    });

    test('copyWith creates modified clone', () {
      const original = UserModel(
        id: 'usr-1',
        name: 'Original',
        role: UserRole.customer,
        accountStatus: 'ACTIVE',
        isVerified: false,
      );

      final modified = original.copyWith(name: 'New Name', isVerified: true);

      expect(modified.id, 'usr-1');
      expect(modified.name, 'New Name');
      expect(modified.isVerified, true);
      expect(modified.role, UserRole.customer);
    });
  });
}
