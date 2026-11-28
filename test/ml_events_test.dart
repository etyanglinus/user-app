import 'dart:convert';

import 'package:fasta_deliveries/helper/ml_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ml = MlEvents.instance;
  late List<http.Request> sent;
  late int status;
  late DateTime now;
  var offline = false;

  Future<void> setUpTracker({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    ml.resetForTest();
    sent = [];
    status = 202;
    offline = false;
    now = DateTime.utc(2026, 11, 28, 10);
    ml.moduleId = () => 2;
    ml.zoneId = () => 1;
    ml.init(
      prefs: await SharedPreferences.getInstance(),
      baseUrl: 'https://api.test',
      headers: () => {'Authorization': 'Bearer abc'},
      appVersion: '5.0.0',
      platform: 'android',
      clock: () => now,
      client: MockClient((req) async {
        if (offline) throw http.ClientException('offline');
        sent.add(req);
        return http.Response('{"accepted":1}', status);
      }),
    );
  }

  List<Map<String, dynamic>> eventsIn(http.Request r) =>
      (jsonDecode(r.body)['events'] as List).cast<Map<String, dynamic>>();

  test('builds a contract-valid event with context and no user id', () async {
    await setUpTracker();
    ml.track('product_tap', entityType: 'item', entityId: 42, props: {'price': 350.0, 'store_id': 7, 'name': 'not allowed'});
    final e = ml.queued.single;
    expect(e['surface'], 'marketplace_app');
    expect(e['action'], 'product_tap');
    expect(e['platform'], 'android');
    expect(e['module_id'], 2);
    expect(e['zone_id'], 1);
    expect(e['entity'], {'type': 'item', 'id': '42'});
    expect(e['props'], {'price': 350.0, 'store_id': 7});
    expect(e['occurred_at'], '2026-11-28T10:00:00.000Z');
    expect(e.containsKey('user_id'), isFalse);
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(e['event_id']), isTrue);
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(e['device_id']), isTrue);
  });

  test('drops events that break the contract', () async {
    await setUpTracker();
    ml.track('purchase');                                                   // unknown action
    ml.track('add_to_cart');                                                // needs an entity
    ml.track('view', entityType: 'item', entityId: 'has space');            // bad id
    ml.track('view', entityType: 'product', entityId: 1);                   // bad entity type
    ml.track('watch_milestone', entityType: 'reel', entityId: 9, props: {'milestone': 60});
    ml.track('watch_milestone', entityType: 'item', entityId: 9, props: {'milestone': 50});
    ml.track('impression', entityType: 'item', entityId: 3);                // needs rec_id
    expect(ml.queued, isEmpty);
    ml.track('watch_milestone', surface: MlEvents.surfaceReels, entityType: 'reel', entityId: 9, props: {'milestone': 50});
    expect(ml.queued.single['surface'], 'reels_feed');
  });

  test('sends batches of at most 50 with the auth header, then empties the queue', () async {
    await setUpTracker();
    for (var i = 0; i < 19; i++) {
      ml.track('view', entityType: 'store', entityId: i + 1);
    }
    expect(sent, isEmpty, reason: 'below 20 nothing is sent until the timer or backgrounding');
    await ml.flush();
    expect(sent.single.headers['Authorization'], 'Bearer abc');
    expect(sent.single.url.toString(), 'https://api.test/api/v1/events');
    expect(eventsIn(sent.single), hasLength(19));
    expect(ml.queued, isEmpty);

    for (var i = 0; i < 70; i++) {
      ml.track('view', entityType: 'store', entityId: i + 1);
    }
    await Future<void>.delayed(Duration.zero);
    await ml.flush();
    await ml.flush();
    expect(sent.skip(1).map((r) => eventsIn(r).length).every((n) => n <= 50), isTrue);
    expect(ml.queued, isEmpty);
  });

  test('keeps events while offline and backs off; a refused batch is dropped', () async {
    await setUpTracker();
    ml.track('view', entityType: 'store', entityId: 1);
    offline = true;
    await ml.flush();
    expect(ml.queued, hasLength(1));
    offline = false;
    await ml.flush();
    expect(sent, isEmpty, reason: 'still inside the backoff window');
    now = now.add(const Duration(seconds: 11));
    await ml.flush();
    expect(sent, hasLength(1));
    expect(ml.queued, isEmpty);

    status = 500;
    ml.track('view', entityType: 'store', entityId: 2);
    await ml.flush();
    expect(ml.queued, hasLength(1), reason: 'server error: retried later');
    status = 422;
    now = now.add(const Duration(minutes: 1));
    await ml.flush();
    expect(ml.queued, isEmpty, reason: 'validation refusal: not retried');
  });

  test('session rotates after 30 idle minutes; device id is stable', () async {
    await setUpTracker();
    ml.track('view', entityType: 'store', entityId: 1);
    now = now.add(const Duration(minutes: 29));
    ml.track('view', entityType: 'store', entityId: 2);
    now = now.add(const Duration(minutes: 31));
    ml.track('view', entityType: 'store', entityId: 3);
    final q = ml.queued;
    expect(q[0]['session_id'], q[1]['session_id']);
    expect(q[2]['session_id'], isNot(q[1]['session_id']));
    expect({for (final e in q) e['device_id']}, hasLength(1));
  });

  test('respects the analytics opt-out', () async {
    await setUpTracker(prefs: {'fasta_analytics_disabled': true});
    ml.track('view', entityType: 'store', entityId: 1);
    expect(ml.queued, isEmpty);
  });

  test('screen names come from routes without the query string', () {
    expect(MlEvents.screenName('/item-details?id=3&page=item'), 'item-details');
    expect(MlEvents.screenName('/'), isNull);
    expect(MlEvents.screenName('/Store/Search'), 'store/search');
  });
}
