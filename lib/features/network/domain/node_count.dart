/// Which way the reachable-node count moved over the last 24 hours, as
/// `cron-network-stats` classified it.
///
/// The producer applies a symmetric ±0.5 % dead band before it leaves
/// `stable`, so a day that moves 0.3 % is flat, not "slightly up". That
/// judgement is the worker's and is not repeated here — this app parses
/// the label, it does not derive it.
enum NodeTrend {
  up,
  down,
  stable,

  /// The producer could not compare: its 24 h reference snapshot sat
  /// more than six hours off target, or the source failed outright.
  /// **Also every label this app does not know.** The worker is free to
  /// introduce a fifth one, and an unknown string must degrade to "no
  /// classification" rather than send the screen to an error state.
  unknown;

  static NodeTrend parse(String? raw) => switch (raw) {
    'up' => NodeTrend.up,
    'down' => NodeTrend.down,
    'stable' => NodeTrend.stable,
    _ => NodeTrend.unknown,
  };
}

/// The `fullNodes` object of `network-health.json`: how many reachable
/// full nodes the producer counted, and how that compares to a day ago.
///
/// **No thresholds and no bands.** Unlike `PoolConcentration`, which
/// derives its verdict in the client, this statement's verdict hangs on
/// the bare figure: that many reachable nodes is what "no single actor
/// can control the network" rests on. There is no canonical number of
/// nodes that makes a network safe, so there is nothing for a
/// `BandScale` to declare — see CLAUDE.md §5, which governs metrics that
/// read as one of several levels.
class NodeCount {
  const NodeCount({
    required this.count,
    required this.percentChange24h,
    required this.trend,
  });

  /// Reads `fullNodes`, or returns `null` when the statement cannot be
  /// formed.
  ///
  /// The payload is fixed-shape — the producer writes
  /// `{count: null, percentChange24h: null, trend: "unknown"}` rather
  /// than omitting the object — so the object is expected and only its
  /// fields are nullable.
  ///
  /// A missing `count` returns `null` instead of throwing, the same way
  /// `PoolConcentration.from` answers a payload with fewer than three
  /// pools: the document parsed fine, this one statement just has no
  /// subject. The other statement on the screen is unaffected.
  static NodeCount? from(Map<String, dynamic> json) {
    final count = (json['count'] as num?)?.toInt();
    if (count == null) return null;

    return NodeCount(
      count: count,
      // Read through `num`: a change that lands on a whole percent is
      // serialised as `1`, not `1.0`, and a direct cast would throw on
      // exactly those days.
      percentChange24h: (json['percentChange24h'] as num?)?.toDouble(),
      trend: NodeTrend.parse(json['trend'] as String?),
    );
  }

  /// Reachable full nodes the producer's source counted.
  ///
  /// A lower bound, not a total: nodes behind Tor or without open ports
  /// belong to the network and cannot be counted. The info sheet on the
  /// screen says so; nothing in this app may present the figure as the
  /// number of nodes that exist.
  final int count;

  /// Change against the same reading 24 hours earlier, in percent, or
  /// `null` when the producer had no usable reference point.
  final double? percentChange24h;

  /// The producer's own classification of [percentChange24h].
  ///
  /// **Nothing on screen is drawn from it.** The design carries direction
  /// through the sign, the sentence and the tone rather than through an
  /// arrow — the icon set is closed at ten glyphs — so the signed figure
  /// says everything a direction word would. It is parsed because it is
  /// part of the payload contract and because [hasChange] would otherwise
  /// be the only reading of a field the producer states explicitly.
  final NodeTrend trend;

  /// Whether a 24 h comparison can be shown at all.
  ///
  /// **The figure decides, not the label.** `trend` degrades to
  /// [NodeTrend.unknown] for any string this app does not know, and
  /// hiding a change value that did arrive because of a label added
  /// upstream would report "comparison missing" next to a comparison
  /// that exists. The producer writes the two together — a `null` change
  /// always carries `trend: "unknown"` — so reading the figure loses
  /// nothing and cannot be wrong-footed.
  bool get hasChange => percentChange24h != null;
}
