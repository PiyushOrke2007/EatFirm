import '../../../core/network/api_client.dart';
import '../models/payment_model.dart';
import '../models/invoice_model.dart';

/// API Service for Payment Status, Cash Collection, and Invoicing (SRS PAY-1..5).
class PaymentInvoiceApiService {
  final ApiClient apiClient;

  PaymentInvoiceApiService({required this.apiClient});

  /// Retrieves the authoritative payment record and audit timeline for an order (PAY-01, PAY-02).
  Future<PaymentDetailResponse> getPaymentByOrderId(String orderId) async {
    final response = await apiClient.get<dynamic>(
      '/orders/$orderId/payment',
      fromJson: (data) => data,
    );
    return PaymentDetailResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Records cash collection for COD orders upon delivery handover (PAY-02, PAY-03, PAY-05).
  Future<PaymentModel> recordCollection(
    String orderId, {
    String? transactionReference,
    String? note,
  }) async {
    final body = <String, dynamic>{
      if (transactionReference != null && transactionReference.isNotEmpty)
        'transactionReference': transactionReference,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final response = await apiClient.post<dynamic>(
      '/orders/$orderId/payment/collect',
      body: body,
      fromJson: (data) => data,
    );

    final data = response.data as Map<String, dynamic>;
    return PaymentModel.fromJson(data['payment'] as Map<String, dynamic>);
  }

  /// Generates or retrieves an immutable tax invoice for an order (PAY-04, PAY-05).
  Future<InvoiceDetailModel> getInvoiceByOrderId(String orderId) async {
    final response = await apiClient.get<dynamic>(
      '/orders/$orderId/invoice',
      fromJson: (data) => data,
    );
    return InvoiceDetailModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Returns the relative URL for printable invoice HTML document.
  String getPrintableInvoiceUrl(String orderId) {
    return '${apiClient.baseUrl}/orders/$orderId/invoice/print';
  }
}

