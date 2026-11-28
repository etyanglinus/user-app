import 'package:flutter_test/flutter_test.dart';
import 'package:fasta_deliveries/features/cms/cms_content.dart';

void main() {
  test('parses the enveloped list the backend returns', () {
    final items = CmsContent.listFrom({
      'identical_code': 'default_200',
      'message': 'ok',
      'content': {
        'contents': [
          {'id': 3, 'type': 'faq', 'slug': 'refunds', 'title': 'How do refunds work?', 'body': '<p>Within 3 days.</p>', 'published_at': '2026-11-27T10:00:00Z'},
          {'id': 4, 'type': 'faq', 'slug': 'x', 'title': ''},
        ]
      },
      'errors': [],
    });
    expect(items.length, 1);
    expect(items.first.title, 'How do refunds work?');
    expect(items.first.body, contains('3 days'));
    expect(items.first.publishedAt?.year, 2026);
  });

  test('parses a bare list and a single item', () {
    expect(CmsContent.listFrom({'contents': [{'id': '7', 'type': 'news', 'slug': 'n', 'title': 'Launch'}]}).single.id, 7);
    final one = CmsContent.oneFrom({'identical_code': 'default_200', 'content': {'id': 9, 'type': 'page', 'slug': 'about', 'title': 'About', 'body': '<p>x</p>'}});
    expect(one?.slug, 'about');
  });

  test('anything unexpected yields nothing instead of throwing', () {
    expect(CmsContent.listFrom(null), isEmpty);
    expect(CmsContent.listFrom('oops'), isEmpty);
    expect(CmsContent.listFrom({'identical_code': 'default_404', 'content': null}), isEmpty);
    expect(CmsContent.oneFrom({'identical_code': 'default_404', 'content': null}), isNull);
  });

  test('the audience matches this app', () {
    expect(CmsRepository.audience, isNotEmpty);
  });
}
