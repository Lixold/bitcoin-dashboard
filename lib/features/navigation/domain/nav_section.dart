import '../../../l10n/generated/app_localizations.dart';

/// One destination in the floating-pill navigation.
///
/// The enum carries all six future sections so the UI never has to learn
/// new ids; sections not yet built simply opt out via [isVisibleInPhase3].
enum NavSection {
  price(
    id: 'price',
    asset: 'assets/icons/nav/price.svg',
    isVisibleInPhase3: true,
  ),
  market(
    id: 'market',
    asset: 'assets/icons/nav/market.svg',
    isVisibleInPhase3: true,
  ),
  forecast(
    id: 'forecast',
    asset: 'assets/icons/nav/forecast.svg',
    isVisibleInPhase3: false,
  ),
  network(
    id: 'network',
    asset: 'assets/icons/nav/network.svg',
    isVisibleInPhase3: true,
  ),
  miner(
    id: 'miner',
    asset: 'assets/icons/nav/miner.svg',
    isVisibleInPhase3: false,
  ),
  news(id: 'news', asset: 'assets/icons/nav/news.svg', isVisibleInPhase3: true);

  const NavSection({
    required this.id,
    required this.asset,
    required this.isVisibleInPhase3,
  });

  final String id;
  final String asset;
  final bool isVisibleInPhase3;

  /// Localised label, looked up through [AppL10n]. Centralised here so the
  /// pill, sheet, and screen headers stay in lockstep.
  String label(AppL10n l10n) => switch (this) {
    NavSection.price => l10n.navPrice,
    NavSection.market => l10n.navMarket,
    NavSection.forecast => l10n.navForecast,
    NavSection.network => l10n.navNetwork,
    NavSection.miner => l10n.navMiner,
    NavSection.news => l10n.navNews,
  };

  /// Route location of this section's shell branch. The id is the single
  /// source of the URL, so the pill, the router, and a deep link can never
  /// disagree about what `/news` means.
  String get location => '/$id';

  /// All sections visible in the current phase, preserving the canonical
  /// declaration order.
  ///
  /// This is also the router's branch order and therefore the index the
  /// shell maps back to a section — see `lib/core/router/app_router.dart`.
  static List<NavSection> visible() =>
      NavSection.values.where((s) => s.isVisibleInPhase3).toList();
}
