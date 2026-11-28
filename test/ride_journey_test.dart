import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_location/domain/models/ride_details_model.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/controllers/ride_journey_controller.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/customer_ride.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the backend's customer ride endpoints send (RideController::serialize, customer view),
/// already unwrapped from the envelope as ApiClient does.
Map<String, dynamic> backendRide({String status = 'accepted', String payment = 'unpaid', String? method, bool withDriver = true}) => {
      'id': 'a1b2c3d4-0000-4000-8000-000000000001',
      'ref_id': 'r-1',
      'type': 'ride_request',
      'current_status': status,
      'pickup_address': 'Westlands',
      'destination_address': 'CBD',
      'pickup_coordinates': {'type': 'Point', 'coordinates': [36.82, -1.28]},
      'destination_coordinates': {'type': 'Point', 'coordinates': [36.8, -1.3]},
      'estimated_fare': '400',
      'total_fare': '400',
      'estimated_distance': 5,
      'estimated_time': '15',
      'encoded_polyline': null,
      'payment_method': method,
      'payment_status': payment,
      'otp': status == 'accepted' ? '482913' : null,
      'paid_fare': payment == 'paid' ? '400' : '0',
      'cancellation_reason': null,
      'cancelled_by': null,
      'accepted_at': '2026-11-29T08:00:00.000000Z',
      'paid_at': null,
      'created_at': '2026-11-29T07:58:00.000000Z',
      'driver': withDriver
          ? {
              'id': 7, 'first_name': 'Otieno', 'last_name': 'D', 'phone': '+254722000111', 'image': null,
              'avg_rating': 4.8, 'total_reviews': 12,
              'vehicle': {'brand': 'Toyota', 'model': 'Fielder', 'category': 'Car', 'licence_plate_number': 'KDB 456B'},
            }
          : null,
      'review_submitted': false,
    };

class FakeApi extends ApiClient {
  FakeApi(SharedPreferences prefs) : super(appBaseUrl: 'https://api.test', sharedPreferences: prefs);

  final List<String> calls = [];
  final Map<String, Response> answers = {};

  Response _answer(String uri) {
    for (final entry in answers.entries) {
      if (uri.contains(entry.key)) return entry.value;
    }
    return const Response(statusCode: 404);
  }

  @override
  Future<Response> getData(String uri, {Map<String, dynamic>? query, Map<String, String>? headers, bool handleError = true,
      bool moduleScoped = false, bool rawBody = false}) async {
    calls.add(uri);
    return _answer(uri);
  }

  @override
  Future<Response> postData(String uri, dynamic body, {Map<String, String>? headers, int? timeout, bool handleError = true}) async {
    calls.add('$uri $body');
    return _answer(uri);
  }
}

Response ok(dynamic data) => Response(statusCode: 200, body: {'response_code': 'success', 'message': 'Success', 'data': data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApi api;
  late RideJourneyController journey;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi(await SharedPreferences.getInstance());
    journey = RideJourneyController(apiClient: api);
  });

  tearDown(() => journey.stopFollowing());

  test('the trip screen model reads the backend ride with the driver card', () {
    final ride = CustomerRide.tryParse(backendRide())!;
    expect(ride.status, CustomerRide.accepted);
    expect(ride.fare, 400);
    expect(ride.otp, '482913');
    expect(ride.canCancel, isTrue);
    expect(ride.driver!.name, 'Otieno D');
    expect(ride.driver!.vehicle, 'Toyota Fielder');
    expect(ride.driver!.plate, 'KDB 456B');
    expect(ride.driver!.rating, 4.8);
    expect(CustomerRide.tryParse({'current_status': 'pending'}), isNull, reason: 'no id, no ride');
  });

  test('My Orders can parse backend rides without crashing (missing fare fields)', () {
    final details = RideDetails.fromJson(backendRide(status: 'completed', payment: 'paid', method: 'wallet'));
    expect(details.currentStatus, 'completed');
    expect(details.paidFare, 400);
    expect(details.actualFare, isNull);
    expect(details.driver!.firstName, 'Otieno');
    expect(details.driver!.rating, 4.8);
    expect(RideDetails.fromJson(backendRide(withDriver: false, status: 'pending')).driver, isNull);
  });

  test('following loads the ride, and cancelling sends the reason', () async {
    api.answers['/customer/ride/details/'] = ok(backendRide());
    api.answers['/config/cancellation-reason-list'] = ok({'accepted_ride': ['Driver is taking too long'], 'ongoing_ride': ['Safety concern']});
    await journey.follow('a1b2c3d4-0000-4000-8000-000000000001');
    expect(journey.ride!.driver!.name, 'Otieno D');

    await journey.loadCancelReasons();
    expect(journey.reasonsForRide, ['Driver is taking too long']);

    api.answers['/customer/ride/cancel'] = ok(backendRide(status: 'cancelled', withDriver: false));
    expect(await journey.cancel('Driver is taking too long'), isTrue);
    expect(journey.ride!.status, CustomerRide.cancelled);
    expect(api.calls.any((c) => c.contains('/customer/ride/cancel') && c.contains('reason: Driver is taking too long')), isTrue);
  });

  test('a refused cancel shows the server message', () async {
    api.answers['/customer/ride/details/'] = ok(backendRide(status: 'ongoing'));
    await journey.follow('a1b2c3d4-0000-4000-8000-000000000001');
    api.answers['/customer/ride/cancel'] = const Response(statusCode: 409, body: {
      'identical_code': 'already_exists_409', 'message': 'Conflict', 'content': null,
      'errors': [{'code': 'conflict', 'message': 'A ride that has started cannot be cancelled.'}],
    });
    expect(await journey.cancel(null), isFalse);
    expect(journey.error, 'A ride that has started cannot be cancelled.');
  });

  test('wallet payment marks the ride paid; cash waits for the driver', () async {
    api.answers['/customer/ride/details/'] = ok(backendRide(status: 'completed'));
    api.answers['/config/get-payment-methods'] = ok([
      {'id': 1, 'name': 'cash', 'title': 'Cash'},
      {'id': 2, 'name': 'wallet', 'title': 'Wallet', 'balance': 1000},
    ]);
    await journey.follow('a1b2c3d4-0000-4000-8000-000000000001');
    await journey.loadPaymentOptions();
    expect(journey.paymentOptions.map((o) => o.name), ['cash', 'wallet']);
    expect(journey.paymentOptions.last.balance, 1000);
    expect(journey.ride!.needsPayment, isTrue);

    api.answers['/customer/ride/payment'] = ok(backendRide(status: 'completed', method: 'cash'));
    expect(await journey.pay('cash'), isTrue);
    expect(journey.ride!.isPaid, isFalse);
    expect(journey.ride!.paymentMethod, 'cash');

    api.answers['/customer/ride/payment'] = ok(backendRide(status: 'completed', payment: 'paid', method: 'wallet'));
    expect(await journey.pay('wallet'), isTrue);
    expect(journey.ride!.isPaid, isTrue);
  });

  test('without the payment-methods endpoint, cash is still offered', () async {
    await journey.loadPaymentOptions();
    expect(journey.paymentOptions.single.name, 'cash');
  });

  test('rating sends the app field names', () async {
    api.answers['/customer/ride/details/'] = ok(backendRide(status: 'completed', payment: 'paid'));
    api.answers['/customer/review/store'] = ok({'id': 1, 'rating': 5});
    await journey.follow('a1b2c3d4-0000-4000-8000-000000000001');
    expect(await journey.rate(5, 'Great driver'), isTrue);
    expect(api.calls.last, contains('rating: 5'));
    expect(api.calls.last, contains('feedback: Great driver'));
  });
}
