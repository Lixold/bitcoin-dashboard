import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_provider.dart';

/// Read-only reader for the static JSON the Workers publish to the CDN
/// (ADR-0003 for how the files are produced, ADR-0005 for their shape).
///
/// **This is a second outbound host for the app, and the first that is
/// ours.** Until now the app only spoke to the live public APIs listed in
/// ADR-0002; `data.bitcoin-dashboard.app` is added to that ADR in the
/// same pull request, as CLAUDE.md §1 requires. It changes nothing about
/// the privacy posture: the bucket is world-readable static files behind
/// a CDN, the requests carry no identity, and there is no write path —
/// see SECURITY.md.
///
/// It sits in `core/http/` next to [dioProvider] rather than under the
/// one feature that uses it today. The host is an app-level fact
/// documented in an ADR, not a property of the network section, and the
/// next CDN-backed slice would otherwise either duplicate the string or
/// import across features.
class CdnClient {
  CdnClient(this._dio);

  /// Origin of the published data. One place, so a move of the bucket is
  /// one edit and one ADR change.
  static const String host = 'https://data.bitcoin-dashboard.app';

  final Dio _dio;

  /// Fetches and decodes one published document, e.g. `data/market.json`.
  ///
  /// No cache headers are set here: the CDN sends its own `max-age` and
  /// how long the app reuses a payload is a decision per document, taken
  /// by that document's cache.
  Future<Map<String, dynamic>> fetchJson(String path) async {
    final response = await _dio.get<Map<String, dynamic>>('$host/$path');
    final data = response.data;
    if (data == null) {
      throw FormatException('Empty body from CDN path $path');
    }
    return data;
  }
}

final cdnClientProvider = Provider<CdnClient>((ref) {
  return CdnClient(ref.watch(dioProvider));
});
