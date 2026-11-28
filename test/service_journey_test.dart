import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/controllers/service_journey_controller.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/domain/models/booking_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backend's customer booking details (ServiceBookingController::customerDetails), unwrapped.
Map<String, dynamic> booking({String status = 'accepted', bool reviewed = false}) => {
      'id': 41, 'display_id': '41', 'provider_id': 7, 'booking_type': 'regular', 'booking_status': status, 'status_label': 'X',
      'payment_status': 'unpaid', 'payment_method': 'cash_after_service', 'booking_amount': 5000.0, 'scheduled': 1,
      'schedule_at': '2026-12-01 09:00:00', 'quantity': 2, 'details_count': 1, 'serviceman_ids': [3],
      'services': [{'service_id': 9, 'name': 'Sofa cleaning', 'quantity': 2}],
      'details': [{'id': 41, 'service_id': 9, 'service_name': 'Sofa cleaning', 'quantity': 2, 'price': 2500.0, 'calculated_price': 5000.0}],
      'status_history': {'accepted': '2026-11-29 10:00:00'}, 'cancellation_reason': null, 'canceled_by': null,
      'service_location': {'get_service_at': 'customer_location', 'address': 'Kilimani', 'lat': -1.29, 'lng': 36.78},
      'amount': {'booking_amount': 5000.0, 'discount_amount': 0.0, 'tax_amount': 0.0},
      'provider': {'id': 7, 'name': 'Sparkle Cleaners', 'phone': '+254700', 'zone_id': 1},
      'customer': {'id': 5, 'is_guest': false, 'name': 'Amina W', 'phone': '+254711'},
      'servicemen': [{'id': 3, 'name': 'Juma K', 'phone': '+254711000777', 'image_full_url': null}],
      'is_reviewed': reviewed, 'can_cancel': ['pending', 'accepted', 'confirmed'].contains(status),
      'currency_symbol': 'KSh', 'created_at': '2026-11-29T09:00:00.000000Z', 'updated_at': '2026-11-29T10:00:00.000000Z',
      'repeat_log': [], 'partial_payments': [],
    };

class FakeApi extends ApiClient {
  FakeApi(SharedPreferences prefs) : super(appBaseUrl: 'https://api.test', sharedPreferences: prefs);
  final Map<String, Response> answers = {};
  final List<String> calls = [];

  Response _answer(String uri) {
    for (final e in answers.entries) {
      if (uri.contains(e.key)) return e.value;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApi api;
  late ServiceJourneyController journey;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi(await SharedPreferences.getInstance());
    journey = ServiceJourneyController(apiClient: api);
  });

  tearDown(() => journey.stopFollowing());

  test('placing sends what the backend validates and returns the new id', () async {
    api.answers['/booking/place'] = Response(statusCode: 200, body: booking(status: 'pending'));
    final id = await journey.place(serviceId: 9, quantity: 2, address: 'Kilimani', lat: -1.29, lng: 36.78);
    expect(id, 41);
    final sent = api.calls.single;
    for (final part in ['buy_now: 1', 'booking_type: regular', 'payment_method: cash_after_service', 'service_id: 9', 'quantity: 2', 'scheduled: 0', 'address: Kilimani']) {
      expect(sent, contains(part));
    }
    expect(RegExp(r'client_request_id: [a-f0-9]{32}').hasMatch(sent), isTrue);
  });

  test('a refused booking explains why', () async {
    api.answers['/booking/place'] = const Response(statusCode: 422, body: {
      'identical_code': 'x', 'message': 'x', 'content': null, 'errors': [{'code': 'x', 'message': 'The address is outside the service area.'}],
    });
    expect(await journey.place(serviceId: 9, quantity: 1, address: 'Far', lat: 0, lng: 0), isNull);
    expect(journey.error, 'The address is outside the service area.');
  });

  test('details load; cancel and rate go to the right endpoints', () async {
    api.answers['/booking/details/'] = Response(statusCode: 200, body: booking());
    await journey.follow(41);
    expect(journey.status, 'accepted');
    expect(journey.canCancel, isTrue);
    expect(journey.canRate, isFalse);

    api.answers['/booking/cancel'] = Response(statusCode: 200, body: booking(status: 'canceled'));
    api.answers['/booking/details/'] = Response(statusCode: 200, body: booking(status: 'canceled'));
    expect(await journey.cancel('Changed my plans'), isTrue);
    expect(api.calls.any((c) => c.contains('/booking/cancel') && c.contains('id: 41') && c.contains('reason: Changed my plans')), isTrue);
    expect(journey.status, 'canceled');

    api.answers['/booking/details/'] = Response(statusCode: 200, body: booking(status: 'completed'));
    await journey.refresh();
    expect(journey.canRate, isTrue);
    api.answers['/reviews/submit'] = const Response(statusCode: 200, body: {'message': 'ok', 'id': 1});
    expect(await journey.rate(4, 'Spotless'), isTrue);
    expect(api.calls.any((c) => c.contains('/reviews/submit') && c.contains('rating: 4') && c.contains('service_id: 9')), isTrue);
  });

  test('the app booking model reads the backend list row', () {
    final row = BookingModel.fromJson(booking());
    expect(row.id, 41);
    expect(row.bookingStatus, 'accepted');
  });
}
