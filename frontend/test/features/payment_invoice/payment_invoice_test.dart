import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/app_theme.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/payment_invoice/models/payment_model.dart';
import 'package:eatfirm/features/payment_invoice/models/invoice_model.dart';
import 'package:eatfirm/features/payment_invoice/services/payment_invoice_api_service.dart';
import 'package:eatfirm/features/payment_invoice/providers/payment_invoice_provider.dart';
import 'package:eatfirm/features/payment_invoice/screens/invoice_detail_screen.dart';

class FakePaymentInvoiceApiService extends PaymentInvoiceApiService {
  FakePaymentInvoiceApiService() : super(apiClient: ApiClient(baseUrl: 'http://localhost:5000/api/v1'));

  InvoiceDetailModel? mockInvoice;
  PaymentDetailResponse? mockPayment;

  @override
  Future<InvoiceDetailModel> getInvoiceByOrderId(String orderId) async {
    if (mockInvoice != null) return mockInvoice!;
    throw Exception('Invoice not found');
  }

  @override
  Future<PaymentDetailResponse> getPaymentByOrderId(String orderId) async {
    if (mockPayment != null) return mockPayment!;
    throw Exception('Payment not found');
  }

  @override
  Future<PaymentModel> recordCollection(
    String orderId, {
    String? transactionReference,
    String? note,
  }) async {
    return PaymentModel(
      id: 'pay-123',
      orderId: orderId,
      paymentMethod: 'CASH_ON_DELIVERY',
      paymentStatus: 'PAID',
      amount: '550.00',
      currency: 'INR',
      collectedAt: DateTime.now(),
      collectedByUserId: 'dp-user-1',
      transactionReference: transactionReference ?? 'COD-TEST-REF',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Module 06: Payment & Invoice Model Unit Tests (SRS PAY-01..05)', () {
    test('PaymentModel deserializes correctly and reports state properties', () {
      final json = {
        'id': 'pay-001',
        'orderId': 'order-101',
        'paymentMethod': 'CASH_ON_DELIVERY',
        'paymentStatus': 'PENDING',
        'amount': '345.50',
        'currency': 'INR',
        'collectedAt': null,
        'collectedByUserId': null,
        'transactionReference': null,
        'createdAt': '2026-10-12T10:00:00Z',
        'updatedAt': '2026-10-12T10:00:00Z',
      };

      final payment = PaymentModel.fromJson(json);
      expect(payment.id, 'pay-001');
      expect(payment.orderId, 'order-101');
      expect(payment.paymentMethod, 'CASH_ON_DELIVERY');
      expect(payment.paymentStatus, 'PENDING');
      expect(payment.isPending, true);
      expect(payment.isPaid, false);
      expect(payment.isFailed, false);
      expect(payment.amount, '345.50');
      expect(payment.currency, 'INR');
      expect(payment.collectedAt, isNull);
    });

    test('PaymentEventModel deserializes correctly for audit timeline', () {
      final json = {
        'id': 'event-001',
        'paymentId': 'pay-001',
        'fromStatus': 'PENDING',
        'toStatus': 'PAID',
        'actorUserId': 'user-dp-1',
        'actorRole': 'DELIVERY_PARTNER',
        'transactionReference': 'COD-REC-9988',
        'note': 'Cash collected at customer doorstep',
        'createdAt': '2026-10-12T10:45:00Z',
      };

      final event = PaymentEventModel.fromJson(json);
      expect(event.id, 'event-001');
      expect(event.fromStatus, 'PENDING');
      expect(event.toStatus, 'PAID');
      expect(event.actorRole, 'DELIVERY_PARTNER');
      expect(event.transactionReference, 'COD-REC-9988');
      expect(event.note, 'Cash collected at customer doorstep');
    });

    test('InvoiceDetailModel deserializes complete tax invoice and line items snapshot', () {
      final json = {
        'invoice': {
          'id': 'inv-001',
          'orderId': 'order-101',
          'invoiceNumber': 'INV-2026-000042',
          'customerId': 'cust-1',
          'restaurantId': 'rest-1',
          'issuedAt': '2026-10-12T10:00:00Z',
          'subtotal': '500.00',
          'deliveryFee': '30.00',
          'taxAmount': '25.00',
          'discountAmount': '0.00',
          'totalAmount': '555.00',
          'currency': 'INR',
          'paymentMethod': 'CASH_ON_DELIVERY',
          'paymentStatus': 'PAID',
          'recipientName': 'Rahul Sharma',
          'recipientPhone': '9876543210',
          'deliveryAddress': 'Flat 201, Green Acres, Indiranagar, Bangalore',
          'createdAt': '2026-10-12T10:00:00Z',
          'updatedAt': '2026-10-12T10:00:00Z',
        },
        'order': {
          'id': 'order-101',
          'publicOrderNumber': 'ORD-20261012-12345',
          'fulfillmentStatus': 'DELIVERED',
        },
        'restaurant': {
          'id': 'rest-1',
          'name': 'Punjabi Rasoi',
          'address': '100 Feet Road, Indiranagar',
          'phone': '080-25252525',
          'cuisineType': 'North Indian',
          'foodLicenseNumber': 'FSSAI-11223344556677',
        },
        'customer': {
          'name': 'Rahul Sharma',
          'phone': '9876543210',
          'deliveryAddress': 'Flat 201, Green Acres, Indiranagar, Bangalore',
        },
        'items': [
          {
            'id': 'item-1',
            'name': 'Butter Chicken',
            'description': 'Rich boneless chicken in creamy tomato gravy',
            'unitPrice': '350.00',
            'isVeg': false,
            'quantity': 1,
            'lineTotal': '350.00',
            'itemInstructions': 'Boneless only',
          },
          {
            'id': 'item-2',
            'name': 'Butter Naan',
            'description': 'Crisp clay-oven flatbread',
            'unitPrice': '50.00',
            'isVeg': true,
            'quantity': 3,
            'lineTotal': '150.00',
            'itemInstructions': null,
          }
        ],
        'breakdown': {
          'subtotal': '500.00',
          'deliveryFee': '30.00',
          'taxAmount': '25.00',
          'discountAmount': '0.00',
          'totalAmount': '555.00',
          'currency': 'INR',
        },
        'payment': {
          'method': 'CASH_ON_DELIVERY',
          'status': 'PAID',
          'collectedAt': '2026-10-12T10:30:00Z',
          'transactionReference': 'COD-REC-001',
        },
      };

      final detail = InvoiceDetailModel.fromJson(json);
      expect(detail.invoice.invoiceNumber, 'INV-2026-000042');
      expect(detail.invoice.totalAmount, '555.00');
      expect(detail.restaurant['foodLicenseNumber'], 'FSSAI-11223344556677');
      expect(detail.restaurant['name'], 'Punjabi Rasoi');
      expect(detail.items.length, 2);
      expect(detail.items[0].name, 'Butter Chicken');
      expect(detail.items[0].isVeg, false);
      expect(detail.items[1].name, 'Butter Naan');
      expect(detail.items[1].isVeg, true);
      expect(detail.items[1].quantity, 3);
      expect(detail.payment['status'], 'PAID');
    });
  });

  group('Module 06: InvoiceDetailScreen Widget Tests (SRS PAY-04)', () {
    testWidgets('Renders official tax invoice with FSSAI, line items, and payment status', (tester) async {
      final fakeApi = FakePaymentInvoiceApiService();
      fakeApi.mockInvoice = InvoiceDetailModel.fromJson({
        'invoice': {
          'id': 'inv-001',
          'orderId': 'order-101',
          'invoiceNumber': 'INV-2026-000123',
          'customerId': 'cust-1',
          'restaurantId': 'rest-1',
          'issuedAt': '2026-10-12T10:00:00Z',
          'subtotal': '300.00',
          'deliveryFee': '30.00',
          'taxAmount': '15.00',
          'discountAmount': '0.00',
          'totalAmount': '345.00',
          'currency': 'INR',
          'paymentMethod': 'CASH_ON_DELIVERY',
          'paymentStatus': 'PAID',
          'recipientName': 'Suresh Kumar',
          'recipientPhone': '9876543210',
          'deliveryAddress': 'House 42, Sector 15, Gurugram',
          'createdAt': '2026-10-12T10:00:00Z',
          'updatedAt': '2026-10-12T10:00:00Z',
        },
        'order': {
          'id': 'order-101',
          'publicOrderNumber': 'ORD-20261012-88776',
          'fulfillmentStatus': 'DELIVERED',
        },
        'restaurant': {
          'id': 'rest-1',
          'name': 'Dhaba Express',
          'address': 'Main Market, Sector 15',
          'phone': '9988776655',
          'cuisineType': 'North Indian',
          'foodLicenseNumber': 'FSSAI-998877665544',
        },
        'customer': {
          'name': 'Suresh Kumar',
          'phone': '9876543210',
          'deliveryAddress': 'House 42, Sector 15, Gurugram',
        },
        'items': [
          {
            'id': 'item-1',
            'name': 'Dal Tadka',
            'description': 'Yellow lentils tempered with cumin and garlic',
            'unitPrice': '150.00',
            'isVeg': true,
            'quantity': 2,
            'lineTotal': '300.00',
            'itemInstructions': null,
          }
        ],
        'breakdown': {
          'subtotal': '300.00',
          'deliveryFee': '30.00',
          'taxAmount': '15.00',
          'discountAmount': '0.00',
          'totalAmount': '345.00',
          'currency': 'INR',
        },
        'payment': {
          'method': 'CASH_ON_DELIVERY',
          'status': 'PAID',
          'collectedAt': '2026-10-12T10:30:00Z',
          'transactionReference': 'COD-REC-123',
        },
      });

      final provider = PaymentInvoiceProvider(apiService: fakeApi);

      await tester.pumpWidget(
        buildTestWidget(
          InvoiceDetailScreen(
            orderId: 'order-101',
            provider: provider,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Brand
      expect(find.text('EatFirm'), findsOneWidget);
      expect(find.text('Tax Invoice'), findsOneWidget);
      expect(find.text('INV-2026-000123'), findsOneWidget);

      // Verify FSSAI & Restaurant
      expect(find.text('Dhaba Express'), findsOneWidget);
      expect(find.text('FSSAI: FSSAI-998877665544'), findsOneWidget);

      // Verify Customer
      expect(find.text('Suresh Kumar'), findsOneWidget);

      // Verify Items
      expect(find.text('Dal Tadka'), findsOneWidget);

      // Verify Total & Status
      expect(find.text('₹345.00'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('Payment Collected via Cash on Delivery'), findsOneWidget);
    });
  });
}

