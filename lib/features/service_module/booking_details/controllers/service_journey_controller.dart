import 'dart:async';

import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:get/get.dart';

/// A service booking from the customer's side: place it, follow it, cancel it, rate it.
/// While the details screen is open the booking is refreshed every [pollEvery].
class ServiceJourneyController extends GetxController implements GetxService {
  final ApiClient apiClient;
  ServiceJourneyController({required this.apiClient});

  static const Duration pollEvery = Duration(seconds: 15);
  static const List<String> active = ['pending', 'accepted', 'confirmed', 'ongoing'];

  Map<String, dynamic>? booking;
  bool loading = false;
  bool busy = false;
  String? error;
  Timer? _timer;
  int? _following;

  int? get bookingId => booking?['id'] is int ? booking!['id'] : int.tryParse('${booking?['id']}');
  String get status => booking?['booking_status']?.toString() ?? 'pending';
  bool get canCancel => booking?['can_cancel'] == true;
  bool get canRate => status == 'completed' && booking?['is_reviewed'] != true;

  /// Places a booking and returns its id, or null with [error] set.
  Future<int?> place({
    required int serviceId,
    required int quantity,
    required String address,
    required double lat,
    required double lng,
    DateTime? scheduleAt,
  }) async {
    if (busy) return null;
    busy = true;
    error = null;
    update();
    final response = await apiClient.postData(AppConstants.servicePlaceBookingUri, {
      'buy_now': 1,
      'booking_type': 'regular',
      'payment_method': 'cash_after_service',
      'service_id': serviceId,
      'quantity': quantity,
      'scheduled': scheduleAt != null ? 1 : 0,
      if (scheduleAt != null) 'schedule_at': scheduleAt.toIso8601String(),
      'service_location': {'address': address, 'lat': lat, 'lng': lng},
      // The same tap retried after a timeout must not book twice.
      'client_request_id': _requestId(serviceId, quantity, address, scheduleAt),
    }, handleError: false);
    busy = false;
    int? id;
    if (ApiClient.isSuccessCode(response.statusCode)) {
      final data = ResponseParser.payloadOf(response.body);
      final dynamic raw = data is Map ? (data['id'] ?? (data['booking'] is Map ? data['booking']['id'] : null)) : null;
      id = raw is int ? raw : int.tryParse('$raw');
      if (id == null) error = 'Booked, but the booking number was not returned.';
    } else {
      error = messageOf(response, 'Could not book this service.');
    }
    update();
    return id;
  }

  Future<void> follow(int id) async {
    _following = id;
    _timer?.cancel();
    if (bookingId != id) booking = null;
    await refresh(showLoading: booking == null);
    _timer = Timer.periodic(pollEvery, (_) {
      if (active.contains(status)) refresh();
    });
  }

  void stopFollowing() {
    _timer?.cancel();
    _timer = null;
    _following = null;
  }

  Future<void> refresh({bool showLoading = false}) async {
    final id = _following;
    if (id == null) return;
    if (showLoading) {
      loading = true;
      update();
    }
    final response = await apiClient.getData('${AppConstants.serviceBookingDetailsUri}$id', handleError: false);
    if (_following != id) return;
    final data = ResponseParser.payloadOf(response.body);
    if (ApiClient.isSuccessCode(response.statusCode) && data is Map) {
      booking = Map<String, dynamic>.from(data);
      error = null;
    } else if (booking == null) {
      error = messageOf(response, 'Could not load this booking.');
    }
    loading = false;
    update();
  }

  Future<bool> cancel(String? reason) async {
    final id = bookingId;
    if (id == null || busy) return false;
    busy = true;
    update();
    final response = await apiClient.postData(AppConstants.serviceBookingCancelUri, {
      'id': id,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    }, handleError: false);
    final ok = ApiClient.isSuccessCode(response.statusCode);
    final message = ok ? null : messageOf(response, 'This booking can no longer be cancelled.');
    await refresh();
    busy = false;
    error = message;
    update();
    return ok;
  }

  Future<bool> rate(int rating, String comment) async {
    final id = bookingId;
    if (id == null || busy) return false;
    busy = true;
    error = null;
    update();
    final response = await apiClient.postData(AppConstants.serviceReviewSubmitUri, {
      'booking_id': id,
      'service_id': booking?['service_id'] ?? (booking?['details'] is List && (booking!['details'] as List).isNotEmpty ? booking!['details'][0]['service_id'] : null),
      'rating': rating,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
    }, handleError: false);
    final ok = ApiClient.isSuccessCode(response.statusCode);
    final message = ok ? null : messageOf(response, 'Could not send your rating.');
    await refresh();
    busy = false;
    error = message;
    update();
    return ok;
  }

  static String messageOf(Response response, String fallback) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map && errors.first['message'] != null) {
        return errors.first['message'].toString();
      }
      if (body['message'] is String && (body['message'] as String).isNotEmpty) return body['message'];
    }
    return response.statusText?.isNotEmpty == true ? response.statusText! : fallback;
  }

  /// 32 hex characters, stable for the same request within a minute.
  static String _requestId(int serviceId, int quantity, String address, DateTime? at) {
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final seed = '$serviceId|$quantity|$address|${at?.toIso8601String()}|$minute';
    var h1 = 0x811c9dc5, h2 = 0x01000193, h3 = 0x9e3779b9, h4 = 0x85ebca6b;
    for (final c in seed.codeUnits) {
      h1 = ((h1 ^ c) * 16777619) & 0xffffffff;
      h2 = ((h2 + c) * 2654435761) & 0xffffffff;
      h3 = ((h3 ^ (c << 3)) * 2246822519) & 0xffffffff;
      h4 = ((h4 + (c << 1)) * 3266489917) & 0xffffffff;
    }
    return [h1, h2, h3, h4].map((h) => h.toRadixString(16).padLeft(8, '0')).join();
  }

  @override
  void onClose() {
    stopFollowing();
    super.onClose();
  }
}
