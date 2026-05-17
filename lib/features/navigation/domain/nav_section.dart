import '../../../l10n/generated/app_localizations.dart';

/// One destination in the floating-pill navigation.
///
/// The enum carries all six future sections so the UI never has to learn
/// new ids; sections not yet built simply opt out via [isVisibleInPhase3].
enum NavSection {
  kurs(
    id: 'kurs',
    asset: 'assets/icons/nav/kurs.svg',
    isVisibleInPhase3: true,
  ),
  markt(
    id: 'markt',
    asset: 'assets/icons/nav/markt.svg',
    isVisibleInPhase3: true,
  ),
  prognose(
    id: 'prognose',
    asset: 'assets/icons/nav/prognose.svg',
    isVisibleInPhase3: false,
  ),
  netzwerk(
    id: 'netzwerk',
    asset: 'assets/icons/nav/netzwerk.svg',
    isVisibleInPhase3: true,
  ),
  miner(
    id: 'miner',
    asset: 'assets/icons/nav/miner.svg',
    isVisibleInPhase3: false,
  ),
  news(
    id: 'news',
    asset: 'assets/icons/nav/news.svg',
    isVisibleInPhase3: true,
  );

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
    NavSection.kurs => l10n.navKurs,
    NavSection.markt => l10n.navMarkt,
    NavSection.prognose => l10n.navPrognose,
    NavSection.netzwerk => l10n.navNetzwerk,
    NavSection.miner => l10n.navMiner,
    NavSection.news => l10n.navNews,
  };

  /// All sections visible in the current phase, preserving the canonical
  /// declaration order.
  static List<NavSection> visible() =>
      NavSection.values.where((s) => s.isVisibleInPhase3).toList();
}
