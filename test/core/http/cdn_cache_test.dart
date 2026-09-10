import 'package:bitcoin_dashboard/core/http/cdn_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// What the extraction added: two documents in one box.
///
/// The behaviour each cache has on its own is covered where it was
/// written — `network_health_cache_test.dart` still exercises the
/// envelope, the corrupt entry and the UTC stamp through the wrapper it
/// was written against. This file only asks the question that could not
/// be asked before there were two keys.
void main() {
  setUpTestHive(boxes: const [CdnCache.boxName], clearBetweenTests: true);

  const market = CdnCache(key: 'market', ttl: Duration(minutes: 15));
  const health = CdnCache(key: 'network-health', ttl: Duration(minutes: 60));

  test('two documents share the box without reading each other', () async {
    await market.write(const {
      'source': 'market',
    }, DateTime.utc(2026, 9, 9, 12));
    await health.write(const {
      'source': 'health',
    }, DateTime.utc(2026, 9, 9, 13));

    expect((await market.read())!.payload['source'], 'market');
    expect((await health.read())!.payload['source'], 'health');
  });

  test(
    'a document with nothing stored reads as null beside a full one',
    () async {
      await health.write(const {
        'source': 'health',
      }, DateTime.utc(2026, 9, 9, 13));

      expect(await market.read(), isNull);
    },
  );

  test('writing one document does not restamp the other', () async {
    await market.write(const {
      'source': 'market',
    }, DateTime.utc(2026, 9, 9, 12));
    await health.write(const {
      'source': 'health',
    }, DateTime.utc(2026, 9, 9, 13));
    await market.write(const {
      'source': 'market',
    }, DateTime.utc(2026, 9, 9, 14));

    expect((await health.read())!.cachedAt, DateTime.utc(2026, 9, 9, 13));
  });

  test('the TTL travels with the document, not with the box', () {
    expect(market.ttl, const Duration(minutes: 15));
    expect(health.ttl, const Duration(minutes: 60));
  });
}
