import '../../../core/network/api_client.dart';
import '../models/order_tracking_model.dart';

/// REST API Service for Order Tracking, Status Timeline and Telemetry (SRS TRACK-1..4).
class TrackingApiService {
  final ApiClient apiClient;

  TrackingApiService({required this.apiClient});

  /// Fetches authoritative tracking timeline and real delivery telemetry (SRS TRACK-01, TRACK-04).
  Future<OrderTrackingModel> getOrderTracking(String orderId) async {
    final response = await apiClient.get('/orders/$orderId/tracking');
    final data = response.data as Map<String, dynamic>;
    return OrderTrackingModel.fromJson(data);
  }

  /// Updates order fulfillment status for operational roles (SRS TRACK-02).
  /// Permitted for RESTAURANT_ADMIN, DELIVERY_PARTNER, and SYSTEM_ADMIN.
  Future<Map<String, dynamic>> updateFulfillmentStatus(
    String orderId,
    String status, {
    String? note,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final response = await apiClient.patch('/orders/$orderId/status', body: body);
    return response.data as Map<String, dynamic>;
  }

  /// Transmits real GPS telemetry location for delivery partner (SRS TRACK-04).
  Future<TrackingLocationModel> recordLocation(
    String orderId, {
    required double latitude,
    required double longitude,
    double? headingDegrees,
    double? speedMetersPerSec,
    double? accuracyMeters,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (headingDegrees != null) body['headingDegrees'] = headingDegrees;
    if (speedMetersPerSec != null) body['speedMetersPerSec'] = speedMetersPerSec;
    if (accuracyMeters != null) body['accuracyMeters'] = accuracyMeters;
    final response = await apiClient.post('/orders/$orderId/tracking/location', body: body);
    return TrackingLocationModel.fromJson(response.data as Map<String, dynamic>);
  }
}
