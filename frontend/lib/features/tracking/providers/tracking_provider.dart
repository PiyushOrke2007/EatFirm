import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/order_tracking_model.dart';
import '../services/tracking_api_service.dart';

/// State Management Provider for Order Tracking, Polling and Status Updates (SRS TRACK-1..5).
class TrackingProvider extends ChangeNotifier {
  final TrackingApiService apiService;

  TrackingProvider({required this.apiService});

  OrderTrackingModel? _tracking;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isOffline = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  String? _activeOrderId;

  OrderTrackingModel? get tracking => _tracking;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  String? get activeOrderId => _activeOrderId;

  /// Starts authoritative tracking and initiates 15-second auto-refresh polling (TRK-03, NFR-6).
  Future<void> startTracking(String orderId) async {
    _activeOrderId = orderId;
    _stopPollingTimer();

    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    try {
      _tracking = await apiService.getOrderTracking(orderId);
      _errorMessage = null;
      _isOffline = false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startPollingTimer(orderId);
  }

  /// Refreshes tracking data on demand or during periodic polling cycle (TRK-03, TRK-05).
  Future<void> refreshTracking({bool silent = false}) async {
    final orderId = _activeOrderId;
    if (orderId == null) return;

    if (!silent) {
      _isRefreshing = true;
      notifyListeners();
    }

    try {
      final updated = await apiService.getOrderTracking(orderId);
      _tracking = updated;
      _isOffline = false;
      _errorMessage = null;

      // Automatically halt polling once order reaches terminal state (DELIVERED or CANCELLED)
      if (updated.isDelivered || updated.isCancelled) {
        _stopPollingTimer();
      }
    } catch (e) {
      // Retain existing tracking data and mark offline/delayed update honestly (TRK-05)
      _isOffline = true;
      if (!silent) {
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      }
    } finally {
      if (!silent) {
        _isRefreshing = false;
      }
      notifyListeners();
    }
  }

  /// Transmits status transition for operational roles (TRK-02).
  Future<bool> updateStatus(String status, {String? note}) async {
    final orderId = _activeOrderId;
    if (orderId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await apiService.updateFulfillmentStatus(orderId, status, note: note);
      // Immediately refresh after mutation
      _tracking = await apiService.getOrderTracking(orderId);
      _errorMessage = null;
      _isOffline = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Transmits GPS coordinates for delivery partner (TRK-04).
  Future<bool> recordTelemetryLocation({
    required double latitude,
    required double longitude,
    double? headingDegrees,
    double? speedMetersPerSec,
    double? accuracyMeters,
  }) async {
    final orderId = _activeOrderId;
    if (orderId == null) return false;

    try {
      final loc = await apiService.recordLocation(
        orderId,
        latitude: latitude,
        longitude: longitude,
        headingDegrees: headingDegrees,
        speedMetersPerSec: speedMetersPerSec,
        accuracyMeters: accuracyMeters,
      );

      // Locally update latest location without waiting for next poll
      if (_tracking != null) {
        _tracking = OrderTrackingModel(
          orderId: _tracking!.orderId,
          publicOrderNumber: _tracking!.publicOrderNumber,
          fulfillmentStatus: _tracking!.fulfillmentStatus,
          paymentStatus: _tracking!.paymentStatus,
          restaurantName: _tracking!.restaurantName,
          deliveryAddress: _tracking!.deliveryAddress,
          customerName: _tracking!.customerName,
          customerPhone: _tracking!.customerPhone,
          totalAmount: _tracking!.totalAmount,
          isScheduled: _tracking!.isScheduled,
          scheduledFor: _tracking!.scheduledFor,
          statusTimeline: _tracking!.statusTimeline,
          latestLocation: loc,
          assignedDeliveryPartner: _tracking!.assignedDeliveryPartner,
          lastFetchedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  void _startPollingTimer(String orderId) {
    // If order is already completed, do not poll
    if (_tracking != null && (_tracking!.isDelivered || _tracking!.isCancelled)) {
      return;
    }

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshTracking(silent: true);
    });
  }

  void _stopPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _stopPollingTimer();
    super.dispose();
  }
}

