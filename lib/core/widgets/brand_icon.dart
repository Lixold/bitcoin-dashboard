import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A glyph from the design system's ten-piece icon set, identified by the
/// asset it is bundled under.
///
/// Implemented by [UiGlyph] for the four UI glyphs and by `NavSection` for
/// the six section glyphs, so [BrandIcon] can render either without a
/// second copy of the ten paths.
abstract interface class BrandGlyph {
  /// Bundled asset path, e.g. `assets/icons/alert.svg`.
  String get asset;
}

/// The four glyphs that belong to the UI rather than to a section.
///
/// The six section glyphs are not repeated here — `NavSection` already
/// carries them and implements [BrandGlyph] for that purpose.
enum UiGlyph implements BrandGlyph {
  chevronDown(asset: 'assets/icons/chevron-down.svg'),
  alert(asset: 'assets/icons/alert.svg'),
  settings(asset: 'assets/icons/settings.svg'),
  more(asset: 'assets/icons/more.svg');

  const UiGlyph({required this.asset});

  @override
  final String asset;
}

/// Renders a design-system glyph at [size], tinted with a `srcIn` filter.
///
/// The filter carries both glyph shapes the set contains: stroked outlines
/// and filled bodies such as `more` and `miner`. [size] is the edge of the
/// box the glyph is fitted into — the artwork scales through its own
/// viewBox, which is not 24×24 for every glyph.
class BrandIcon extends StatelessWidget {
  const BrandIcon(this.glyph, {super.key, this.size = 32, this.color});

  /// Either a [UiGlyph] or a `NavSection`.
  final BrandGlyph glyph;

  /// Edge length of the square the glyph is drawn into. The design system
  /// uses 34 in sheet tiles, 28 in the pill and 12 for the chevron.
  final double size;

  /// Tint applied to the whole glyph. Defaults to `colorScheme.onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      glyph.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}
