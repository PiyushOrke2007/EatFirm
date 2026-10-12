import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../models/payment_model.dart';
import '../models/invoice_model.dart';
import '../services/payment_invoice_api_service.dart';

/// State provider for Cash On Delivery payments, timeline audit, and invoicing (SRS PAY-1..5).
class PaymentInvoiceProvider extends ChangeNotifier {
  final PaymentInvoiceApiService apiService;

  PaymentModel? _currentPayment;
  List<PaymentEventModel> _paymentEvents = [];
  bool _isLoadingPayment = false;
  String? _paymentError;

  InvoiceDetailModel? _currentInvoice;
  bool _isLoadingInvoice = false;
  String? _invoiceError;

  bool _isCollecting = false;
  String? _collectionError;

  PaymentInvoiceProvider({required this.apiService});

  PaymentModel? get currentPayment => _currentPayment;
  List<PaymentEventModel> get paymentEvents => _paymentEvents;
  bool get isLoadingPayment => _isLoadingPayment;
  String? get paymentError => _paymentError;

  InvoiceDetailModel? get currentInvoice => _currentInvoice;
  bool get isLoadingInvoice => _isLoadingInvoice;
  String? get invoiceError => _invoiceError;

  bool get isCollecting => _isCollecting;
  String? get collectionError => _collectionError;

  /// Loads payment record and timeline for a given order.
  Future<void> fetchPayment(String orderId) async {
    _isLoadingPayment = true;
    _paymentError = null;
    notifyListeners();

    try {
      final res = await apiService.getPaymentByOrderId(orderId);
      _currentPayment = res.payment;
      _paymentEvents = res.events;
    } on ApiException catch (e) {
      _paymentError = e.message;
    } catch (e) {
      _paymentError = 'Failed to load payment details: $e';
    } finally {
      _isLoadingPayment = false;
      notifyListeners();
    }
  }

  /// Records cash collection for Cash On Delivery orders upon delivery handover.
  Future<bool> recordCollection(
    String orderId, {
    String? transactionReference,
    String? note,
  }) async {
    _isCollecting = true;
    _collectionError = null;
    notifyListeners();

    try {
      final updated = await apiService.recordCollection(
        orderId,
        transactionReference: transactionReference,
        note: note,
      );
      _currentPayment = updated;
      // Refresh timeline
      final res = await apiService.getPaymentByOrderId(orderId);
      _currentPayment = res.payment;
      _paymentEvents = res.events;
      return true;
    } on ApiException catch (e) {
      _collectionError = e.message;
      return false;
    } catch (e) {
      _collectionError = 'Failed to record cash collection: $e';
      return false;
    } finally {
      _isCollecting = false;
      notifyListeners();
    }
  }

  /// Loads or generates the immutable tax invoice for a given order.
  Future<void> fetchInvoice(String orderId) async {
    _isLoadingInvoice = true;
    _invoiceError = null;
    notifyListeners();

    try {
      final inv = await apiService.getInvoiceByOrderId(orderId);
      _currentInvoice = inv;
    } on ApiException catch (e) {
      _invoiceError = e.message;
    } catch (e) {
      _invoiceError = 'Failed to load tax invoice: $e';
    } finally {
      _isLoadingInvoice = false;
      notifyListeners();
    }
  }

  /// Clears state when navigating away.
  void clear() {
    _currentPayment = null;
    _paymentEvents = [];
    _paymentError = null;
    _currentInvoice = null;
    _invoiceError = null;
    _collectionError = null;
    notifyListeners();
  }
}

