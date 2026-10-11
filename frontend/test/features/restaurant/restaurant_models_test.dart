import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/features/restaurant/models/restaurant_model.dart';
import 'package:eatfirm/features/restaurant/models/menu_category_model.dart';
import 'package:eatfirm/features/restaurant/models/menu_item_model.dart';
import 'package:eatfirm/features/restaurant/models/operating_hours_model.dart';

void main() {
  group('Restaurant Models Tests (SRS REST-1 to REST-6)', () {
    test('RestaurantModel parses JSON with approval statuses correctly', () {
      final jsonPending = {
        'id': 'rest-123',
        'ownerId': 'owner-456',
        'name': 'Biryani Palace',
        'description': 'Authentic Hyderabadi Biryani',
        'cuisineType': 'Hyderabadi',
        'foodLicenseNumber': 'FSSAI-12345678901234',
        'address': '123 Food Street, Hyderabad',
        'phone': '9876543210',
        'imageUrl': 'https://eatfirm.com/img.jpg',
        'isOpen': true,
        'approvalStatus': 'PENDING_APPROVAL',
        'rejectionReason': null,
        'createdAt': '2026-03-30T10:00:00Z',
        'updatedAt': '2026-03-30T10:00:00Z',
      };

      final rest = RestaurantModel.fromJson(jsonPending);
      expect(rest.id, 'rest-123');
      expect(rest.name, 'Biryani Palace');
      expect(rest.foodLicenseNumber, 'FSSAI-12345678901234');
      expect(rest.approvalStatus, RestaurantApprovalStatus.pendingApproval);
      expect(rest.isOpen, isTrue);

      final jsonRejected = Map<String, dynamic>.from(jsonPending)
        ..['approvalStatus'] = 'REJECTED'
        ..['rejectionReason'] = 'Invalid FSSAI food license number';
      final restRejected = RestaurantModel.fromJson(jsonRejected);
      expect(restRejected.approvalStatus, RestaurantApprovalStatus.rejected);
      expect(restRejected.rejectionReason, 'Invalid FSSAI food license number');
    });

    test('MenuCategoryModel parses JSON and converts correctly', () {
      final json = {
        'id': 'cat-1',
        'restaurantId': 'rest-123',
        'name': 'Main Course',
        'sortOrder': 1,
        'isActive': true,
        'itemCount': 5,
        'createdAt': '2026-03-30T10:00:00Z',
        'updatedAt': '2026-03-30T10:00:00Z',
      };

      final cat = MenuCategoryModel.fromJson(json);
      expect(cat.id, 'cat-1');
      expect(cat.name, 'Main Course');
      expect(cat.sortOrder, 1);
      expect(cat.isActive, isTrue);
      expect(cat.itemCount, 5);
    });

    test('MenuItemModel calculates effective price and special offer savings', () {
      final json = {
        'id': 'item-1',
        'restaurantId': 'rest-123',
        'categoryId': 'cat-1',
        'categoryName': 'Biryani',
        'name': 'Chicken Dum Biryani',
        'description': 'Fragrant basmati rice cooked with succulent chicken pieces',
        'price': '350.00',
        'isVeg': false,
        'isAvailable': true,
        'availableFrom': '11:00',
        'availableUntil': '23:00',
        'isSpecialOffer': true,
        'offerPrice': '299.00',
        'imageUrl': 'https://eatfirm.com/biryani.jpg',
        'createdAt': '2026-03-30T10:00:00Z',
        'updatedAt': '2026-03-30T10:00:00Z',
      };

      final item = MenuItemModel.fromJson(json);
      expect(item.id, 'item-1');
      expect(item.name, 'Chicken Dum Biryani');
      expect(item.parsedPrice, 350.0);
      expect(item.isVeg, isFalse);
      expect(item.isSpecialOffer, isTrue);
      expect(item.parsedOfferPrice, 299.0);
      expect(item.effectivePrice, 299.0);
      expect(item.availableFrom, '11:00');
      expect(item.availableUntil, '23:00');
    });

    test('OperatingHoursModel parses days and formatted ranges', () {
      const openDay = OperatingHoursModel(
        dayOfWeek: 'MONDAY',
        openTime: '09:00',
        closeTime: '22:00',
        isClosed: false,
      );
      expect(openDay.displayDayName, 'Monday');
      expect(openDay.formattedTime, '09:00 - 22:00');

      const closedDay = OperatingHoursModel(
        dayOfWeek: 'SUNDAY',
        openTime: '00:00',
        closeTime: '00:00',
        isClosed: true,
      );
      expect(closedDay.displayDayName, 'Sunday');
      expect(closedDay.formattedTime, 'Closed');
    });
  });
}

