import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// How a [Statement] reads its subject.
///
/// The tone is the claim, not decoration: it decides the verdict colour,
/// the marker shape and the insight pill's accent together, so a screen
/// cannot say "fine" in words and "alarming" in colour.
enum StatementTone { positive, warning, negative, neutral }

/// The app's unit of meaning: a category, a verdict, the figures behind
/// it, one sentence that says what they mean, and the evidence.
///
/// **This is the composition every later slice inherits**, so the slots
/// are fixed and their order is not a per-screen choice:
///
///   1. [category] — the eyebrow: what this statement is about, plus
///      whatever qualifies it right now (a timestamp, a loading note).
///   2. [notice] — a state that changes how the figures should be read
///      without invalidating them, such as an age hint.
///   3. [verdict] — the one-word answer, its badge and the info trigger.
///   4. [figures] — the numbers the verdict rests on.
///   5. [insight] — the sentence. Never optional when figures are shown;
///      CLAUDE.md §5 makes a figure without its sentence a placeholder.
///   6. [evidence] — the detail a reader can check the claim against.
///
/// Every slot is nullable because the states differ — loading has no
/// verdict, empty has no insight — but the order never does.
class Statement extends StatelessWidget {
  const Statement({
    super.key,
    required this.category,
    this.notice,
    this.verdict,
    this.figures,
    this.insight,
    this.evidence,
  });

  /// Reading width for prose. Wider lines are harder to track back to the
  /// next line's start; the design system caps its own at the same point.
  static const double proseMaxWidth = 640;

  /// Reading width for the evidence block, which carries rows rather than
  /// sentences and can take more.
  static const double evidenceMaxWidth = 720;

  final Widget category;
  final Widget? notice;
  final Widget? verdict;
  final Widget? figures;
  final Widget? insight;
  final Widget? evidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        category,
        if (notice != null) ...[const SizedBox(height: AppSpacing.s4), notice!],
        if (verdict != null) ...[const SizedBox(height: 14), verdict!],
        if (figures != null) ...[
          const SizedBox(height: AppSpacing.s5),
          figures!,
        ],
        if (insight != null) ...[
          const SizedBox(height: AppSpacing.s5),
          insight!,
        ],
        if (evidence != null) ...[
          const SizedBox(height: AppSpacing.s6),
          evidence!,
        ],
      ],
    );
  }
}

/// The eyebrow above a statement: an optional live dot, the subject, and
/// trailing qualifiers.
class StatementCategory extends StatelessWidget {
  const StatementCategory({
    super.key,
    required this.label,
    this.isLive = false,
    this.trailing,
  });

  final String label;

  /// Shows the live dot. Only true when the statement rests on data that
  /// is current — a stale or absent payload must not claim liveness.
  final bool isLive;

  /// Qualifiers appended after a `·`, e.g. the data stamp.
  final List<String>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = AppTypography.monoCaption.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        if (isLive)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: LiveDot(color: AppColors.positiveFor(theme.brightness)),
          ),
        Text(label.toUpperCase(), style: style),
        for (final qualifier in trailing ?? const <String>[])
          Text('· $qualifier', style: style),
      ],
    );
  }
}

/// The 6 px dot that marks a figure as currently observed.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The verdict line: marker, the word, its badge, and the info trigger.
class StatementVerdict extends StatelessWidget {
  const StatementVerdict({
    super.key,
    required this.verdict,
    required this.badgeLabel,
    required this.tone,
    this.onInfo,
    this.infoLabel,
  });

  final String verdict;
  final String badgeLabel;
  final StatementTone tone;
  final VoidCallback? onInfo;
  final String? infoLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColor = tone.colorFor(theme.brightness);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s2,
      children: [
        VerdictMarker(tone: tone),
        Text(
          verdict,
          // The verdict word stays in the body colour rather than the tone
          // colour. A 32 px word in amber or red is the loudest thing on
          // the screen before it has been read, and the marker and badge
          // already carry the signal at a size where contrast is safe.
          style: AppTypography.displayLarge.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        StatusBadge(label: badgeLabel, tone: tone, color: toneColor),
        if (onInfo != null && infoLabel != null)
          InfoTrigger(label: infoLabel!, onTap: onInfo!),
      ],
    );
  }
}

/// The tone marker — a 16 px disc whose **shape** carries the level.
///
/// Ring, half-filled, filled. Colour repeats the same information for
/// readers who see it, but the three states stay apart in greyscale and
/// for anyone who does not distinguish the hues: the briefing for #68
/// requires the verdict to survive without colour.
class VerdictMarker extends StatelessWidget {
  const VerdictMarker({super.key, required this.tone, this.size = 16});

  final StatementTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _VerdictMarkerPainter(
        tone: tone,
        color: tone.colorFor(Theme.of(context).brightness),
      ),
    );
  }
}

class _VerdictMarkerPainter extends CustomPainter {
  const _VerdictMarkerPainter({required this.tone, required this.color});

  final StatementTone tone;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (tone) {
      case StatementTone.positive:
        break; // ring only
      case StatementTone.warning:
        // Left half filled: visibly "partway" without relying on hue.
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
        canvas.drawCircle(centre, radius, fill);
        canvas.restore();
      case StatementTone.negative:
      case StatementTone.neutral:
        canvas.drawCircle(centre, radius, fill);
    }

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_VerdictMarkerPainter oldDelegate) =>
      oldDelegate.tone != tone || oldDelegate.color != color;
}

/// The pill next to the verdict, restating it in a short phrase.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    required this.color,
  });

  final String label;
  final StatementTone tone;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveDot(color: color, size: 8),
          const SizedBox(width: AppSpacing.s2),
          Text(
            label.toUpperCase(),
            style: AppTypography.monoCaption.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// The 20 px "?" that opens an explanation.
class InfoTrigger extends StatelessWidget {
  const InfoTrigger({super.key, required this.label, required this.onTap});

  /// Accessible name and tooltip — what the explanation answers.
  final String label;
  final VoidCallback onTap;

  /// Edge of the touch target. The visible ring is [ringSize]; the target
  /// around it is what a finger has to hit.
  static const double targetSize = 44;
  static const double ringSize = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: targetSize,
            height: targetSize,
            child: Center(
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  '?',
                  style: AppTypography.monoCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sentence. Tinted block with a 3 px accent edge, the category in
/// the accent colour, then the claim in prose.
class InsightPill extends StatelessWidget {
  const InsightPill({
    super.key,
    required this.category,
    required this.text,
    required this.tone,
  });

  final String category;
  final String text;
  final StatementTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tone == StatementTone.positive
        // The positive insight keeps the brand accent rather than green:
        // a calm reading is the normal case and should not light up.
        ? theme.colorScheme.primary
        : tone.colorFor(theme.brightness);

    return Container(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$category: ',
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: text),
          ],
        ),
        // The insight sentence is the app's first wrapped prose, so it
        // takes the body role at its full 16 / 1.5 rather than a smaller
        // one — see the ramp note in AppTypography.
        style: AppTypography.bodyLarge.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

extension StatementToneColor on StatementTone {
  /// The tone's colour on this [brightness]. Signal colours differ per
  /// scheme for contrast — see [AppColors].
  Color colorFor(Brightness brightness) => switch (this) {
    StatementTone.positive => AppColors.positiveFor(brightness),
    StatementTone.warning => AppColors.warningFor(brightness),
    StatementTone.negative => AppColors.negativeFor(brightness),
    StatementTone.neutral => AppColors.neutralFor(brightness),
  };
}
