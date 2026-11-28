import 'dart:async';

import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/customer_ride.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:get/get.dart';

/// One ride from request to rating, for the customer: follows the ride's status, cancels it
/// with a reason, pays for it and rates it.
///
/// Live updates (pusher) are not wired for rides yet, so the open ride is refreshed every
/// [pollEvery] while a journey screen is showing; [stopFollowing] stops it when they close.
class RideJourneyController extends GetxController implements GetxService {
  final ApiClient apiClient;
  RideJourneyController({required this.apiClient});

  static const Duration pollEvery = Duration(seconds: 5);

  CustomerRide? ride;
  String? error;
  bool loading = false;
  bool busy = false;
  Map<String, List<String>> cancelReasons = const {};
  List<RidePaymentOption> paymentOptions = const [];

  Timer? _timer;
  String? _following;

  /// Load [rideId] now, then keep it fresh until [stopFollowing].
  Future<void> follow(String rideId) async {
    _following = rideId;
    _timer?.cancel();
    if (ride?.id != rideId) ride = null;
    await refreshRide(showLoading: ride == null);
    _timer = Timer.periodic(pollEvery, (_) {
      // Stop polling once nothing more can change on its own.
      final current = ride;
      if (current != null && !current.isActive && !(current.needsPayment && current.paymentMethod == 'cash')) return;
      refreshRide();
    });
  }

  void stopFollowing() {
    _timer?.cancel();
    _timer = null;
    _following = null;
  }

  Future<void> refreshRide({bool showLoading = false}) async {
    final id = _following;
    if (id == null) return;
    if (showLoading) {
      loading = true;
      update();
    }
    final response = await apiClient.getData('${AppConstants.tripDetails}$id', handleError: false);
    if (_following != id) return; // closed or switched meanwhile
    if (ApiClient.isSuccessCode(response.statusCode)) {
      final parsed = CustomerRide.tryParse(_data(response.body));
      if (parsed != null) {
        ride = parsed;
        error = null;
      }
    } else if (ride == null) {
      error = response.statusText ?? 'Could not load this ride.';
    }
    loading = false;
    update();
  }

  Future<void> loadCancelReasons() async {
    if (cancelReasons.isNotEmpty) return;
    final response = await apiClient.getData(AppConstants.rideCancellationReasonList, handleError: false);
    final data = _data(response.body);
    if (ApiClient.isSuccessCode(response.statusCode) && data is Map) {
      cancelReasons = {
        for (final stage in const ['accepted_ride', 'ongoing_ride'])
          stage: ((data[stage] as List?) ?? const []).map((e) => e.toString()).toList(),
      };
      update();
    }
  }

  /// Reasons that fit the ride's stage (a ride can only be cancelled before it starts).
  List<String> get reasonsForRide => cancelReasons['accepted_ride'] ?? const [];

  Future<bool> cancel(String? reason) async {
    final current = ride;
    if (current == null || busy) return false;
    busy = true;
    update();
    final response = await apiClient.postData(AppConstants.rideCancel, {
      'ride_request_id': current.id,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    }, handleError: false);
    final ok = ApiClient.isSuccessCode(response.statusCode);
    if (ok) {
      ride = CustomerRide.tryParse(_data(response.body)) ?? ride;
    } else {
      final message = _message(response, 'This ride can no longer be cancelled.');
      await refreshRide(); // show what the ride is now; this clears error, so set it after
      error = message;
    }
    busy = false;
    update();
    return ok;
  }

  Future<void> loadPaymentOptions() async {
    final response = await apiClient.getData(AppConstants.getPaymentMethods, handleError: false);
    final data = _data(response.body);
    if (ApiClient.isSuccessCode(response.statusCode) && data is List) {
      paymentOptions = data.map(RidePaymentOption.tryParse).whereType<RidePaymentOption>().toList();
    }
    if (paymentOptions.isEmpty) {
      paymentOptions = const [RidePaymentOption(name: 'cash', title: 'Cash')];
    }
    update();
  }

  /// Wallet pays now; cash tells the driver to expect it (they confirm in their app).
  Future<bool> pay(String method) async {
    final current = ride;
    if (current == null || busy) return false;
    busy = true;
    error = null;
    update();
    final response = await apiClient.postData(AppConstants.paymentUri, {'ride_request_id': current.id, 'payment_method': method}, handleError: false);
    final ok = ApiClient.isSuccessCode(response.statusCode);
    if (ok) {
      ride = CustomerRide.tryParse(_data(response.body)) ?? ride;
    } else {
      error = _message(response, 'Payment did not go through. Please try again.');
    }
    busy = false;
    update();
    return ok;
  }

  Future<bool> rate(int rating, String feedback) async {
    final current = ride;
    if (current == null || busy) return false;
    busy = true;
    error = null;
    update();
    final response = await apiClient.postData(AppConstants.submitReview, {
      'ride_request_id': current.id,
      'rating': rating,
      if (feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
    }, handleError: false);
    final ok = ApiClient.isSuccessCode(response.statusCode);
    if (!ok) error = _message(response, 'Could not send your rating.');
    busy = false;
    update();
    return ok;
  }

  /// Ride endpoints answer `{response_code, message, data: …}` inside the envelope.
  static dynamic _data(dynamic body) {
    final payload = ResponseParser.payloadOf(body);
    return payload is Map && payload.containsKey('data') ? payload['data'] : payload;
  }

  static String _message(Response response, String fallback) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map && errors.first['message'] != null) {
        return errors.first['message'].toString();
      }
      if (body['message'] is String) return body['message'];
    }
    return response.statusText?.isNotEmpty == true ? response.statusText! : fallback;
  }

  @override
  void onClose() {
    stopFollowing();
    super.onClose();
  }
}
