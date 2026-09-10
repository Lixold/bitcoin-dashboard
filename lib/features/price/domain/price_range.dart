/// The five ranges the published history covers.
///
/// **The key is the file name, and the file name is case-sensitive.**
/// `history-1D.json` is served, `history-1d.json` returns 404, so the
/// upper-case spelling is the value rather than something [path] derives
/// from a lower-case name.
///
/// There is no `ALL`. The source ends at 365 days — a sixth option would
/// be a tab with nothing behind it, which is the placeholder CLAUDE.md §5
/// rules out. It is issue #44, and the 200-week average is #35.
enum PriceRange {
  oneDay('1D'),
  oneWeek('1W'),
  oneMonth('1M'),
  threeMonths('3M'),
  oneYear('1Y');

  const PriceRange(this.key);

  /// The document's `range` field, and the upper-case part of its name.
  final String key;

  /// Path of this range's document under `CdnClient.host`.
  String get path => 'data/history-$key.json';

  /// Entry name inside the shared CDN cache box — one per range, so a
  /// switch back and forth costs no second request.
  ///
  /// Hyphenated like the two entries already in that box (`market`,
  /// `network-health`): the box is one namespace and reads better for it.
  String get cacheKey => 'history-$key';
}
