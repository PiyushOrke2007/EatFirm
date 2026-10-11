import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/features/browse/models/browse_filter_model.dart';
import 'package:eatfirm/features/browse/models/search_suggestion_model.dart';
import 'package:eatfirm/features/browse/models/customer_menu_model.dart';
import 'package:eatfirm/features/restaurant/models/restaurant_model.dart';

void main() {
  group('Module 04: Browse & Discovery Models Test Suite', () {
    test('BrowseFilterModel serializes query parameters accurately', () {
      const filter = BrowseFilterModel(
        search: 'Biryani',
        cuisine: 'Hyderabadi',
        minRating: 4.2,
        maxDistanceKm: 7.5,
        maxDeliveryMins: 45,
        priceTier: '₹₹',
        vegOnly: true,
        isOpenOnly: true,
        latitude: 12.9716,
        longitude: 77.5946,
        sortBy: 'rating_desc',
        page: 2,
        limit: 15,
      );

      final params = filter.toQueryParams();
      expect(params['search'], 'Biryani');
      expect(params['cuisine'], 'Hyderabadi');
      expect(params['minRating'], '4.2');
      expect(params['maxDistanceKm'], '7.5');
      expect(params['maxDeliveryMins'], '45');
      expect(params['priceTier'], '₹₹');
      expect(params['vegOnly'], 'true');
      expect(params['isOpenOnly'], 'true');
      expect(params['latitude'], '12.9716');
      expect(params['longitude'], '77.5946');
      expect(params['sortBy'], 'rating_desc');
      expect(params['page'], '2');
      expect(params['limit'], '15');
    });

    test('SearchSuggestionModel parses types and subtext properly', () {
      final json1 = {
        'type': 'restaurant',
        'text': 'Paradise Biryani',
        'subtext': 'Biryani, Mughlai',
        'id': 'rest-123',
      };
      final s1 = SearchSuggestionModel.fromJson(json1);
      expect(s1.type, 'restaurant');
      expect(s1.text, 'Paradise Biryani');
      expect(s1.subtext, 'Biryani, Mughlai');
      expect(s1.id, 'rest-123');

      final json2 = {
        'type': 'dish',
        'text': 'Paneer Tikka',
        'subtext': 'Starters',
      };
      final s2 = SearchSuggestionModel.fromJson(json2);
      expect(s2.type, 'dish');
      expect(s2.text, 'Paneer Tikka');
    });

    test('RestaurantModel correctly parses discovery metrics and handles unrated restaurants', () {
      final jsonRated = {
        'id': 'r-1',
        'ownerId': 'o-1',
        'name': 'Spice Garden',
        'address': 'MG Road, Bengaluru',
        'phone': '9876543210',
        'cuisineType': 'North Indian',
        'foodLicenseNumber': 'FSSAI-123456789012',
        'isOpen': true,
        'latitude': '12.9716',
        'longitude': '77.5946',
        'averageRating': '4.50',
        'ratingCount': 85,
        'estimatedDeliveryMins': 25,
        'priceTier': '₹₹',
        'distanceKm': 2.34,
      };

      final rRated = RestaurantModel.fromJson(jsonRated);
      expect(rRated.averageRating, 4.5);
      expect(rRated.ratingCount, 85);
      expect(rRated.estimatedDeliveryMins, 25);
      expect(rRated.priceTier, '₹₹');
      expect(rRated.distanceKm, 2.34);
      expect(rRated.isOpen, true);

      // Unrated restaurant (New, theme.md compliance)
      final jsonUnrated = {
        'id': 'r-2',
        'ownerId': 'o-2',
        'name': 'New Eatery',
        'address': 'Koramangala',
        'phone': '9876543211',
        'cuisineType': 'South Indian',
        'foodLicenseNumber': 'FSSAI-999999999999',
        'isOpen': true,
        'averageRating': null,
        'ratingCount': 0,
      };

      final rUnrated = RestaurantModel.fromJson(jsonUnrated);
      expect(rUnrated.averageRating, isNull);
      expect(rUnrated.ratingCount, 0);
    });

    test('CustomerMenuResponse parses categorized menu with dishes and veg flags', () {
      final jsonMenu = {
        'restaurant': {
          'id': 'rest-99',
          'ownerId': 'own-99',
          'name': 'The Veg Haven',
          'address': 'Jayanagar',
          'phone': '9988776655',
          'cuisineType': 'Pure Vegetarian',
          'foodLicenseNumber': 'FSSAI-888888888888',
          'isOpen': true,
        },
        'categories': [
          {
            'id': 'cat-1',
            'name': 'Starters',
            'sortOrder': 1,
            'items': [
              {
                'id': 'item-1',
                'restaurantId': 'rest-99',
                'categoryId': 'cat-1',
                'name': 'Crispy Corn',
                'price': '180.00',
                'isVeg': true,
                'isAvailable': true,
                'isSpecialOffer': true,
                'offerPrice': '149.00',
              },
            ],
          },
        ],
        'menuItems': [
          {
            'id': 'item-1',
            'restaurantId': 'rest-99',
            'categoryId': 'cat-1',
            'name': 'Crispy Corn',
            'price': '180.00',
            'isVeg': true,
            'isAvailable': true,
            'isSpecialOffer': true,
            'offerPrice': '149.00',
          },
        ],
      };

      final response = CustomerMenuResponse.fromJson(jsonMenu);
      expect(response.restaurant.name, 'The Veg Haven');
      expect(response.categories.length, 1);
      expect(response.categories[0].name, 'Starters');
      expect(response.categories[0].items.length, 1);

      final dish = response.categories[0].items[0];
      expect(dish.name, 'Crispy Corn');
      expect(dish.isVeg, true);
      expect(dish.isSpecialOffer, true);
      expect(dish.effectivePrice, 149.00);
      expect(dish.parsedPrice, 180.00);
    });
  });
}

