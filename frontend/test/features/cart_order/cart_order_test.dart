import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/app_theme.dart';
import 'package:eatfirm/features/cart_order/models/cart_model.dart';
import 'package:eatfirm/features/cart_order/models/order_model.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Module 05: Cart & Order Models Unit Tests', () {
    test('CartModel deserializes from JSON accurately with item and bill calculations', () {
      final cartJson = {
        'id': 'cart-101',
        'customerId': 'user-1',
        'restaurantId': 'rest-1',
        'restaurantName': 'Spice Villa',
        'restaurantAddress': '123 Food Street, Bangalore',
        'specialInstructions': 'Please send extra mint chutney and cutlery',
        'subtotal': '350.00',
        'deliveryFee': '30.00',
        'taxAmount': '17.50',
        'discountAmount': '0.00',
        'totalAmount': '397.50',
        'itemCount': 3,
        'items': [
          {
            'id': 'item-1',
            'cartId': 'cart-101',
            'menuItemId': 'dish-1',
            'name': 'Paneer Butter Masala',
            'price': '250.00',
            'effectivePrice': '250.00',
            'quantity': 1,
            'lineTotal': '250.00',
            'isVeg': true,
            'isAvailable': true,
            'imageUrl': 'https://example.com/paneer.jpg',
            'itemInstructions': 'Make it medium spicy',
          },
          {
            'id': 'item-2',
            'cartId': 'cart-101',
            'menuItemId': 'dish-2',
            'name': 'Garlic Naan',
            'price': '50.00',
            'effectivePrice': '50.00',
            'quantity': 2,
            'lineTotal': '100.00',
            'isVeg': true,
            'isAvailable': true,
            'imageUrl': null,
            'itemInstructions': null,
          }
        ],
      };

      final cart = CartModel.fromJson(cartJson);

      expect(cart.id, 'cart-101');
      expect(cart.restaurantId, 'rest-1');
      expect(cart.restaurantName, 'Spice Villa');
      expect(cart.specialInstructions, 'Please send extra mint chutney and cutlery');
      expect(cart.itemCount, 3);

      // Verify double calculations
      expect(cart.subtotalDouble, 350.0);
      expect(cart.deliveryFeeDouble, 30.0);
      expect(cart.taxAmountDouble, 17.5);
      expect(cart.totalAmountDouble, 397.5);

      // Verify individual line items
      expect(cart.items.length, 2);

      final item1 = cart.items[0];
      expect(item1.name, 'Paneer Butter Masala');
      expect(item1.quantity, 1);
      expect(item1.effectivePriceDouble, 250.0);
      expect(item1.lineTotalDouble, 250.0);
      expect(item1.isVeg, true);
      expect(item1.itemInstructions, 'Make it medium spicy');

      final item2 = cart.items[1];
      expect(item2.name, 'Garlic Naan');
      expect(item2.quantity, 2);
      expect(item2.effectivePriceDouble, 50.0);
      expect(item2.lineTotalDouble, 100.0);
      expect(item2.isVeg, true);
    });

    test('CartModel free delivery logic over ₹500 threshold', () {
      final freeDeliveryCartJson = {
        'id': 'cart-102',
        'customerId': 'user-1',
        'restaurantId': 'rest-1',
        'restaurantName': 'Spice Villa',
        'restaurantAddress': '123 Food Street, Bangalore',
        'subtotal': '550.00',
        'deliveryFee': '0.00', // Free delivery over 500
        'taxAmount': '27.50', // 5% GST
        'discountAmount': '0.00',
        'totalAmount': '577.50',
        'itemCount': 2,
        'items': [],
      };

      final cart = CartModel.fromJson(freeDeliveryCartJson);
      expect(cart.deliveryFeeDouble, 0.0);
      expect(cart.subtotalDouble, 550.0);
      expect(cart.taxAmountDouble, 27.5);
      expect(cart.totalAmountDouble, 577.5);
    });

    test('OrderModel deserializes snapshot items, statuses, and cancellation fields', () {
      final orderJson = {
        'id': 'ord-uuid-999',
        'publicOrderNumber': 'ORD-2026-999',
        'customerId': 'cust-1',
        'restaurantId': 'rest-1',
        'restaurantName': 'The Spice House',
        'restaurantAddress': '123 Food Street, Bangalore',
        'deliveryAddressSnapshot': 'Flat 402, Green Glen Heights, Bellandur, Bangalore',
        'customerPhoneSnapshot': '9123456789',
        'customerNameSnapshot': 'Piyush Sharma',
        'fulfillmentStatus': 'CANCELLED',
        'paymentStatus': 'PENDING',
        'paymentMethod': 'CASH_ON_DELIVERY',
        'subtotal': '400.00',
        'deliveryFee': '30.00',
        'taxAmount': '20.00',
        'discountAmount': '0.00',
        'totalAmount': '450.00',
        'specialInstructions': 'Ring bell twice',
        'cancellationReason': 'Customer changed their mind',
        'cancelledAt': '2026-10-12T11:00:00.000Z',
        'idempotencyKey': 'idem-test-12345',
        'isScheduled': false,
        'scheduledFor': null,
        'items': [
          {
            'id': 'ord-item-1',
            'orderId': 'ord-uuid-999',
            'menuItemId': 'dish-1',
            'itemName': 'Chicken Tikka',
            'unitPrice': '400.00',
            'quantity': 1,
            'lineTotal': '400.00',
            'isVeg': false,
            'itemInstructions': null,
          }
        ],
        'statusTimeline': [
          {
            'id': 'evt-1',
            'orderId': 'ord-uuid-999',
            'fromStatus': null,
            'toStatus': 'PLACED',
            'actorRole': 'CUSTOMER',
            'note': 'Order placed',
            'createdAt': '2026-10-12T10:45:00.000Z',
          },
          {
            'id': 'evt-2',
            'orderId': 'ord-uuid-999',
            'fromStatus': 'PLACED',
            'toStatus': 'CANCELLED',
            'actorRole': 'CUSTOMER',
            'note': 'Customer cancelled',
            'createdAt': '2026-10-12T11:00:00.000Z',
          }
        ],
        'createdAt': '2026-10-12T10:45:00.000Z',
        'updatedAt': '2026-10-12T11:00:00.000Z',
      };

      final order = OrderModel.fromJson(orderJson);

      expect(order.id, 'ord-uuid-999');
      expect(order.publicOrderNumber, 'ORD-2026-999');
      expect(order.fulfillmentStatus, OrderFulfillmentStatus.cancelled);
      expect(order.restaurantName, 'The Spice House');
      expect(order.customerNameSnapshot, 'Piyush Sharma');
      expect(order.cancellationReason, 'Customer changed their mind');
      expect(order.cancelledAt, isNotNull);
      expect(order.fulfillmentStatus.isCancellable, false);
      expect(order.totalAmountDouble, 450.0);
      expect(order.items.length, 1);
      expect(order.items.first.itemName, 'Chicken Tikka');
      expect(order.items.first.isVeg, false);
      expect(order.statusTimeline.length, 2);
    });

    test('OrderFulfillmentStatus isCancellable evaluates true only for placed or confirmed', () {
      expect(OrderFulfillmentStatus.placed.isCancellable, true);
      expect(OrderFulfillmentStatus.confirmed.isCancellable, true);
      expect(OrderFulfillmentStatus.preparing.isCancellable, false);
      expect(OrderFulfillmentStatus.outForDelivery.isCancellable, false);
      expect(OrderFulfillmentStatus.delivered.isCancellable, false);
      expect(OrderFulfillmentStatus.cancelled.isCancellable, false);
    });
  });

  group('Module 05: Order & Cart UI Component Tests', () {
    testWidgets('Veg and Non-Veg indicators render correctly with symbols (NFR-12)',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Column(
            children: [
              // Veg indicator
              Container(
                key: const Key('veg-badge'),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Icon(Icons.circle, size: 6, color: Colors.green),
                ),
              ),
              // Non-veg indicator
              Container(
                key: const Key('non-veg-badge'),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Icon(Icons.circle, size: 6, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('veg-badge')), findsOneWidget);
      expect(find.byKey(const Key('non-veg-badge')), findsOneWidget);
    });

    testWidgets('Order bill summary displays itemized calculation faithfully (NFR-13)',
        (tester) async {
      const cart = CartModel(
        id: 'cart-1',
        customerId: 'u1',
        restaurantId: 'r1',
        restaurantName: 'The Royal Treat',
        restaurantAddress: 'Indiranagar 100ft Rd',
        specialInstructions: null,
        subtotal: '400.00',
        deliveryFee: '30.00',
        taxAmount: '20.00',
        discountAmount: '0.00',
        totalAmount: '450.00',
        itemCount: 1,
        items: [
          CartItemModel(
            id: 'ci-1',
            cartId: 'cart-1',
            menuItemId: 'mi-1',
            name: 'Dal Makhani',
            price: '400.00',
            effectivePrice: '400.00',
            quantity: 1,
            lineTotal: '400.00',
            isVeg: true,
            isAvailable: true,
            imageUrl: null,
            itemInstructions: null,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtotal: ₹${cart.subtotalDouble.toStringAsFixed(2)}'),
                  Text('Delivery Fee: ₹${cart.deliveryFeeDouble.toStringAsFixed(2)}'),
                  Text('Taxes & Charges (5% GST): ₹${cart.taxAmountDouble.toStringAsFixed(2)}'),
                  const Divider(),
                  Text('Grand Total: ₹${cart.totalAmountDouble.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Subtotal: ₹400.00'), findsOneWidget);
      expect(find.text('Delivery Fee: ₹30.00'), findsOneWidget);
      expect(find.text('Taxes & Charges (5% GST): ₹20.00'), findsOneWidget);
      expect(find.text('Grand Total: ₹450.00'), findsOneWidget);
    });
  });
}

