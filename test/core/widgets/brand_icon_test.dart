import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The full ten-piece set: four UI glyphs plus the six section glyphs the
/// [NavSection] enum already owns.
const List<BrandGlyph> allGlyphs = <BrandGlyph>[
  ...UiGlyph.values,
  ...NavSection.values,
];

Widget _harness(Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: Wrap(
          children: [for (final glyph in allGlyphs) BrandIcon(glyph)],
        ),
      ),
    ),
  );
}

void main() {
  test('the set is ten glyphs and every asset path is distinct', () {
    expect(allGlyphs, hasLength(10));
    expect(allGlyphs.map((g) => g.asset).toSet(), hasLength(10));
  });

  testWidgets('every glyph is bundled and parses as SVG', (tester) async {
    for (final glyph in allGlyphs) {
      // Fails if `assets/icons/` is missing from pubspec.yaml, or if a
      // directory entry was merged away — neither shows up at build time.
      final source = await rootBundle.loadString(glyph.asset);
      expect(source, startsWith('<svg'), reason: glyph.asset);
      expect(source, contains('</svg>'), reason: glyph.asset);

      // Parses the real file through the same loader BrandIcon uses.
      await vg.loadPicture(SvgAssetLoader(glyph.asset), null);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('renders all ten glyphs in ${brightness.name}', (tester) async {
      await tester.pumpWidget(_harness(brightness));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsNWidgets(10));

      final rendered = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      final expectedTint =
          (brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
              .colorScheme
              .onSurface;

      for (var i = 0; i < allGlyphs.length; i++) {
        expect(
          rendered[i].bytesLoader.toString(),
          contains(allGlyphs[i].asset),
          reason: allGlyphs[i].asset,
        );
        expect(
          rendered[i].colorFilter,
          ColorFilter.mode(expectedTint, BlendMode.srcIn),
          reason: allGlyphs[i].asset,
        );
      }
    });
  }

  testWidgets('size defaults to 32 and is overridable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              BrandIcon(UiGlyph.settings),
              BrandIcon(UiGlyph.chevronDown, size: 12),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pictures = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(pictures[0].width, 32);
    expect(pictures[0].height, 32);
    expect(pictures[1].width, 12);
    expect(pictures[1].height, 12);
  });

  testWidgets('an explicit colour wins over the scheme default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: BrandIcon(NavSection.miner, color: Color(0xFFF7931A)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      picture.colorFilter,
      const ColorFilter.mode(Color(0xFFF7931A), BlendMode.srcIn),
    );
  });
}
