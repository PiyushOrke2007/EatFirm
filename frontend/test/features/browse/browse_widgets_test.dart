import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/app_theme.dart';
import 'package:eatfirm/features/browse/widgets/restaurant_card.dart';
import 'package:eatfirm/features/browse/widgets/restaurant_compare_sheet.dart';
import 'package:eatfirm/features/restaurant/models/restaurant_model.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  final testRestaurant = RestaurantModel(
    id: 'rest-1',
    ownerId: 'owner-1',
    name: 'Tandoori Flames',
    address: 'Indiranagar 100ft Road',
    phone: '9876543210',
    cuisineType: 'North Indian',
    foodLicenseNumber: 'FSSAI-123456789012',
    approvalStatus: RestaurantApprovalStatus.approved,
    isOpen: true,
    latitude: 12.9716,
    longitude: 77.5946,
    averageRating: 4.6,
    ratingCount: 120,
    estimatedDeliveryMins: 25,
    priceTier: '₹₹',
    distanceKm: 1.8,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Module 04: RestaurantCard Widget Tests', () {
    testWidgets('Displays restaurant name, cuisine, rating, and delivery time',
        (tester) async {
      bool tapped = false;
      bool compareToggled = false;

      await tester.pumpWidget(
        buildTestWidget(
          RestaurantCard(
            restaurant: testRestaurant,
            onTap: () => tapped = true,
            isComparing: false,
            onToggleCompare: () => compareToggled = true,
          ),
        ),
      );

      // Verify essential content per BROWSE-1 and theme.md
      expect(find.text('Tandoori Flames'), findsOneWidget);
      expect(find.text('North Indian • ₹₹'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('(120)'), findsOneWidget);
      expect(find.text('25 mins'), findsOneWidget);
      expect(find.text('1.8 km'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Tandoori Flames'));
      expect(tapped, isTrue);

      // Toggle compare
      await tester.tap(find.text('Compare'));
      expect(compareToggled, isTrue);
    });

    testWidgets('Unrated restaurant displays NEW badge without fake rating',
        (tester) async {
      final unratedRestaurant = testRestaurant.copyWith(
        averageRating: null,
        ratingCount: 0,
      );

      await tester.pumpWidget(
        buildTestWidget(
          RestaurantCard(
            restaurant: unratedRestaurant,
            onTap: () {},
            isComparing: false,
            onToggleCompare: () {},
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('4.6'), findsNothing);
    });
  });

  group('Module 04: RestaurantCompareSheet Widget Tests (BROWSE-4)', () {
    testWidgets('Displays side-by-side comparison and selects View Menu',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final restaurant2 = testRestaurant.copyWith(
        id: 'rest-2',
        name: 'Dosa Camp',
        cuisineType: 'South Indian',
        averageRating: 4.2,
        estimatedDeliveryMins: 15,
        priceTier: '₹',
        distanceKm: 0.9,
      );

      RestaurantModel? selected;

      await tester.pumpWidget(
        buildTestWidget(
          RestaurantCompareSheet(
            restaurants: [testRestaurant, restaurant2],
            onSelectRestaurant: (r) => selected = r,
            onRemoveRestaurant: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      expect(find.text('Compare Restaurants'), findsOneWidget);
      expect(find.text('Comparing 2 of 3 restaurants'), findsOneWidget);
      expect(find.text('Tandoori Flames'), findsOneWidget);
      expect(find.text('Dosa Camp'), findsOneWidget);
      expect(find.text('North Indian'), findsOneWidget);
      expect(find.text('South Indian'), findsOneWidget);
      expect(find.text('View Menu'), findsNWidgets(2));

      // Tap View Menu on first restaurant
      await tester.tap(find.text('View Menu').first);
      expect(selected?.id, 'rest-1');
    });

    testWidgets('Clears comparison shelf via Clear All button',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool cleared = false;

      await tester.pumpWidget(
        buildTestWidget(
          RestaurantCompareSheet(
            restaurants: [testRestaurant],
            onSelectRestaurant: (_) {},
            onRemoveRestaurant: (_) {},
            onClearAll: () => cleared = true,
          ),
        ),
      );

      await tester.tap(find.text('Clear All'));
      expect(cleared, isTrue);
    });
  });
}
