import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fasta_deliveries/api/api_client.dart';

/// Content published from Fasta's ERP (CMS → Website and app content).
/// Read-only: `GET /api/v1/cms/contents` and `/api/v1/cms/contents/{type}/{slug}`.
/// Anything that goes wrong (offline, backend not updated yet) shows nothing rather than an
/// error, so the rest of the app is unaffected.
class CmsContent {
  final int id;
  final String type;
  final String slug;
  final String title;
  final String? summary;
  final String? body;
  final DateTime? publishedAt;

  const CmsContent({required this.id, required this.type, required this.slug, required this.title, this.summary, this.body, this.publishedAt});

  factory CmsContent.fromJson(Map<String, dynamic> json) => CmsContent(
        id: int.tryParse('${json['id']}') ?? 0,
        type: '${json['type'] ?? ''}',
        slug: '${json['slug'] ?? ''}',
        title: '${json['title'] ?? ''}',
        summary: json['summary']?.toString(),
        body: json['body']?.toString(),
        publishedAt: DateTime.tryParse('${json['published_at'] ?? ''}'),
      );

  /// Accepts the API envelope ({identical_code, content: {...}}) or the bare payload.
  static dynamic unwrap(dynamic body) =>
      body is Map && body.containsKey('identical_code') ? body['content'] : body;

  static List<CmsContent> listFrom(dynamic body) {
    final payload = unwrap(body);
    final raw = payload is Map ? payload['contents'] : payload;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => CmsContent.fromJson(Map<String, dynamic>.from(e))).where((c) => c.title.isNotEmpty).toList();
  }

  static CmsContent? oneFrom(dynamic body) {
    final payload = unwrap(body);
    return payload is Map && payload['title'] != null ? CmsContent.fromJson(Map<String, dynamic>.from(payload)) : null;
  }
}

class CmsRepository {
  static const String audience = 'customers';
  static const String _uri = '/api/v1/cms/contents';

  static Future<List<CmsContent>> list(String type, {bool withBody = false}) async {
    try {
      final Response r = await Get.find<ApiClient>().getData(_uri,
          query: {'type': type, 'audience': audience, if (withBody) 'with_body': '1'}, handleError: false);
      return r.statusCode == 200 ? CmsContent.listFrom(r.body) : const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<CmsContent?> one(String type, String slug) async {
    try {
      final Response r = await Get.find<ApiClient>().getData('$_uri/$type/$slug', handleError: false);
      return r.statusCode == 200 ? CmsContent.oneFrom(r.body) : null;
    } catch (_) {
      return null;
    }
  }
}

/// FAQs (expandable) or news (list → detail).
class CmsListScreen extends StatefulWidget {
  final String type; // 'faq' or 'news'
  const CmsListScreen({super.key, required this.type});

  @override
  State<CmsListScreen> createState() => _CmsListScreenState();
}

class _CmsListScreenState extends State<CmsListScreen> {
  late Future<List<CmsContent>> _items;

  @override
  void initState() {
    super.initState();
    _items = CmsRepository.list(widget.type, withBody: widget.type == 'faq');
  }

  @override
  Widget build(BuildContext context) {
    final bool faq = widget.type == 'faq';
    return Scaffold(
      appBar: AppBar(title: Text(faq ? 'help_and_faqs'.tr : 'news_and_updates'.tr)),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _items = CmsRepository.list(widget.type, withBody: faq));
          await _items;
        },
        child: FutureBuilder<List<CmsContent>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('nothing_here_yet'.tr)))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = items[i];
                if (faq) {
                  return Card(
                    child: ExpansionTile(
                      title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [HtmlWidget(c.body ?? c.summary ?? '')],
                    ),
                  );
                }
                return Card(
                  child: ListTile(
                    title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: c.summary == null ? null : Text(c.summary!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Get.to(() => CmsDetailScreen(type: c.type, slug: c.slug, title: c.title)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CmsDetailScreen extends StatelessWidget {
  final String type;
  final String slug;
  final String title;
  const CmsDetailScreen({super.key, required this.type, required this.slug, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<CmsContent?>(
        future: CmsRepository.one(type, slug),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final c = snap.data;
          if (c == null) return Center(child: Text('nothing_here_yet'.tr));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, style: Theme.of(context).textTheme.titleLarge),
              if (c.publishedAt != null)
                Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text('${c.publishedAt!.toLocal()}'.split(' ').first, style: Theme.of(context).textTheme.bodySmall)),
              HtmlWidget(c.body ?? ''),
            ]),
          );
        },
      ),
    );
  }
}

/// The newest live announcement for this app's audience, dismissible. Renders nothing when
/// there is none, it was dismissed, or the request failed.
class CmsAnnouncementBanner extends StatefulWidget {
  const CmsAnnouncementBanner({super.key});

  @override
  State<CmsAnnouncementBanner> createState() => _CmsAnnouncementBannerState();
}

class _CmsAnnouncementBannerState extends State<CmsAnnouncementBanner> {
  static const String _dismissedKey = 'cms_dismissed_announcements';
  CmsContent? _item;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await CmsRepository.list('announcement', withBody: true);
    if (items.isEmpty || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedKey) ?? const [];
    final fresh = items.where((c) => !dismissed.contains('${c.id}')).toList();
    if (fresh.isNotEmpty && mounted) setState(() => _item = fresh.first);
  }

  Future<void> _dismiss() async {
    final c = _item;
    if (c == null) return;
    setState(() => _item = null);
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_dismissedKey) ?? <String>[];
    prefs.setStringList(_dismissedKey, [...list.where((e) => e != '${c.id}'), '${c.id}'].take(50).toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = _item;
    if (c == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.primary.withValues(alpha: 0.3))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.to(() => CmsDetailScreen(type: c.type, slug: c.slug, title: c.title)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(children: [
            Icon(Icons.campaign_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (c.summary != null && c.summary!.isNotEmpty) Text(c.summary!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), tooltip: 'dismiss'.tr, onPressed: _dismiss),
          ]),
        ),
      ),
    );
  }
}
