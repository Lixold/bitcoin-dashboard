import '../../../core/widgets/brand_icon.dart';
import '../../../l10n/generated/app_localizations.dart';

/// One destination in the app's navigation.
///
/// The enum carries all six future sections so the UI never has to learn
/// new ids; a section without a shipped slice simply opts out via
/// [hasShippedSlice].
///
/// It implements [BrandGlyph] so [BrandIcon] can render a section through
/// the same entry point as a [UiGlyph]. [asset] stays the only place the
/// six section paths are written down.
enum NavSection implements BrandGlyph {
  price(
    id: 'price',
    asset: 'assets/icons/nav/price.svg',
    hasShippedSlice: true,
  ),
  market(
    id: 'market',
    asset: 'assets/icons/nav/market.svg',
    hasShippedSlice: true,
  ),
  forecast(
    id: 'forecast',
    asset: 'assets/icons/nav/forecast.svg',
    hasShippedSlice: false,
  ),
  network(
    id: 'network',
    asset: 'assets/icons/nav/network.svg',
    hasShippedSlice: true,
  ),
  miner(
    id: 'miner',
    asset: 'assets/icons/nav/miner.svg',
    hasShippedSlice: false,
  ),
  news(id: 'news', asset: 'assets/icons/nav/news.svg', hasShippedSlice: false);

  const NavSection({
    required this.id,
    required this.asset,
    required this.hasShippedSlice,
  });

  final String id;

  @override
  final String asset;

  /// Whether this section's first slice is merged — not whether a screen
  /// file for it exists. A section flips to `true` in the pull request that
  /// ships its first user-visible capability, and not before: until then it
  /// has nothing to render but a placeholder, which CLAUDE.md §5 rules out
  /// of the shipped app. This flag is what keeps it out of the navigation
  /// and out of the routing table.
  final bool hasShippedSlice;

  /// Localised label, looked up through [AppL10n]. Centralised here so the
  /// bar, the rail and the drawer stay in lockstep.
  ///
  /// The switch is exhaustive over all six sections, so every section keeps
  /// its key in the ARB files even while it has no shipped slice and is
  /// therefore never rendered. Removing those keys would not remove a
  /// string from the app — it would remove the compiler's guarantee that
  /// the next section to ship already has a label.
  String label(AppL10n l10n) => switch (this) {
    NavSection.price => l10n.navPrice,
    NavSection.market => l10n.navMarket,
    NavSection.forecast => l10n.navForecast,
    NavSection.network => l10n.navNetwork,
    NavSection.miner => l10n.navMiner,
    NavSection.news => l10n.navNews,
  };

  /// Route location of this section's shell branch. The id is the single
  /// source of the URL, so the navigation, the router, and a deep link can
  /// never disagree about what `/market` means.
  ///
  /// Every section has one, including those without a shipped slice: the
  /// location is what a deep link is matched against, and a section that
  /// has no branch has to be recognisable to be turned away.
  String get location => '/$id';

  /// Every section whose first slice has shipped, in the canonical
  /// declaration order.
  ///
  /// This is also the router's branch order and therefore the index the
  /// shell maps back to a section — see `lib/core/router/app_router.dart`.
  static List<NavSection> visible() =>
      NavSection.values.where((s) => s.hasShippedSlice).toList();
}
