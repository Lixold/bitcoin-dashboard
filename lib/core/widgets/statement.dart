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
///   2. [selection] — a control that picks *what the statement is about*,
///      such as the price screen's range strip. It sits above the verdict
///      rather than inside the evidence because it chooses the subject,
///      not the drawing: pick a different range and the verdict, the
///      figure and the sentence all change with it.
///   3. [notice] — a state that changes how the figures should be read
///      without invalidating them, such as an age hint.
///   4. [verdict] — the one-word answer, its badge and the info trigger.
///   5. [figures] — the numbers the verdict rests on.
///   6. [insight] — the sentence. Never optional when figures are shown;
///      CLAUDE.md §5 makes a figure without its sentence a placeholder.
///   7. [evidence] — the detail a reader can check the claim against.
///
/// Every slot is nullable because the states differ — loading has no
/// verdict, empty has no insight — but the order never does.
class Statement extends StatelessWidget {
  const Statement({
    super.key,
    required this.category,
    this.selection,
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
  final Widget? selection;
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
        if (selection != null) ...[
          const SizedBox(height: AppSpacing.s5),
          selection!,
        ],
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

/// The eyebrow above a statement: an optional live dot and the subject,
/// with the qualifiers on a second line beneath.
///
/// **Two lines, not one that wraps.** The design gives the stamp its own
/// line at a step below the subject — putting both in one run makes the
/// break depend on the window width, so the same screen reads as one
/// line on a desktop and as a wrapped label on a phone.
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

  /// What qualifies the subject right now — the data stamp, its age, a
  /// loading note. They share the second line, joined by `·`.
  final List<String>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualifiers = trailing ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isLive) ...[
              LiveDot(color: AppColors.positiveFor(theme.brightness)),
              const SizedBox(width: AppSpacing.s2),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: AppTypography.monoCaption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (qualifiers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            qualifiers.join(' · ').toUpperCase(),
            // A step down from the subject and in the neutral colour:
            // this is metadata about the figures, not a second heading.
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.neutralFor(theme.brightness),
            ),
          ),
        ],
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
    required this.tone,
    this.badgeLabel,
    this.onInfo,
    this.infoLabel,
  });

  final String verdict;

  /// The badge's short phrase, or `null` for no badge.
  ///
  /// **A second word only where it says something the first does not.**
  /// The network statement's verdict is a level ("uncritical") and its
  /// badge names the figure that set it; the sentiment statement's
  /// verdict is already the band's own name, and a badge repeating it
  /// would restate the word next to itself. The marker carries the tone
  /// in both cases — through its shape, not through a second label.
  final String? badgeLabel;

  final StatementTone tone;

  /// Opens the long explanation. Null leaves [infoLabel] as the whole
  /// explanation, shown in a tooltip — see [InfoTrigger].
  final VoidCallback? onInfo;

  /// What the trigger explains. Null means the verdict carries no
  /// trigger at all.
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
        if (badgeLabel != null)
          StatusBadge(label: badgeLabel!, tone: tone, color: toneColor),
        if (infoLabel != null) InfoTrigger(label: infoLabel!, onTap: onInfo),
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

/// The 20 px glyph that explains a term.
///
/// **The glyph follows the behaviour, and the behaviour follows the
/// length of the explanation.** An explanation that fits in a tooltip is
/// an "i" and needs no [onTap]; one long enough to need a sheet is a "?"
/// and opens it. The design system draws the same distinction, and a "?"
/// that answers itself in a tooltip would promise a page that never
/// arrives.
class InfoTrigger extends StatelessWidget {
  const InfoTrigger({super.key, required this.label, this.onTap});

  /// Accessible name and tooltip — what the explanation answers, or the
  /// explanation itself when there is nothing further to open.
  final String label;

  /// Opens the long form. Null means [label] *is* the explanation, and
  /// the tooltip is then reachable by tap as well as by hover, because a
  /// phone has no hover.
  final VoidCallback? onTap;

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
        triggerMode: onTap == null ? TooltipTriggerMode.tap : null,
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
                  onTap == null ? 'i' : '?',
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
