import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/app_theme.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/cart_order/models/order_model.dart';
import 'package:eatfirm/features/tracking/models/order_tracking_model.dart';
import 'package:eatfirm/features/tracking/services/tracking_api_service.dart';
import 'package:eatfirm/features/tracking/providers/tracking_provider.dart';
import 'package:eatfirm/features/tracking/screens/order_tracking_screen.dart';

class FakeTrackingApiService extends TrackingApiService {
  FakeTrackingApiService() : super(apiClient: ApiClient(baseUrl: 'http://localhost:5000/api/v1'));

  OrderTrackingModel? mockTracking;
  bool shouldThrowError = false;

  @override
  Future<OrderTrackingModel> getOrderTracking(String orderId) async {
    if (shouldThrowError) {
      throw Exception('Network connection timed out');
    }
    if (mockTracking != null) return mockTracking!;
    throw Exception('Tracking not found');
  }

  @override
  Future<Map<String, dynamic>> updateFulfillmentStatus(
    String orderId,
    String status, {
    String? note,
  }) async {
    return {'id': orderId, 'fulfillmentStatus': status};
  }

  @override
  Future<TrackingLocationModel> recordLocation(
    String orderId, {
    required double latitude,
    required double longitude,
    double? headingDegrees,
    double? speedMetersPerSec,
    double? accuracyMeters,
  }) async {
    return TrackingLocationModel(
      id: 'loc-test-1',
      orderId: orderId,
      deliveryPartnerId: 'dp-user-1',
      latitude: latitude,
      longitude: longitude,
      headingDegrees: headingDegrees,
      speedMetersPerSec: speedMetersPerSec,
      accuracyMeters: accuracyMeters,
      recordedAt: DateTime.now(),
    );
  }
}

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  final sampleTracking = OrderTrackingModel(
    orderId: 'ord-test-101',
    publicOrderNumber: 'EF-TEST-101',
    fulfillmentStatus: OrderFulfillmentStatus.outForDelivery,
    paymentStatus: 'PENDING',
    restaurantName: 'Mehra Kitchen Express',
    deliveryAddress: 'Flat 402, Lotus Towers, Bengaluru',
    customerName: 'Aakash Verma',
    customerPhone: '9876543210',
    totalAmount: '450.00',
    isScheduled: false,
    statusTimeline: [
      OrderStatusEventModel(
        id: 'ev-1',
        orderId: 'ord-test-101',
        fromStatus: null,
        toStatus: 'PLACED',
        actorRole: 'CUSTOMER',
        note: 'Order placed by customer',
        createdAt: DateTime.parse('2026-10-12T10:00:00Z'),
      ),
      OrderStatusEventModel(
        id: 'ev-2',
        orderId: 'ord-test-101',
        fromStatus: 'PLACED',
        toStatus: 'CONFIRMED',
        actorRole: 'RESTAURANT_ADMIN',
        note: 'Kitchen accepted',
        createdAt: DateTime.parse('2026-10-12T10:05:00Z'),
      ),
      OrderStatusEventModel(
        id: 'ev-3',
        orderId: 'ord-test-101',
        fromStatus: 'CONFIRMED',
        toStatus: 'PREPARING',
        actorRole: 'RESTAURANT_ADMIN',
        note: 'Cooking started',
        createdAt: DateTime.parse('2026-10-12T10:10:00Z'),
      ),
      OrderStatusEventModel(
        id: 'ev-4',
        orderId: 'ord-test-101',
        fromStatus: 'PREPARING',
        toStatus: 'OUT_FOR_DELIVERY',
        actorRole: 'DELIVERY_PARTNER',
        note: 'Order picked up from kitchen',
        createdAt: DateTime.parse('2026-10-12T10:25:00Z'),
      ),
    ],
    latestLocation: TrackingLocationModel(
      id: 'loc-1',
      orderId: 'ord-test-101',
      deliveryPartnerId: 'dp-1',
      latitude: 12.97500,
      longitude: 77.60500,
      headingDegrees: 90.0,
      speedMetersPerSec: 8.5,
      accuracyMeters: 5.0,
      recordedAt: DateTime.parse('2026-10-12T10:26:00Z'),
    ),
    assignedDeliveryPartner: const TrackingDeliveryPartnerModel(
      id: 'dp-1',
      name: 'Ramesh Rider',
      phone: '9876543211',
    ),
    lastFetchedAt: DateTime.parse('2026-10-12T10:26:30Z'),
  );

  group('Module 07: Tracking Model Unit Tests (SRS TRACK-1..5)', () {
    test('OrderTrackingModel correctly deserializes and identifies states', () {
      final json = {
        'orderId': 'ord-json-1',
        'publicOrderNumber': 'ORD-1234',
        'fulfillmentStatus': 'DELIVERED',
        'paymentStatus': 'PAID',
        'restaurantName': 'Bawarchi Express',
        'deliveryAddress': 'Indiranagar 100ft Rd',
        'customerName': 'Neha Roy',
        'customerPhone': '9898989898',
        'totalAmount': '320.00',
        'isScheduled': false,
        'statusTimeline': [
          {
            'id': 'ev-del',
            'orderId': 'ord-json-1',
            'fromStatus': 'OUT_FOR_DELIVERY',
            'toStatus': 'DELIVERED',
            'actorUserId': 'dp-1',
            'actorRole': 'DELIVERY_PARTNER',
            'note': 'Handed over',
            'createdAt': '2026-10-12T11:00:00Z',
          }
        ],
        'latestLocation': {
          'id': 'loc-1',
          'orderId': 'ord-json-1',
          'deliveryPartnerId': 'dp-1',
          'latitude': 12.9352,
          'longitude': 77.6245,
          'headingDegrees': 180.0,
          'speedMetersPerSec': 0.0,
          'accuracyMeters': 3.0,
          'recordedAt': '2026-10-12T11:00:00Z',
        },
        'assignedDeliveryPartner': {
          'id': 'dp-1',
          'name': 'Suresh Kumar',
          'phone': '9123456789',
        },
      };

      final model = OrderTrackingModel.fromJson(json);
      expect(model.orderId, 'ord-json-1');
      expect(model.publicOrderNumber, 'ORD-1234');
      expect(model.isDelivered, true);
      expect(model.isCancelled, false);
      expect(model.statusTimeline.length, 1);
      expect(model.latestLocation?.latitude, 12.9352);
      expect(model.assignedDeliveryPartner?.name, 'Suresh Kumar');
    });

    test('TrackingLocationModel parses optional telemetry metrics correctly', () {
      final loc = TrackingLocationModel.fromJson({
        'id': 'loc-2',
        'orderId': 'ord-2',
        'deliveryPartnerId': 'dp-2',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'headingDegrees': 45.5,
        'speedMetersPerSec': 12.3,
        'accuracyMeters': 4.0,
        'recordedAt': '2026-10-12T12:00:00Z',
      });

      expect(loc.latitude, 13.0827);
      expect(loc.longitude, 80.2707);
      expect(loc.headingDegrees, 45.5);
      expect(loc.speedMetersPerSec, 12.3);
      expect(loc.accuracyMeters, 4.0);
    });
  });

  group('Module 07: TrackingProvider Unit Tests (TRK-03, TRK-05)', () {
    test('startTracking loads data and initializes state', () async {
      final fakeApi = FakeTrackingApiService();
      fakeApi.mockTracking = sampleTracking;
      final provider = TrackingProvider(apiService: fakeApi);

      await provider.startTracking('ord-test-101');

      expect(provider.isLoading, false);
      expect(provider.tracking, isNotNull);
      expect(provider.tracking?.publicOrderNumber, 'EF-TEST-101');
      expect(provider.isOffline, false);
      expect(provider.errorMessage, isNull);

      provider.dispose();
    });

    test('refreshTracking preserves existing tracking data on network failure (TRK-05)', () async {
      final fakeApi = FakeTrackingApiService();
      fakeApi.mockTracking = sampleTracking;
      final provider = TrackingProvider(apiService: fakeApi);

      await provider.startTracking('ord-test-101');
      expect(provider.tracking, isNotNull);

      // Simulate network disconnection
      fakeApi.shouldThrowError = true;
      await provider.refreshTracking(silent: false);

      // Data is preserved honestly while offline indicator is activated
      expect(provider.tracking, isNotNull);
      expect(provider.isOffline, true);
      expect(provider.errorMessage, contains('Network connection timed out'));

      provider.dispose();
    });
  });

  group('Module 07: OrderTrackingScreen Widget Tests (TRK-01..05)', () {
    testWidgets('Renders timeline, real telemetry, partner details, and back button (TRK-01, TRK-04)', (tester) async {
      final fakeApi = FakeTrackingApiService();
      fakeApi.mockTracking = sampleTracking;
      final provider = TrackingProvider(apiService: fakeApi);

      await tester.pumpWidget(
        buildTestWidget(
          OrderTrackingScreen(
            orderId: 'ord-test-101',
            provider: provider,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify AppBar and back arrow
      expect(find.text('Tracking #EF-TEST-101'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // 2. Verify Status Header Card
      expect(find.text('Out for Delivery'), findsWidgets);
      expect(find.text('OUT_FOR_DELIVERY'), findsOneWidget);

      // 3. Verify Timeline Milestones (TRK-01)
      expect(find.text('Order Progress Timeline'), findsOneWidget);
      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Order Confirmed'), findsOneWidget);
      expect(find.text('Preparing Food'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);

      // 4. Verify Real GPS Telemetry Card (TRK-04)
      expect(find.text('Live Partner Telemetry'), findsOneWidget);
      expect(find.text('REAL GPS ACTIVE'), findsOneWidget);
      expect(find.textContaining('12.97500'), findsOneWidget);
      expect(find.textContaining('77.60500'), findsOneWidget);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);

      // 5. Verify Delivery Partner details
      expect(find.text('Ramesh Rider'), findsOneWidget);
      expect(find.text('9876543211'), findsOneWidget);

      // 6. Verify Navigation buttons
      expect(find.text('View Order Details'), findsOneWidget);
      expect(find.text('Tax Invoice'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Renders offline resilience banner when provider is offline (TRK-05)', (tester) async {
      final fakeApi = FakeTrackingApiService();
      fakeApi.mockTracking = sampleTracking;
      final provider = TrackingProvider(apiService: fakeApi);

      await provider.startTracking('ord-test-101');

      // Trigger network loss
      fakeApi.shouldThrowError = true;
      await provider.refreshTracking();

      await tester.pumpWidget(
        buildTestWidget(
          OrderTrackingScreen(
            orderId: 'ord-test-101',
            provider: provider,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify offline banner is displayed honestly without wiping screen data
      expect(find.textContaining('Updates delayed due to network connectivity'), findsOneWidget);
      expect(find.text('Tracking #EF-TEST-101'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Renders status-based progress when live GPS is absent (TRK-04)', (tester) async {
      final trackingWithoutGps = OrderTrackingModel(
        orderId: 'ord-test-no-gps',
        publicOrderNumber: 'EF-NOGPS-01',
        fulfillmentStatus: OrderFulfillmentStatus.confirmed,
        paymentStatus: 'PENDING',
        restaurantName: 'South Tiffin Center',
        deliveryAddress: 'BTM Layout 2nd Stage',
        customerName: 'Kavitha R',
        customerPhone: '9000000000',
        totalAmount: '180.00',
        isScheduled: false,
        statusTimeline: [
          OrderStatusEventModel(
            id: 'ev-1',
            orderId: 'ord-test-no-gps',
            fromStatus: null,
            toStatus: 'PLACED',
            actorRole: 'CUSTOMER',
            note: 'Order placed',
            createdAt: DateTime.parse('2026-10-12T09:00:00Z'),
          ),
        ],
        latestLocation: null, // No GPS telemetry
        assignedDeliveryPartner: null,
        lastFetchedAt: DateTime.now(),
      );

      final fakeApi = FakeTrackingApiService();
      fakeApi.mockTracking = trackingWithoutGps;
      final provider = TrackingProvider(apiService: fakeApi);

      await tester.pumpWidget(
        buildTestWidget(
          OrderTrackingScreen(
            orderId: 'ord-test-no-gps',
            provider: provider,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TELEMETRY PENDING'), findsOneWidget);
      expect(
        find.textContaining('Live telemetry is broadcast once the delivery partner picks up'),
        findsOneWidget,
      );

      provider.dispose();
    });
  });
}
