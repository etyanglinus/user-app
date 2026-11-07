import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fasta_deliveries/util/app_constants.dart';

class SellerAnalytics {
  static Future<void>? _pending;
  static String? _visitor;
  static String? _session;
  static DateTime? _lastEvent;

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('fasta_analytics_disabled') == true) return;
    _visitor = prefs.getString('fasta_analytics_visitor') ?? _uuid();
    await prefs.setString('fasta_analytics_visitor', _visitor!);
  }

  static Future<void> track(int? storeId, String event) async {
    if (storeId == null) return;
    try {
      _pending ??= _initialize();
      await _pending;
      if (_visitor == null) return;
      final now = DateTime.now();
      if (_session == null || _lastEvent == null || now.difference(_lastEvent!).inMinutes >= 30) {
        _session = _uuid();
      }
      _lastEvent = now;
      final channel = kIsWeb ? 'web' : defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/v1/analytics/events'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'event_id': _uuid(), 'store_id': storeId, 'visitor_id': _visitor,
          'session_id': _session, 'channel': channel, 'event': event,
          'device': kIsWeb ? 'desktop' : 'mobile',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Analytics must not interrupt shopping.
    }
  }
}

