import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/features/restaurant/models/restaurant_model.dart';
import 'package:eatfirm/features/restaurant/screens/restaurant_dashboard_screen.dart';
import 'package:eatfirm/features/restaurant/services/restaurant_api_service.dart';

class FakeRestaurantApiService extends Fake implements RestaurantApiService {
  final RestaurantModel? restaurant;

  FakeRestaurantApiService({this.restaurant});

  @override
  Future<RestaurantModel?> getMyRestaurant() async {
    return restaurant;
  }
}

void main() {
  group('RestaurantDashboardScreen Widget Tests', () {
    testWidgets('Displays onboarding prompt when no restaurant registered',
        (tester) async {
      final fakeService = FakeRestaurantApiService(restaurant: null);

      await tester.pumpWidget(
        MaterialApp(
          home: RestaurantDashboardScreen(restaurantService: fakeService),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state showing onboard button
      expect(find.text('No Restaurant Registered'), findsOneWidget);
      expect(find.text('Register Restaurant'), findsOneWidget);
    });

    testWidgets('Displays restaurant profile and status banner when loaded',
        (tester) async {
      final restaurant = RestaurantModel(
        id: 'rest-1',
        ownerId: 'owner-1',
        name: 'The Spice Grill',
        description: 'Authentic Indian Food',
        address: 'MG Road, Bangalore',
        phone: '9876543210',
        cuisineType: 'North Indian',
        foodLicenseNumber: 'FSSAI-999888777666',
        approvalStatus: RestaurantApprovalStatus.approved,
        isOpen: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fakeService = FakeRestaurantApiService(restaurant: restaurant);

      await tester.pumpWidget(
        MaterialApp(
          home: RestaurantDashboardScreen(restaurantService: fakeService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('The Spice Grill'), findsOneWidget);
      expect(find.text('North Indian'), findsOneWidget);
      expect(find.text('FSSAI-999888777666'), findsOneWidget);
      expect(find.textContaining('Verified Partner'), findsOneWidget);
      expect(find.text('Accepting Orders'), findsOneWidget);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Operating Hours'), findsOneWidget);
    });
  });
}
