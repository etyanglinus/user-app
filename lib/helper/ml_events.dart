import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sends shopping events to the Fasta ML engine (`POST /api/v1/events`, contract
/// `fasta.event.v1`, see marcov-and-ml/docs/EVENTS.md).
///
/// Design rules:
/// * Never in the way: [track] is synchronous and cheap, every failure is swallowed, nothing
///   here can throw into a screen or slow a tap.
/// * Batched: events queue in memory and go out every 10 s, at 20 queued, and when the app is
///   backgrounded (then also saved, so a killed app sends them on next start).
/// * Bounded: at most 500 queued (oldest dropped), 50 per request, backoff up to 5 minutes
///   while offline or the server errors; a rejected batch (4xx) is dropped, not retried.
/// * Private: no user id is sent; the backend derives it from the auth token and
///   pseudonymises it. The same opt-out as seller analytics (`fasta_analytics_disabled`).
class MlEvents with WidgetsBindingObserver {
  MlEvents._();
  static final MlEvents instance = MlEvents._();

  static const String surfaceApp = 'marketplace_app';
  static const String surfaceReels = 'reels_feed';

  static const int maxQueue = 500;
  static const int maxBatch = 50;
  static const int flushAt = 20;
  static const Duration flushEvery = Duration(seconds: 10);
  static const Duration sessionIdle = Duration(minutes: 30);
  static const Duration maxBackoff = Duration(minutes: 5);
  static const String _prefDevice = 'ml_events_device_id';
  static const String _prefQueue = 'ml_events_queue';
  static const String _prefOptOut = 'fasta_analytics_disabled';

  static const Set<String> _actions = {
    'view', 'impression', 'watch_milestone', 'product_tap', 'add_to_cart', 'checkout_start', 'order_completed', 'drop_off',
  };
  static const Set<String> _entityTypes = {'screen', 'module', 'store', 'item', 'reel', 'category', 'vehicle', 'service', 'order'};
  static const Set<String> _props = {
    'milestone', 'position', 'rec_id', 'slot', 'screen', 'price', 'quantity', 'category_id', 'store_id', 'order_value', 'item_ids',
  };
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.:-]{1,64}$');

  SharedPreferences? _prefs;
  late String _endpoint;
  late Map<String, String> Function() _headers;
  late String _appVersion;
  late String _platform;
  http.Client? _client; // created on first send
  DateTime Function() _now = () => DateTime.now().toUtc();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _sending = false;
  bool _enabled = false;
  DateTime? _retryAfter;
  Duration _backoff = const Duration(seconds: 10);
  String? _deviceId;
  String? _sessionId;
  DateTime? _lastActivity;

  /// Context that changes as the customer moves around; read on every event.
  int? Function() moduleId = () => null;
  int? Function() zoneId = () => null;

  /// Call once at startup, after SharedPreferences and the API client exist.
  void init({
    required SharedPreferences prefs,
    required String baseUrl,
    required Map<String, String> Function() headers,
    required String appVersion,
    String? platform,
    http.Client? client,
    DateTime Function()? clock,
  }) {
    _prefs = prefs;
    _endpoint = '$baseUrl/api/v1/events';
    _headers = headers;
    _appVersion = appVersion.length > 20 ? appVersion.substring(0, 20) : appVersion;
    _platform = platform ?? (kIsWeb ? 'web' : defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    if (client != null) _client = client;
    if (clock != null) _now = clock;
    _enabled = prefs.getBool(_prefOptOut) != true;
    _deviceId = prefs.getString(_prefDevice);
    if (_deviceId == null) {
      _deviceId = uuid();
      prefs.setString(_prefDevice, _deviceId!);
    }
    _restore();
    _timer?.cancel();
    _timer = Timer.periodic(flushEvery, (_) => flush());
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Record one event. Invalid input is dropped (debug-logged), never thrown.
  void track(
    String action, {
    String surface = surfaceApp,
    String? entityType,
    Object? entityId,
    Map<String, Object?>? props,
    int? moduleId,
    int? zoneId,
  }) {
    if (!_enabled || _prefs == null) return;
    try {
      final event = build(action, surface: surface, entityType: entityType, entityId: entityId, props: props,
        moduleId: moduleId, zoneId: zoneId);
      if (event == null) return;
      _queue.add(event);
      if (_queue.length > maxQueue) _queue.removeRange(0, _queue.length - maxQueue);
      if (_queue.length >= flushAt) flush();
    } catch (e) {
      if (kDebugMode) debugPrint('ml-events: dropped $action ($e)');
    }
  }

  /// A screen view; [route] is the GetX route (query string ignored).
  void screen(String? route) {
    final name = screenName(route);
    if (name == null) return;
    track('view', entityType: 'screen', entityId: name.replaceAll('/', '.'), props: {'screen': name});
  }

  /// The event as sent, or null when it breaks the contract. Public for tests.
  @visibleForTesting
  Map<String, dynamic>? build(
    String action, {
    String surface = surfaceApp,
    String? entityType,
    Object? entityId,
    Map<String, Object?>? props,
    int? moduleId,
    int? zoneId,
  }) {
    if (!_actions.contains(action)) return null;
    Map<String, String>? entity;
    if (entityType != null && entityId != null) {
      final id = '$entityId';
      if (!_entityTypes.contains(entityType) || !_idPattern.hasMatch(id)) return null;
      entity = {'type': entityType, 'id': id};
    }
    final cleanProps = <String, Object>{};
    props?.forEach((k, v) {
      if (v != null && _props.contains(k)) cleanProps[k] = v;
    });
    if ((action == 'product_tap' || action == 'add_to_cart') && entity == null) return null;
    if (action == 'watch_milestone' && (entity?['type'] != 'reel' || ![25, 50, 75, 100].contains(cleanProps['milestone']))) return null;
    if (action == 'impression' && (entity == null || cleanProps['rec_id'] == null)) return null;

    final now = _now();
    if (_sessionId == null || _lastActivity == null || now.difference(_lastActivity!) > sessionIdle) {
      _sessionId = uuid();
    }
    _lastActivity = now;
    final mod = moduleId ?? this.moduleId();
    final zone = zoneId ?? this.zoneId();
    return {
      'event_id': uuid(),
      'occurred_at': now.toIso8601String(),
      'surface': surface,
      'action': action,
      'platform': _platform,
      'app_version': _appVersion,
      if (mod != null && mod > 0) 'module_id': mod,
      if (zone != null && zone > 0) 'zone_id': zone,
      if (entity != null) 'entity': entity,
      'device_id': _deviceId,
      'session_id': _sessionId,
      if (cleanProps.isNotEmpty) 'props': cleanProps,
    };
  }

  /// Send what is queued (one request of up to [maxBatch]; the timer sends the rest).
  Future<void> flush() async {
    if (_sending || _queue.isEmpty || !_enabled) return;
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) return;
    _sending = true;
    final batch = _queue.take(maxBatch).toList();
    try {
      final headers = Map<String, String>.from(_headers())
        ..['Content-Type'] = 'application/json'
        ..['Accept'] = 'application/json';
      final res = await (_client ??= http.Client())
          .post(Uri.parse(_endpoint), headers: headers, body: jsonEncode({'events': batch}))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 429 || res.statusCode >= 500) {
        _scheduleRetry();
      } else {
        // 2xx: delivered. Other 4xx: the batch was refused; resending it would fail again.
        if (res.statusCode >= 400 && kDebugMode) debugPrint('ml-events: batch refused ${res.statusCode} ${res.body}');
        _queue.removeRange(0, min(batch.length, _queue.length));
        _retryAfter = null;
        _backoff = const Duration(seconds: 10);
      }
    } catch (_) {
      _scheduleRetry(); // offline or timed out: keep the events and try later
    } finally {
      _sending = false;
    }
  }

  void _scheduleRetry() {
    _retryAfter = _now().add(_backoff);
    _backoff = _backoff * 2 > maxBackoff ? maxBackoff : _backoff * 2;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      _persist();
      _retryAfter = null;
      flush().then((_) => _persist());
    }
  }

  void _persist() {
    try {
      final keep = _queue.length > 200 ? _queue.sublist(_queue.length - 200) : _queue;
      _prefs?.setString(_prefQueue, jsonEncode(keep));
    } catch (_) {}
  }

  void _restore() {
    try {
      final raw = _prefs?.getString(_prefQueue);
      if (raw == null) return;
      final saved = (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e));
      _queue.insertAll(0, saved);
      _prefs?.remove(_prefQueue);
    } catch (_) {
      _prefs?.remove(_prefQueue);
    }
  }

  /// Turn tracking off or on (privacy setting); off also clears the queue.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _prefs?.setBool(_prefOptOut, !enabled);
    if (!enabled) {
      _queue.clear();
      _prefs?.remove(_prefQueue);
    }
  }

  @visibleForTesting
  List<Map<String, dynamic>> get queued => List.unmodifiable(_queue);

  @visibleForTesting
  void resetForTest() {
    _timer?.cancel();
    _queue.clear();
    _sending = false;
    _retryAfter = null;
    _backoff = const Duration(seconds: 10);
    _sessionId = null;
    _lastActivity = null;
    _prefs = null;
  }

  /// `/item-details?id=3` → `item-details`; null for the empty or root route.
  static String? screenName(String? route) {
    if (route == null) return null;
    var r = route.split('?').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_/.-]'), '');
    r = r.replaceAll(RegExp(r'^/+|/+$'), '');
    if (r.isEmpty) return null;
    return r.length > 60 ? r.substring(0, 60) : r;
  }

  static String uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
